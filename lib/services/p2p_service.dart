import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'api_service.dart';
import 'device_service.dart';
import 'signaling_client.dart';

enum P2PStatus { idle, connecting, connected, failed }

class P2PService {
  static final P2PService instance = P2PService.internal();
  factory P2PService() => instance;
  P2PService.internal();

  final ApiService api = ApiService();
  late final DeviceService deviceService = DeviceService(api);

  SignalingClient? signaling;
  StreamSubscription<Map<String, dynamic>>? signalSub;

  RTCPeerConnection? peerConnection;
  RTCDataChannel? dataChannel;

  String? myUuid;
  String? remoteDeviceUuid;
  bool isCaller = false;
  bool handlingOffer = false;
  bool remoteDescriptionSet = false;
  final List<RTCIceCandidate> pendingIce = [];

  // Flux de messages reçus côté DataChannel.
  final StreamController<String> messagesController =
      StreamController<String>.broadcast();
  Stream<String> get messages => messagesController.stream;

  // État observable de la connexion P2P.
  final ValueNotifier<P2PStatus> status = ValueNotifier(P2PStatus.idle);

  // -------- API publique --------

  void startListening() {
    deviceService.getDeviceUuid().then((uuid) {
      myUuid = uuid;
      ensureSignaling();
    });
  }

  Future<void> connectToDevice(String deviceUuid) async {
    log('connectToDevice → $deviceUuid');
    await disconnect();
    status.value = P2PStatus.connecting;
    try {
      remoteDeviceUuid = deviceUuid;
      myUuid ??= await deviceService.getDeviceUuid();
      isCaller = true;
      ensureSignaling();

      peerConnection = await createPeer(listenForRemoteChannel: false);
      bindDataChannel(
        await peerConnection!.createDataChannel('messages', RTCDataChannelInit()),
      );

      final offer = await peerConnection!.createOffer();
      await peerConnection!.setLocalDescription(offer);
      await signaling!.send('offer', deviceUuid, {'sdp': offer.sdp});
      log('offer envoyée');
    } catch (e) {
      status.value = P2PStatus.failed;
      rethrow;
    }
  }

  Future<void> sendMessage() async {
    if (dataChannel?.state == RTCDataChannelState.RTCDataChannelOpen) {
      dataChannel!.send(RTCDataChannelMessage('Hello P2P'));
      log('"Hello P2P" envoyé');
    } else {
      log('canal non ouvert (state=${dataChannel?.state})');
    }
  }

  Future<void> disconnect() async {
    signaling?.stop();
    await dataChannel?.close();
    await peerConnection?.close();
    dataChannel = null;
    peerConnection = null;
    remoteDeviceUuid = null;
    pendingIce.clear();
    remoteDescriptionSet = false;
    isCaller = false;
    status.value = P2PStatus.idle;
  }

  // -------- Signalisation --------

  void ensureSignaling() {
    if (myUuid == null) return;
    if (signaling == null) {
      signaling = SignalingClient(api: api, myUuid: myUuid!);
      signalSub = signaling!.signals.listen((msg) async {
        try {
          await handleSignal(msg);
        } catch (e) {
          log('erreur signal ${msg['type']}: $e');
        }
      });
    }
    signaling!.start();
  }

  Future<void> handleSignal(Map<String, dynamic> msg) async {
    final type = msg['type'] as String?;
    log('signal reçu: type=$type from=${msg['from_uuid']}');
    switch (type) {
      case 'offer':
        await onOffer(msg);
        break;
      case 'answer':
        await onAnswer(msg);
        break;
      case 'ice':
        await onIce(msg);
        break;
    }
  }

  Future<void> onOffer(Map<String, dynamic> msg) async {
    if (handlingOffer) {
      log('offer ignorée (déjà en cours)');
      return;
    }
    handlingOffer = true;
    try {
      if (peerConnection != null) await disconnect();
      status.value = P2PStatus.connecting;
      myUuid ??= await deviceService.getDeviceUuid();
      remoteDeviceUuid = msg['from_uuid'] as String?;
      isCaller = false;
      ensureSignaling();

      peerConnection = await createPeer(listenForRemoteChannel: true);
      await applyRemoteDescription(RTCSessionDescription(msg['sdp'], 'offer'));

      final answer = await peerConnection!.createAnswer();
      await peerConnection!.setLocalDescription(answer);
      await signaling!.send('answer', remoteDeviceUuid!, {'sdp': answer.sdp});
      log('answer envoyée');
    } catch (e) {
      status.value = P2PStatus.failed;
      log('onOffer échec: $e');
    } finally {
      handlingOffer = false;
    }
  }

  Future<void> onAnswer(Map<String, dynamic> msg) async {
    await applyRemoteDescription(RTCSessionDescription(msg['sdp'], 'answer'));
  }

  Future<void> onIce(Map<String, dynamic> msg) async {
    if (peerConnection == null) return;
    final c = RTCIceCandidate(
      msg['candidate'],
      msg['sdpMid'],
      msg['sdpMLineIndex'],
    );
    if (remoteDescriptionSet) {
      await peerConnection!.addCandidate(c);
    } else {
      pendingIce.add(c);
    }
  }

  Future<void> applyRemoteDescription(RTCSessionDescription d) async {
    await peerConnection!.setRemoteDescription(d);
    remoteDescriptionSet = true;
    for (final c in pendingIce) {
      await peerConnection!.addCandidate(c);
    }
    pendingIce.clear();
  }

  // -------- WebRTC --------

  Future<RTCPeerConnection> createPeer({required bool listenForRemoteChannel}) async {
    final pc = await createPeerConnection(iceConfig);
    pc.onIceCandidate = sendIceCandidate;
    pc.onConnectionState = (s) => log('connection state: $s');
    if (listenForRemoteChannel) pc.onDataChannel = bindDataChannel;
    return pc;
  }

  void bindDataChannel(RTCDataChannel ch) {
    dataChannel = ch;
    ch.onDataChannelState = (s) {
      log('data channel: $s');
      if (s == RTCDataChannelState.RTCDataChannelOpen) {
        status.value = P2PStatus.connected;
        signaling?.stop();
        if (isCaller) sendMessage();
      }
    };
    ch.onMessage = (m) {
      log('message reçu: ${m.text}');
      messagesController.add(m.text);
      disconnect();
    };
  }

  Future<void> sendIceCandidate(RTCIceCandidate c) async {
    if (myUuid == null || remoteDeviceUuid == null || c.candidate == null) return;
    try {
      await signaling!.send('ice', remoteDeviceUuid!, {
        'candidate': c.candidate,
        'sdpMid': c.sdpMid,
        'sdpMLineIndex': c.sdpMLineIndex,
      });
    } catch (e) {
      // Un ICE perdu n'est pas fatal: WebRTC en envoie plusieurs.
      log('sendIce: $e');
    }
  }

  // -------- Config ICE depuis .env --------

  Map<String, dynamic> get iceConfig {
    final servers = <Map<String, dynamic>>[];
    final stun = dotenv.env['STUN_URL'];
    final turn = dotenv.env['TURN_URL'];
    if (stun != null && stun.isNotEmpty) {
      servers.add({'urls': stun});
    }
    if (turn != null && turn.isNotEmpty) {
      servers.add({
        'urls': turn,
        'username': dotenv.env['TURN_USER'] ?? '',
        'credential': dotenv.env['TURN_PASS'] ?? '',
      });
    }
    return {'iceServers': servers};
  }

  void log(String msg) => print('[P2P] $msg');
}
