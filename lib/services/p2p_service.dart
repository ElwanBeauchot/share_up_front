// Orchestrateur P2P (singleton): API publique consommée par l'UI et l'app.
// État de session + transferState observable. Délègue aux mixins
// P2PSignaling / P2PWebRTC / P2PTransfer pour rester simple à lire.

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'api_service.dart';
import 'device_service.dart';
import '../feature/p2p/file_receiver.dart';
import '../feature/p2p/file_sender.dart';
import '../feature/p2p/ice_config.dart';
import '../feature/p2p/p2p_phase.dart';
import 'signaling_client.dart';

export '../feature/p2p/p2p_phase.dart';

part '../feature/p2p/p2p_signaling.dart';
part '../feature/p2p/p2p_transfer.dart';
part '../feature/p2p/p2p_webrtc.dart';

// Throttle des updates de progression vers la UI (~8 fps suffisent visuellement).
const Duration _progressThrottle = Duration(milliseconds: 120);
// Auto-dismiss des phases terminales (success/rejected/failed).
const Duration _successDelay = Duration(milliseconds: 800);
const Duration _rejectedDelay = Duration(seconds: 3);

// -------- État partagé entre les mixins --------
//
// Tous les champs et utilitaires vivent ici pour que les mixins puissent
// y accéder sans héritage compliqué. Seul P2PService est instancié.
abstract class _P2PCore {
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

  String? pendingFilePath;
  Completer<bool>? _incomingDecision;
  FileReceiver? _receiver;

  DateTime _lastProgressTick = DateTime.fromMillisecondsSinceEpoch(0);

  // Flux des fichiers reçus (chemin local sauvegardé), consommé par main.dart.
  final StreamController<String> receivedFilesController =
      StreamController<String>.broadcast();
  Stream<String> get receivedFiles => receivedFilesController.stream;

  // État observable consommé par TransferBanner.
  final ValueNotifier<TransferState> transferState =
      ValueNotifier(TransferState.idle);

  void log(String msg) => debugPrint('[P2P] $msg');

  // Implémenté par P2PService, utilisé par les mixins (cycle de vie).
  Future<void> disconnect();

  // -------- Helpers d'état partagés --------

  void _setState(TransferState s) {
    transferState.value = s;
  }

  // Throttle: on n'émet une update qu'au plus toutes les _progressThrottle,
  // sauf au début et à la fin (received==0 ou received>=total).
  void _emitProgress({String? name, required int received, required int total}) {
    final now = DateTime.now();
    final isEdge = received == 0 || received >= total;
    if (!isEdge && now.difference(_lastProgressTick) < _progressThrottle) {
      return;
    }
    _lastProgressTick = now;
    final cur = transferState.value;
    _setState(cur.copyWith(
      phase: P2PPhase.transferring,
      fileName: name ?? cur.fileName,
      totalBytes: total > 0 ? total : cur.totalBytes,
      transferredBytes: received,
    ));
  }

  void _scheduleAutoDismiss(Duration after) {
    Future.delayed(after, () async {
      // Ne ferme que si on est encore sur la même phase terminale.
      final p = transferState.value.phase;
      if (p == P2PPhase.success ||
          p == P2PPhase.rejected ||
          p == P2PPhase.failed) {
        await disconnect();
      }
    });
  }
}

class P2PService extends _P2PCore
    with P2PTransfer, P2PWebRTC, P2PSignaling {
  static final P2PService instance = P2PService.internal();
  factory P2PService() => instance;
  P2PService.internal();

  // -------- API publique --------

  // Boot de l'app: récupère l'UUID local et ouvre la SSE en écoute permanente.
  void startListening() {
    deviceService.getDeviceUuid().then((uuid) {
      myUuid = uuid;
      ensureSignaling();
    });
  }

  // (A) déclenche le handshake P2P vers (B) avec un fichier optionnel.
  Future<void> connectToDevice(String deviceUuid, {String? filePath}) async {
    log('connectToDevice → $deviceUuid (file=${filePath ?? 'aucun'})');
    await disconnect();
    try {
      pendingFilePath = filePath;
      remoteDeviceUuid = deviceUuid;
      myUuid ??= await deviceService.getDeviceUuid();
      isCaller = true;
      ensureSignaling();

      String? fileName;
      int fileSize = 0;
      if (filePath != null) {
        final f = File(filePath);
        if (await f.exists()) {
          fileName = f.uri.pathSegments.isNotEmpty
              ? f.uri.pathSegments.last
              : 'file.bin';
          fileSize = await f.length();
        }
      }
      _setState(TransferState(
        phase: P2PPhase.awaitingResponse,
        fileName: fileName,
        totalBytes: fileSize,
        isSender: true,
      ));

      peerConnection = await createPeer(listenForRemoteChannel: false);
      bindDataChannel(
        await peerConnection!.createDataChannel('files', RTCDataChannelInit()),
      );

      final offer = await peerConnection!.createOffer();
      await peerConnection!.setLocalDescription(offer);
      await signaling!.send('offer', deviceUuid, {
        'sdp': offer.sdp,
        'fileName': fileName,
        'fileSize': fileSize,
      });
      log('offer envoyée');
    } catch (e) {
      log('connectToDevice échec: $e');
      _setState(transferState.value.copyWith(phase: P2PPhase.failed));
      rethrow;
    }
  }

  // L'utilisateur (B) accepte la demande entrante affichée par la bannière.
  void acceptIncoming() {
    final c = _incomingDecision;
    if (c != null && !c.isCompleted) c.complete(true);
  }

  // L'utilisateur (B) refuse la demande entrante.
  void rejectIncoming() {
    final c = _incomingDecision;
    if (c != null && !c.isCompleted) c.complete(false);
  }

  // Annulation manuelle pendant l'attente / la connexion / le transfert.
  // Notifie le peer pour qu'il sorte de son état d'attente avant de couper.
  Future<void> cancel() async {
    log('annulation manuelle');
    final remote = remoteDeviceUuid;
    if (remote != null && signaling != null) {
      try {
        await signaling!.send('cancel', remote, {});
      } catch (e) {
        log('envoi cancel échoué: $e');
      }
    }
    await disconnect();
  }

  // Ferme proprement la session P2P et reset tous les flags.
  @override
  Future<void> disconnect() async {
    await dataChannel?.close();
    await peerConnection?.close();
    dataChannel = null;
    peerConnection = null;
    remoteDeviceUuid = null;
    pendingIce.clear();
    pendingFilePath = null;
    _receiver = null;
    if (_incomingDecision != null && !_incomingDecision!.isCompleted) {
      _incomingDecision!.complete(false);
    }
    _incomingDecision = null;
    remoteDescriptionSet = false;
    isCaller = false;
    _setState(TransferState.idle);
  }
}
