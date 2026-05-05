// Modèle d'état observable d'une session P2P, consommé par TransferBanner.
// Définit l'enum P2PPhase (idle → request/await → connecting → transferring →
// success/rejected/failed) et la classe immutable TransferState (copyWith).

enum P2PPhase {
  idle,
  awaitingResponse,
  incomingRequest,
  connecting,
  transferring,
  success,
  rejected,
  failed,
}

class TransferState {
  final P2PPhase phase;
  final String? fileName;
  final int totalBytes;
  final int transferredBytes;
  final bool isSender;

  const TransferState({
    this.phase = P2PPhase.idle,
    this.fileName,
    this.totalBytes = 0,
    this.transferredBytes = 0,
    this.isSender = false,
  });

  static const TransferState idle = TransferState();

  double get progress {
    if (totalBytes <= 0) return 0;
    final p = transferredBytes / totalBytes;
    if (p < 0) return 0;
    if (p > 1) return 1;
    return p;
  }

  TransferState copyWith({
    P2PPhase? phase,
    String? fileName,
    int? totalBytes,
    int? transferredBytes,
    bool? isSender,
  }) {
    return TransferState(
      phase: phase ?? this.phase,
      fileName: fileName ?? this.fileName,
      totalBytes: totalBytes ?? this.totalBytes,
      transferredBytes: transferredBytes ?? this.transferredBytes,
      isSender: isSender ?? this.isSender,
    );
  }
}
