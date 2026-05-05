// Pilote l'envoi/réception de fichier sur le DataChannel ouvert.
// Mixin appliqué sur P2PService: lance FileSender, gère ack final côté A,
// throttle les updates de progression et programme l'auto-dismiss du banner.

part of '../../services/p2p_service.dart';

mixin P2PTransfer on _P2PCore {
  Future<void> _runSender(String path) async {
    final ch = dataChannel;
    if (ch == null) return;
    final sender = FileSender(ch);
    try {
      await sender.send(
        path,
        onProgress: (sent, total) {
          _emitProgress(received: sent, total: total);
        },
      );
    } catch (e) {
      log('envoi échec: $e');
      _setState(transferState.value.copyWith(phase: P2PPhase.failed));
    }
  }

  Future<void> _onTextMessage(String raw) async {
    if (_receiver?.handleText(raw) ?? false) return;
    // Côté A: ack final → succès puis fermeture.
    if (raw.contains('file_received')) {
      log('ack reçu, succès');
      _setState(
        transferState.value.copyWith(
          phase: P2PPhase.success,
          transferredBytes: transferState.value.totalBytes,
        ),
      );
      _scheduleAutoDismiss(_successDelay);
    }
  }

  void _onFileReceived(String savedPath) {
    receivedFilesController.add(savedPath);
    _setState(
      transferState.value.copyWith(
        phase: P2PPhase.success,
        transferredBytes: transferState.value.totalBytes,
      ),
    );
    _scheduleAutoDismiss(_successDelay);
  }
}
