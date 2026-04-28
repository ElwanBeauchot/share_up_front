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

  // appelé au boot de l'app: récupère l'uuid du device et ouvre la SSE
  // pour être en écoute permanente d'un éventuel offer entrant
  void startListening() {
    deviceService.getDeviceUuid().then((uuid) {
      myUuid = uuid;
      ensureSignaling(); // ouverture de la connexion SSE
    });
  }

  // (A) point d'entrée côté caller: déclenche tout le handshake P2P vers (B)
  Future<void> connectToDevice(String deviceUuid) async {
    log('connectToDevice → $deviceUuid');
    await disconnect(); // cleanup d'une éventuelle session précédente
    status.value = P2PStatus.connecting;
    try {
      remoteDeviceUuid = deviceUuid; // uuid de (B)
      myUuid ??= await deviceService.getDeviceUuid();
      isCaller = true; // on est l'initiateur
      ensureSignaling(); // on réouvre la SSE fermée par disconnect() ci-dessus

      peerConnection = await createPeer(
        listenForRemoteChannel: false,
      ); // false -> c'est nous qui créons le canal, pas besoin d'écouter
      bindDataChannel(
        await peerConnection!.createDataChannel(
          'messages',
          RTCDataChannelInit(),
        ),
      ); // création du DataChannel local + branchement des callbacks

      final offer = await peerConnection!
          .createOffer(); // génération du SDP local
      await peerConnection!.setLocalDescription(
        offer,
      ); // WebRTC commence à émettre les candidats ICE vers (B)
      await signaling!.send('offer', deviceUuid, {
        'sdp': offer.sdp,
      }); // envoi du SDP à (B) via le backend
      log('offer envoyée');
    } catch (e) {
      status.value = P2PStatus.failed;
      rethrow;
    }
  }

  // envoi d'un message texte sur le DataChannel (déclenché auto à l'ouverture côté A)
  Future<void> sendMessage() async {
    if (dataChannel?.state == RTCDataChannelState.RTCDataChannelOpen) {
      dataChannel!.send(RTCDataChannelMessage('Hello P2P'));
      log('"Hello P2P" envoyé');
    } else {
      // si le canal n'est pas encore ouvert, on log et on abandonne
      log('canal non ouvert (state=${dataChannel?.state})');
    }
  }

  // ferme proprement la session P2P et reset tous les flags pour pouvoir réutiliser le service
  Future<void> disconnect() async {
    signaling?.stop(); // ferme la SSE (plus besoin pour cette session)
    await dataChannel?.close(); // ferme le canal de données P2P
    await peerConnection?.close(); // ferme la PeerConnection WebRTC
    dataChannel = null;
    peerConnection = null;
    remoteDeviceUuid = null;
    pendingIce.clear(); // vide le tampon ICE
    remoteDescriptionSet = false;
    isCaller = false;
    status.value = P2PStatus.idle; // on revient à l'état initial
  }

  // -------- Signalisation --------

  void ensureSignaling() {
    if (myUuid == null) return;
    if (signaling == null) {
      signaling = SignalingClient(
        api: api,
        myUuid: myUuid!,
      ); // crétation de l'instance de SignalingClient (connexion SSE qui reste ouverte et attends les messages)
      signalSub = signaling!.signals.listen((msg) async {
        // appel synchrone qui gère le(s) message(s) de la connexion SSE (SignalingClient) de type: offer, answer, ice
        try {
          await handleSignal(msg);
        } catch (e) {
          log('erreur signal ${msg['type']}: $e');
        }
      });
    }
    signaling!.start();
  }

  // handler qui appelle la bonne fonction de traitement du message
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

  // (B) miroir de @connectToDevice() qui gère l'offer reçu (A)
  Future<void> onOffer(Map<String, dynamic> msg) async {
    if (handlingOffer) {
      log('offer ignorée (déjà en cours)');
      return;
    } // permet de vérifier que l'on traite pas deux offres en même temps
    handlingOffer = true; // notre flag de vérif
    try {
      if (peerConnection != null) {
        await disconnect();
      } // si session précédente non terminée, on la termine
      status.value =
          P2PStatus.connecting; // on met à jour le status de connexion
      myUuid ??= await deviceService.getDeviceUuid();
      remoteDeviceUuid = msg['from_uuid'] as String?; // uuid de (A)
      isCaller = false;
      ensureSignaling(); // on réouvre la connexion SSE si jamais elle a été fermée par notre vérification précédente

      peerConnection = await createPeer(
        listenForRemoteChannel: true,
      ); // true -> on écoute le canal distant (A)
      await applyRemoteDescription(RTCSessionDescription(msg['sdp'], 'offer'));

      final answer = await peerConnection!.createAnswer();
      await peerConnection!.setLocalDescription(
        answer,
      ); // WebRTC envoit les candidats ICE à (A)
      await signaling!.send('answer', remoteDeviceUuid!, {
        'sdp': answer.sdp,
      }); // envoi de l'answer à (A)
      log('answer envoyée');
    } catch (e) {
      status.value = P2PStatus.failed;
      log('onOffer échec: $e');
    } finally {
      handlingOffer = false;
    }
  }

  // (A) reçoit l'answer envoyée par (B): rien à faire d'autre que poser le SDP distant
  Future<void> onAnswer(Map<String, dynamic> msg) async {
    await applyRemoteDescription(RTCSessionDescription(msg['sdp'], 'answer'));
  }

  // (A) ou (B): reçoit un candidat ICE du peer distant, à ajouter au peerConnection
  Future<void> onIce(Map<String, dynamic> msg) async {
    if (peerConnection == null) return; // safety: pas de session active
    final c = RTCIceCandidate(
      msg['candidate'],
      msg['sdpMid'],
      msg['sdpMLineIndex'],
    );
    if (remoteDescriptionSet) {
      // remote description posée -> on peut ajouter le candidat directement
      await peerConnection!.addCandidate(c);
    } else {
      // sinon on bufferise: addCandidate échouerait sans remote description
      pendingIce.add(c);
    }
  }

  // SDP = Session Description Protocol — c'est juste une carte de visite réseau au format texte.
  Future<void> applyRemoteDescription(RTCSessionDescription d) async {
    await peerConnection!.setRemoteDescription(
      d,
    ); // dépose le sdp dans le peerConnection
    remoteDescriptionSet = true;
    for (final c in pendingIce) {
      // on ajoute les candidats ICE restant à la liste
      await peerConnection!.addCandidate(c);
    }
    pendingIce.clear();
  }

  // -------- WebRTC --------

  // crée une PeerConnection et branche les callbacks WebRTC indispensables
  Future<RTCPeerConnection> createPeer({
    required bool listenForRemoteChannel,
  }) async {
    final pc = await createPeerConnection(
      iceConfig,
    ); // utilise STUN/TURN du .env
    pc.onIceCandidate =
        sendIceCandidate; // chaque candidat ICE local part vers le peer
    pc.onConnectionState = (s) => log('connection state: $s');
    if (listenForRemoteChannel) {
      // (B) seul le receveur écoute: c'est (A) qui crée le DataChannel
      pc.onDataChannel = bindDataChannel;
    }
    return pc;
  }

  // branche les callbacks du DataChannel: ouverture, réception de message
  void bindDataChannel(RTCDataChannel ch) {
    dataChannel = ch;
    ch.onDataChannelState = (s) {
      log('data channel: $s');
      if (s == RTCDataChannelState.RTCDataChannelOpen) {
        // canal ouvert: la SSE n'est plus utile, on libère
        status.value = P2PStatus.connected;
        signaling?.stop();
        if (isCaller) sendMessage(); // (A) envoie automatiquement "Hello P2P"
      }
    };
    ch.onMessage = (m) {
      log('message reçu: ${m.text}');
      messagesController.add(
        m.text,
      ); // notifie les listeners (UI, main.dart...)
      disconnect(); // tunnel a fait son office: on ferme proprement
    };
  }

  // envoyé par WebRTC à chaque candidat ICE local: on le pousse au peer via SSE
  Future<void> sendIceCandidate(RTCIceCandidate c) async {
    if (myUuid == null || remoteDeviceUuid == null || c.candidate == null) {
      return; // safety: contexte incomplet, on ignore
    }
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

  //stun = serveur de trafic public -> "voici ton IP publique vue depuis l'extérieur"
  //turn = serveur relais -> sert quand le P2P est impossible en direct (pare-feu, NAT, etc.)

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
