// Réception et traitement des signaux SSE (offer/answer/ice/reject/cancel).
// Mixin appliqué sur P2PService: dispatcher de signaux + handshake côté A et B
// (acceptation utilisateur via Completer, création des SDP, gestion des ICE).

part of '../../services/p2p_service.dart';

mixin P2PSignaling on _P2PCore, P2PWebRTC {
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
      case 'reject':
        await onReject(msg);
        break;
      case 'cancel':
        await onCancel(msg);
        break;
    }
  }

  // (B) gère une offre entrante: demande d'accord à l'utilisateur via la
  // bannière (Completer), puis créé l'answer si accepté.
  Future<void> onOffer(Map<String, dynamic> msg) async {
    if (handlingOffer) {
      log('offer ignorée (déjà en cours)');
      return;
    }
    handlingOffer = true;
    try {
      if (peerConnection != null) await disconnect();
      myUuid ??= await deviceService.getDeviceUuid();
      remoteDeviceUuid = msg['from_uuid'] as String?;
      remoteDeviceName = msg['senderDeviceName'] as String?;
      ensureSignaling();

      final fileCount = (msg['fileCount'] as num?)?.toInt() ?? 1;
      final totalSize =
          (msg['totalSize'] as num?)?.toInt() ??
          (msg['fileSize'] as num?)?.toInt() ??
          0;
      final singleName = msg['fileName'] as String?;
      final fileName = fileCount > 1
          ? '$fileCount fichiers'
          : (singleName ?? 'fichier');

      _incomingDecision = Completer<bool>();
      _setState(
        TransferState(
          phase: P2PPhase.incomingRequest,
          fileName: fileName,
          totalBytes: totalSize,
          isSender: false,
        ),
      );

      final accepted = await _incomingDecision!.future;
      _incomingDecision = null;

      if (!accepted) {
        // Session déjà coupée pendant l'attente (cancel du peer ou disconnect
        // manuel): plus rien à signaler ni à afficher.
        if (remoteDeviceUuid == null) return;
        log('offre refusée par l\'utilisateur');
        try {
          await signaling!.send('reject', remoteDeviceUuid!, {});
        } catch (e) {
          log('envoi reject échoué: $e');
        }
        _setState(
          TransferState(
            phase: P2PPhase.rejected,
            fileName: fileName,
            isSender: false,
          ),
        );
        _scheduleAutoDismiss(_rejectedDelay);
        remoteDeviceUuid = null;
        return;
      }

      isCaller = false;
      _setState(transferState.value.copyWith(phase: P2PPhase.connecting));

      peerConnection = await createPeer(listenForRemoteChannel: true);
      await applyRemoteDescription(RTCSessionDescription(msg['sdp'], 'offer'));

      final answer = await peerConnection!.createAnswer();
      await peerConnection!.setLocalDescription(answer);
      await signaling!.send('answer', remoteDeviceUuid!, {'sdp': answer.sdp});
      log('answer envoyée');
    } catch (e) {
      log('onOffer échec: $e');
      _setState(transferState.value.copyWith(phase: P2PPhase.failed));
    } finally {
      handlingOffer = false;
    }
  }

  // (A) reçoit l'answer envoyée par (B).
  Future<void> onAnswer(Map<String, dynamic> msg) async {
    _setState(transferState.value.copyWith(phase: P2PPhase.connecting));
    await applyRemoteDescription(RTCSessionDescription(msg['sdp'], 'answer'));
  }

  // (A) reçoit un refus de (B).
  Future<void> onReject(Map<String, dynamic> msg) async {
    log('offer refusée par le peer');
    _setState(transferState.value.copyWith(phase: P2PPhase.rejected));
    await dataChannel?.close();
    await peerConnection?.close();
    peerConnection = null;
    dataChannel = null;
    pendingIce.clear();
    remoteDescriptionSet = false;
    _scheduleAutoDismiss(_rejectedDelay);
  }

  // Annulation par le peer (A pendant l'attente/transfert, ou B avant accept):
  // on coupe simplement la session, le banner se ferme.
  Future<void> onCancel(Map<String, dynamic> msg) async {
    log('annulé par le peer');
    await disconnect();
  }

  Future<void> onIce(Map<String, dynamic> msg) async {
    if (peerConnection == null) return;
    final cand = msg['candidate'] as String?;
    if (cand == null || cand.isEmpty) return;
    final c = RTCIceCandidate(cand, msg['sdpMid'], msg['sdpMLineIndex']);
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
}
