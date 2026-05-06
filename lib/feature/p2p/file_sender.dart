// Envoi d'un fichier sur un DataChannel ouvert (côté A).
// Protocole: header texte {type:'file_start', name, size} puis N chunks
// binaires de 16 KB avec backpressure SCTP via bufferedAmount.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

// Taille de chunk pour le DataChannel SCTP (recommandé ≤ 16 KB).
const int _chunkSize = 16 * 1024;
// Au-delà de cette quantité bufferisée côté SCTP, on attend.
const int _maxBuffered = 1 * 1024 * 1024;

typedef ProgressCallback = void Function(int sent, int total);

// Envoie un fichier sur un DataChannel ouvert.
// Protocole minimal:
//   1) {type:'file_start', name, size} en texte
//   2) N chunks binaires
//   3) côté B renvoie {type:'file_received'} (géré par l'orchestrateur)
class FileSender {
  final RTCDataChannel channel;
  // Completer résolu quand le récepteur renvoie {type:'file_received'}.
  Completer<void>? _ackCompleter;

  FileSender(this.channel);

  // À appeler depuis l'orchestrateur quand un ack arrive.
  void notifyAckReceived() {
    final c = _ackCompleter;
    if (c != null && !c.isCompleted) c.complete();
  }

  // Envoie N fichiers d'affilée, puis signale la fin de session.
  Future<void> sendAll(
    List<String> paths, {
    void Function(int fileIndex, int total, int sent, int size)? onProgress,
  }) async {
    for (var i = 0; i < paths.length; i++) {
      _ackCompleter = Completer<void>();
      await _sendOne(
        paths[i],
        onProgress: (sent, size) =>
            onProgress?.call(i, paths.length, sent, size),
      );
      await _ackCompleter!.future; // attend file_received avant le suivant
    }
    channel.send(RTCDataChannelMessage(jsonEncode({'type': 'transfer_done'})));
  }

  Future<void> _sendOne(String path, {ProgressCallback? onProgress}) async {
    final file = File(path);
    if (!await file.exists()) {
      throw FileSystemException('fichier introuvable', path);
    }
    final size = await file.length();
    final name = file.uri.pathSegments.isNotEmpty
        ? file.uri.pathSegments.last
        : 'file.bin';

    channel.send(
      RTCDataChannelMessage(
        jsonEncode({'type': 'file_start', 'name': name, 'size': size}),
      ),
    );

    var sent = 0;
    onProgress?.call(sent, size);

    await for (final chunk in file.openRead()) {
      for (var offset = 0; offset < chunk.length; offset += _chunkSize) {
        final end = (offset + _chunkSize <= chunk.length)
            ? offset + _chunkSize
            : chunk.length;
        final slice = Uint8List.fromList(chunk.sublist(offset, end));
        await _waitForBuffer();
        channel.send(RTCDataChannelMessage.fromBinary(slice));
        sent += slice.length;
        onProgress?.call(sent, size);
      }
    }
  }

  Future<void> _waitForBuffer() async {
    while ((channel.bufferedAmount ?? 0) > _maxBuffered) {
      await Future.delayed(const Duration(milliseconds: 20));
    }
  }
}
