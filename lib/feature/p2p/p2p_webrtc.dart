// Création et configuration de la PeerConnection / DataChannel WebRTC.
// Mixin appliqué sur P2PService: branche les callbacks (ICE, état du canal,
// messages entrants) et instancie le FileReceiver côté (B).

part of '../../services/p2p_service.dart';

mixin P2PWebRTC on _P2PCore, P2PTransfer {
  Future<RTCPeerConnection> createPeer({
    required bool listenForRemoteChannel,
  }) async {
    final pc = await createPeerConnection(buildIceConfig());
    pc.onIceCandidate = sendIceCandidate;
    pc.onConnectionState = (s) => log('connection state: $s');
    pc.onIceConnectionState = (s) => log('ice connection state: $s');
    pc.onIceGatheringState = (s) => log('ice gathering state: $s');
    if (listenForRemoteChannel) {
      pc.onDataChannel = bindDataChannel;
    }
    return pc;
  }

  void bindDataChannel(RTCDataChannel ch) {
    dataChannel = ch;
    _receivedFilePaths.clear();
    _receiver = FileReceiver(
      sendAck: (json) => ch.send(RTCDataChannelMessage(json)),
      onProgress: (name, received, total) {
        _emitProgress(name: name, received: received, total: total);
      },
      onCompleted: (savedPath) {
        receivedFilesController.add(savedPath);
        _receivedFilePaths.add(savedPath);
      },
      onAllCompleted: _onAllTransfersDone,
    );
    ch.onDataChannelState = (s) {
      log('data channel: $s');
      if (s == RTCDataChannelState.RTCDataChannelOpen) {
        _setState(
          transferState.value.copyWith(
            phase: P2PPhase.transferring,
            transferredBytes: 0,
          ),
        );
        if (isCaller && pendingFilePaths.isNotEmpty) {
          // ignore: discarded_futures
          _runSender(pendingFilePaths);
        }
      }
    };
    ch.onMessage = (m) async {
      try {
        if (m.isBinary) {
          await _receiver?.handleBinary(m.binary);
        } else {
          await _onTextMessage(m.text);
        }
      } catch (e) {
        log('onMessage erreur: $e');
      }
    };
  }

  Future<void> sendIceCandidate(RTCIceCandidate c) async {
    if (myUuid == null || remoteDeviceUuid == null || c.candidate == null) {
      return;
    }
    try {
      await signaling!.send('ice', remoteDeviceUuid!, {
        'candidate': c.candidate,
        'sdpMid': c.sdpMid,
        'sdpMLineIndex': c.sdpMLineIndex,
      });
    } catch (e) {
      log('sendIce: $e');
    }
  }
}
