import 'dart:async';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'api_service.dart';
import 'device_service.dart';

class P2PService {
  static final P2PService instance = P2PService.internal();
  factory P2PService() => instance;
  P2PService.internal();

  static const Map<String, dynamic> iceConfig = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {
        'urls': 'turn:openrelay.metered.ca:80',
        'username': 'openrelayproject',
        'credential': 'openrelayproject',
      },
      {
        'urls': 'turn:openrelay.metered.ca:443',
        'username': 'openrelayproject',
        'credential': 'openrelayproject',
      },
    ],
  };

  final ApiService api = ApiService();
  late final DeviceService deviceService = DeviceService(api);

  RTCPeerConnection? peerConnection;
  RTCDataChannel? dataChannel;
  StreamSubscription<Map<String, dynamic>>? signalSub;
  String? myUuid;
  String? remoteDeviceUuid;

  // Tampon ICE: les candidats reçus avant setRemoteDescription seraient perdus.
  final List<RTCIceCandidate> pendingIce = [];
  bool remoteDescriptionSet = false;

  // Évite que deux offers concurrentes créent deux PeerConnections.
  bool handlingOffer = false;

  // true si on est l'initiateur de la connexion (caller), false côté receveur.
  bool isCaller = false;

  Function(String)? onMessageReceived;

  // -------- API publique --------

  void startListening() {
    deviceService.getDeviceUuid().then((uuid) {
      myUuid = uuid;
      startSignaling();
    });
  }

  Future<void> connectToDevice(String deviceUuid) async {
    log('connectToDevice → $deviceUuid');
    await disconnect();

    remoteDeviceUuid = deviceUuid;
    myUuid ??= await deviceService.getDeviceUuid();
    isCaller = true;

    peerConnection = await createPeer(listenForRemoteChannel: false);
    bindDataChannel(
      await peerConnection!.createDataChannel('messages', RTCDataChannelInit()),
    );

    final offer = await peerConnection!.createOffer();
    await peerConnection!.setLocalDescription(offer);

    await postOrThrow('/p2p/offer', {
      'from_uuid': myUuid,
      'to_uuid': deviceUuid,
      'sdp': offer.sdp,
    });
    log('offer envoyée au backend');

    startSignaling();
  }

  Future<Map<String, dynamic>> postOrThrow(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    final res = await api.post(endpoint, body);
    if (res['code'] != 200) {
      throw P2PException(
        'POST $endpoint a échoué (code=${res['code']}, msg=${res['message']})',
      );
    }
    return res;
  }

  Future<void> sendMessage() async {
    if (dataChannel?.state == RTCDataChannelState.RTCDataChannelOpen) {
      dataChannel!.send(RTCDataChannelMessage('Hello P2P'));
      log('sendMessage: "Hello P2P" envoyé');
    } else {
      log('sendMessage: canal non ouvert (state=${dataChannel?.state})');
    }
  }

  Future<void> disconnect() async {
    stopSignaling();
    await dataChannel?.close();
    await peerConnection?.close();
    dataChannel = null;
    peerConnection = null;
    remoteDeviceUuid = null;
    pendingIce.clear();
    remoteDescriptionSet = false;
    isCaller = false;
  }

  // -------- WebRTC --------

  Future<RTCPeerConnection> createPeer({required bool listenForRemoteChannel}) async {
    final pc = await createPeerConnection(iceConfig);
    pc.onIceCandidate = sendIceCandidate;
    pc.onConnectionState = (s) => log('connection state: $s');
    // Seul le receveur écoute onDataChannel: le caller crée son channel lui-même.
    if (listenForRemoteChannel) {
      pc.onDataChannel = bindDataChannel;
    }
    return pc;
  }

  void bindDataChannel(RTCDataChannel ch) {
    dataChannel = ch;
    ch.onDataChannelState = (s) {
      log('data channel state: $s');
      if (s == RTCDataChannelState.RTCDataChannelOpen) {
        // La signalisation n'est plus nécessaire une fois le canal ouvert.
        stopSignaling();
        // Côté initiateur: on envoie automatiquement un "Hello P2P".
        if (isCaller) sendMessage();
      }
    };
    ch.onMessage = (m) {
      log('message reçu: ${m.text}');
      onMessageReceived?.call(m.text);
      // Une fois le message reçu, le tunnel a fait son office: on ferme.
      disconnect();
    };
  }

  // -------- Signalisation (SSE) --------

  void startSignaling() {
    if (myUuid == null || signalSub != null) return;
    log('SSE: ouverture du flux /p2p/events/$myUuid');
    signalSub = api.streamEvents('/p2p/events/$myUuid').listen(
      (msg) async {
        try {
          await handleSignal(msg);
        } catch (e) {
          log('erreur sur signal ${msg['type']}: $e');
        }
      },
      onError: (e) {
        log('SSE erreur: $e');
        signalSub = null;
      },
      onDone: () {
        log('SSE fermé par le serveur');
        signalSub = null;
      },
    );
  }

  void stopSignaling() {
    if (signalSub != null) {
      log('arrêt de la signalisation SSE');
      signalSub!.cancel();
      signalSub = null;
    }
  }

  Future<void> sendIceCandidate(RTCIceCandidate candidate) async {
    if (myUuid == null || remoteDeviceUuid == null) return;
    if (candidate.candidate == null) return;
    try {
      await postOrThrow('/p2p/ice', {
        'from_uuid': myUuid,
        'to_uuid': remoteDeviceUuid,
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      });
    } catch (e) {
      // Un ICE perdu n'est pas fatal: WebRTC en envoie plusieurs.
      log('sendIceCandidate: $e');
    }
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
      log('offer ignorée: une autre est déjà en cours de traitement');
      return;
    }
    handlingOffer = true;
    try {
      if (peerConnection != null) await disconnect();
      myUuid ??= await deviceService.getDeviceUuid();
      remoteDeviceUuid = msg['from_uuid'] as String?;
      isCaller = false;

      peerConnection = await createPeer(listenForRemoteChannel: true);
      await applyRemoteDescription(RTCSessionDescription(msg['sdp'], 'offer'));

      final answer = await peerConnection!.createAnswer();
      await peerConnection!.setLocalDescription(answer);

      await postOrThrow('/p2p/answer', {
        'from_uuid': myUuid,
        'to_uuid': msg['from_uuid'],
        'sdp': answer.sdp,
      });
      log('answer envoyée au backend');
      startSignaling();
    } finally {
      handlingOffer = false;
    }
  }

  Future<void> onAnswer(Map<String, dynamic> msg) async {
    await applyRemoteDescription(RTCSessionDescription(msg['sdp'], 'answer'));
  }

  Future<void> onIce(Map<String, dynamic> msg) async {
    final candidate = RTCIceCandidate(
      msg['candidate'],
      msg['sdpMid'],
      msg['sdpMLineIndex'],
    );
    if (remoteDescriptionSet) {
      await peerConnection!.addCandidate(candidate);
    } else {
      pendingIce.add(candidate);
    }
  }

  Future<void> applyRemoteDescription(RTCSessionDescription desc) async {
    await peerConnection!.setRemoteDescription(desc);
    remoteDescriptionSet = true;
    for (final c in pendingIce) {
      await peerConnection!.addCandidate(c);
    }
    pendingIce.clear();
  }

  void log(String msg) => print('[P2P] $msg');
}

class P2PException implements Exception {
  final String message;
  P2PException(this.message);
  @override
  String toString() => 'P2PException: $message';
}
