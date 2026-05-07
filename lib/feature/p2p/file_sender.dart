// Envoi de fichiers sur un DataChannel ouvert (côté A).
// Pour chaque fichier: {file_start} + N chunks binaires + ack {file_received}.
// Termine la session par {transfer_done}.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter_webrtc/flutter_webrtc.dart';

// Moins d’appels send/onMessage ; la pile SCTP fragmente si besoin.
const int _chunkSize = 256 * 1024;
// Plus de données « en vol » avant backpressure (meilleur débit si le lien suit).
const int _maxBuffered = 8 * 1024 * 1024;

typedef SenderProgress =
    void Function(int fileIndex, int totalFiles, int sent, int size);

class FileSender {
  final RTCDataChannel channel;
  Completer<void>? _ack;

  FileSender(this.channel);

  void notifyAckReceived() {
    if (_ack?.isCompleted == false) _ack!.complete();
  }

  Future<void> sendAll(List<String> paths, {SenderProgress? onProgress}) async {
    for (var i = 0; i < paths.length; i++) {
      _ack = Completer<void>();
      await _sendOne(paths[i], i, paths.length, onProgress);
      await _ack!.future;
    }
    _sendJson({'type': 'transfer_done'});
  }

  Future<void> _sendOne(
    String path,
    int index,
    int total,
    SenderProgress? onProgress,
  ) async {
    final file = File(path);
    if (!await file.exists()) {
      throw FileSystemException('fichier introuvable', path);
    }
    final size = await file.length();
    final name = file.uri.pathSegments.isNotEmpty
        ? file.uri.pathSegments.last
        : 'file.bin';

    _sendJson({'type': 'file_start', 'name': name, 'size': size});

    var sent = 0;
    onProgress?.call(index, total, sent, size);

    await for (final chunk in file.openRead()) {
      final bytes = chunk is Uint8List ? chunk : Uint8List.fromList(chunk);
      for (var o = 0; o < bytes.length; o += _chunkSize) {
        final slice = Uint8List.sublistView(
          bytes,
          o,
          math.min(o + _chunkSize, bytes.length),
        );
        await _waitForBuffer();
        channel.send(RTCDataChannelMessage.fromBinary(slice));
        sent += slice.lengthInBytes;
        onProgress?.call(index, total, sent, size);
      }
    }
  }

  void _sendJson(Map<String, Object?> data) =>
      channel.send(RTCDataChannelMessage(jsonEncode(data)));

  Future<void> _waitForBuffer() async {
    while ((channel.bufferedAmount ?? 0) > _maxBuffered) {
      await Future.delayed(const Duration(milliseconds: 20));
    }
  }
}
