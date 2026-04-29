import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:path_provider/path_provider.dart';
import 'api_service.dart';
import 'device_service.dart';
import 'signaling_client.dart';

enum P2PStatus { idle, connecting, connected, failed }

// Taille de chunk pour le DataChannel SCTP (recommandé ≤ 16 KB).
const int _chunkSize = 16 * 1024;

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

  // Fichier que (A) souhaite envoyer dès l'ouverture du DataChannel.
  String? pendingFilePath;

  // Etat de réception côté (B): rempli au reçu du header file_start.
  _IncomingFile? _incoming;

  // Flux des fichiers reçus (chemin local du fichier sauvegardé).
  final StreamController<String> receivedFilesController =
      StreamController<String>.broadcast();
  Stream<String> get receivedFiles => receivedFilesController.stream;

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

  // (A) point d'entrée côté caller: déclenche tout le handshake P2P vers (B).
  // Si [filePath] est fourni, le fichier sera envoyé dès l'ouverture du canal.
  Future<void> connectToDevice(String deviceUuid, {String? filePath}) async {
    log('connectToDevice → $deviceUuid (file=${filePath ?? 'aucun'})');
    await disconnect(); // cleanup d'une éventuelle session précédente
    status.value = P2PStatus.connecting;
    try {
      pendingFilePath = filePath; // mémorise le fichier à envoyer dès DC ouvert
      remoteDeviceUuid = deviceUuid; // uuid de (B)
      myUuid ??= await deviceService.getDeviceUuid();
      isCaller = true; // on est l'initiateur
      ensureSignaling(); // on réouvre la SSE fermée par disconnect() ci-dessus

      peerConnection = await createPeer(
        listenForRemoteChannel: false,
      ); // false -> c'est nous qui créons le canal, pas besoin d'écouter
      bindDataChannel(
        await peerConnection!.createDataChannel('files', RTCDataChannelInit()),
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

  // ferme proprement la session P2P et reset tous les flags pour pouvoir réutiliser le service
  Future<void> disconnect() async {
    signaling?.stop(); // ferme la SSE (plus besoin pour cette session)
    await dataChannel?.close(); // ferme le canal de données P2P
    await peerConnection?.close(); // ferme la PeerConnection WebRTC
    dataChannel = null;
    peerConnection = null;
    remoteDeviceUuid = null;
    pendingIce.clear(); // vide le tampon ICE
    pendingFilePath = null; // plus rien à envoyer
    _incoming = null; // plus rien à recevoir
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
    final cand = msg['candidate'] as String?;
    if (cand == null || cand.isEmpty) {
      return; // end-of-candidates ou candidat vide: on ignore
    }
    final c = RTCIceCandidate(cand, msg['sdpMid'], msg['sdpMLineIndex']);
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
    pc.onIceConnectionState = (s) =>
        log('ice connection state: $s'); // utile pour diag ICE failed
    pc.onIceGatheringState = (s) => log('ice gathering state: $s');
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
        if (isCaller && pendingFilePath != null) {
          // (A) envoie automatiquement le fichier mémorisé
          // ignore: discarded_futures
          _sendFile(pendingFilePath!);
        }
      }
    };
    ch.onMessage = (m) async {
      // dispatch binaire (chunks de fichier) vs texte (header / ack)
      try {
        if (m.isBinary) {
          await _onBinaryChunk(m.binary);
        } else {
          await _onTextMessage(m.text);
        }
      } catch (e) {
        log('onMessage erreur: $e');
      }
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

  // -------- Envoi de fichier (côté A) --------

  // protocole minimal:
  //  1) un message texte JSON {type:'file_start', name, size}
  //  2) N messages binaires (chunks de _chunkSize octets)
  //  3) (B) renvoie {type:'file_received'} quand il a tout reçu -> on disconnect
  Future<void> _sendFile(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      log('fichier introuvable: $path');
      await disconnect();
      return;
    }
    final size = await file.length();
    final name = file.uri.pathSegments.isNotEmpty
        ? file.uri.pathSegments.last
        : 'file.bin';

    log('envoi fichier "$name" ($size octets)');

    // 1) header JSON en texte
    dataChannel!.send(
      RTCDataChannelMessage(
        jsonEncode({'type': 'file_start', 'name': name, 'size': size}),
      ),
    );

    // 2) chunks binaires lus depuis le disque pour ne pas tout charger en RAM
    var sent = 0;
    await for (final chunk in file.openRead()) {
      // openRead() peut renvoyer des morceaux > _chunkSize, on resplit.
      for (var offset = 0; offset < chunk.length; offset += _chunkSize) {
        final end = (offset + _chunkSize <= chunk.length)
            ? offset + _chunkSize
            : chunk.length;
        final slice = Uint8List.fromList(chunk.sublist(offset, end));
        await _waitForBuffer(); // backpressure: on attend si le buffer SCTP gonfle
        dataChannel!.send(RTCDataChannelMessage.fromBinary(slice));
        sent += slice.length;
      }
    }
    log('fichier envoyé ($sent/$size octets), en attente de l\'ack…');
  }

  // Backpressure simple: si le buffer SCTP gonfle, on attend qu'il se vide
  // pour ne pas saturer la mémoire native côté WebRTC.
  Future<void> _waitForBuffer() async {
    const maxBuffered = 1 * 1024 * 1024; // 1 MB
    final ch = dataChannel;
    if (ch == null) return;
    while ((ch.bufferedAmount ?? 0) > maxBuffered) {
      await Future.delayed(const Duration(milliseconds: 20));
    }
  }

  // -------- Réception de fichier (côté B) --------

  // gère les messages texte du DataChannel: header de fichier ou ack.
  Future<void> _onTextMessage(String raw) async {
    final data = jsonDecode(raw);
    if (data is! Map<String, dynamic>) return;
    final type = data['type'];
    switch (type) {
      case 'file_start':
        // (B) reçoit le header: on prépare le buffer de réception
        final name = data['name'] as String? ?? 'file.bin';
        final size = (data['size'] as num?)?.toInt() ?? 0;
        log('header reçu: "$name" ($size octets)');
        _incoming = _IncomingFile(name: name, expectedSize: size);
        break;
      case 'file_received':
        // (A) reçoit l'ack du peer (B): tout est parti -> on coupe
        log('ack reçu, fermeture');
        await disconnect();
        break;
    }
  }

  // accumule les chunks binaires; quand on a la taille annoncée, on sauvegarde.
  Future<void> _onBinaryChunk(Uint8List bytes) async {
    final rx = _incoming;
    if (rx == null) {
      // safety: on a reçu des octets sans header préalable
      log('chunk reçu sans header, ignoré');
      return;
    }
    rx.builder.add(bytes);
    if (rx.builder.length >= rx.expectedSize) {
      // fichier complet -> écriture sur disque
      final savedPath = await _saveIncoming(rx);
      log('fichier reçu et sauvegardé: $savedPath');
      receivedFilesController.add(
        savedPath,
      ); // notifie les listeners (UI, main.dart...)
      // ack pour permettre à (A) de fermer proprement
      try {
        dataChannel?.send(
          RTCDataChannelMessage(jsonEncode({'type': 'file_received'})),
        );
      } catch (_) {
        // si l'ack ne part pas, ce n'est pas grave: timeout côté A
      }
      _incoming = null;
      // petit délai pour laisser partir l'ack avant de fermer le canal
      await Future.delayed(const Duration(milliseconds: 200));
      await disconnect();
    }
  }

  // écrit le fichier reçu dans le dossier documents de l'app.
  Future<String> _saveIncoming(_IncomingFile rx) async {
    final dir = await getApplicationDocumentsDirectory();
    final safeName = _sanitizeFilename(rx.name);
    final path = '${dir.path}${Platform.pathSeparator}$safeName';
    final file = File(path);
    await file.writeAsBytes(rx.builder.takeBytes(), flush: true);
    return file.path;
  }

  // empêche les noms de fichier d'écraser un chemin (ex: "../etc/passwd").
  String _sanitizeFilename(String name) {
    final cleaned = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    return cleaned.isEmpty ? 'file.bin' : cleaned;
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

  void log(String msg) => debugPrint('[P2P] $msg');
}

// petit conteneur pour l'état de réception côté (B).
class _IncomingFile {
  final String name;
  final int expectedSize;
  final BytesBuilder builder = BytesBuilder(copy: false);

  _IncomingFile({required this.name, required this.expectedSize});
}
