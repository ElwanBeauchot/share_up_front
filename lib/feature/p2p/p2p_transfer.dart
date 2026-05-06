// Pilote l'envoi/réception de fichier sur le DataChannel ouvert.
// Mixin appliqué sur P2PService: lance FileSender, gère ack final côté A,
// throttle les updates de progression et programme l'auto-dismiss du banner.

part of '../../services/p2p_service.dart';

mixin P2PTransfer on _P2PCore {
  FileSender? _sender;
  final List<String> _receivedFilePaths = [];

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
      await _saveSendHistory(paths);
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
    if (!isCaller) {
      unawaited(_saveReceiveHistory());
    }

    _setState(
      transferState.value.copyWith(
        phase: P2PPhase.success,
        transferredBytes: transferState.value.totalBytes,
      ),
    );
    _scheduleAutoDismiss(_successDelay);
  }

  Future<void> _saveReceiveHistory() async {
    if (_receivedFilePaths.isEmpty) return;

    try {
      var totalSize = 0;
      final fileNames = <String>[];

      for (final path in _receivedFilePaths) {
        final file = File(path);
        if (!await file.exists()) continue;

        totalSize += await file.length();
        fileNames.add(
          file.uri.pathSegments.isNotEmpty
              ? file.uri.pathSegments.last
              : 'fichier',
        );
      }

      await receiveRecords(
        size: totalSize,
        fileCount: fileNames.length,
        time: DateTime.now(),
        deviceName: remoteDeviceName ?? remoteDeviceUuid ?? 'Appareil inconnu',
        fileNames: fileNames,
      );
    } catch (e) {
      log('sauvegarde historique réception échouée: $e');
    } finally {
      _receivedFilePaths.clear();
    }
  }

  Future<void> _saveSendHistory(List<String> paths) async {
    if (paths.isEmpty) return;

    try {
      var totalSize = 0;
      final fileNames = <String>[];

      for (final path in paths) {
        final file = File(path);
        if (!await file.exists()) continue;

        totalSize += await file.length();
        fileNames.add(
          file.uri.pathSegments.isNotEmpty
              ? file.uri.pathSegments.last
              : 'fichier',
        );
      }

      await sendRecords(
        size: totalSize,
        fileCount: fileNames.length,
        time: DateTime.now(),
        deviceName: remoteDeviceName ?? remoteDeviceUuid ?? 'Appareil inconnu',
        fileNames: fileNames,
      );
    } catch (e) {
      log('sauvegarde historique envoi échouée: $e');
    }
  }
}
