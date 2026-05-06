// Pilote l'envoi/réception de fichier sur le DataChannel ouvert.
// Mixin appliqué sur P2PService: lance FileSender, gère ack final côté A,
// throttle les updates de progression et programme l'auto-dismiss du banner.

part of '../../services/p2p_service.dart';

mixin P2PTransfer on _P2PCore {
  FileSender? _sender;

  Future<void> _runSender(List<String> paths) async {
    final ch = dataChannel;
    if (ch == null) return;
    final sender = _sender = FileSender(ch);
    try {
      await sender.sendAll(
        paths,
        onProgress: (i, total, sent, size) {
          _emitProgress(received: sent, total: size);
        },
      );
      _onAllTransfersDone();
    } catch (e) {
      log('envoi échec: $e');
      _setState(transferState.value.copyWith(phase: P2PPhase.failed));
    }
  }

  Future<void> _onTextMessage(String raw) async {
    if (_receiver?.handleText(raw) ?? false) return;
    if (raw.contains('file_received')) {
      log('ack reçu');
      _sender?.notifyAckReceived(); // débloque l'envoi du fichier suivant
    }
  }

  // Appelé par FileReceiver.onAllCompleted (côté B) OU par sendAll au retour (côté A).
  void _onAllTransfersDone() {
    _setState(
      transferState.value.copyWith(
        phase: P2PPhase.success,
        transferredBytes: transferState.value.totalBytes,
      ),
    );
    _scheduleAutoDismiss(_successDelay);
  }
}
