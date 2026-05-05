// Réception d'un fichier sur un DataChannel (côté B).
// Lit le header file_start, accumule les chunks binaires, sauvegarde via la
// boîte "Enregistrer sous" du système puis envoie l'ack file_received.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:path_provider/path_provider.dart';

typedef ReceiverProgressCallback = void Function(
  String fileName,
  int received,
  int total,
);
typedef ReceiverCompletedCallback = void Function(String savedPath);
typedef AckSender = void Function(String json);

// Réception d'un fichier sur un DataChannel.
// Stateful: on garde le header courant + le builder d'octets entre les chunks.
class FileReceiver {
  final ReceiverProgressCallback? onProgress;
  final ReceiverCompletedCallback? onCompleted;
  final AckSender sendAck;

  _Incoming? _current;

  FileReceiver({
    required this.sendAck,
    this.onProgress,
    this.onCompleted,
  });

  // Renvoie true si le message a été consommé (header / ack), false sinon.
  // L'orchestrateur peut ainsi gérer ses propres messages (ex: file_received).
  bool handleText(String raw) {
    final data = jsonDecode(raw);
    if (data is! Map<String, dynamic>) return false;
    if (data['type'] != 'file_start') return false;
    final name = data['name'] as String? ?? 'file.bin';
    final size = (data['size'] as num?)?.toInt() ?? 0;
    debugPrint('[FileReceiver] header reçu: "$name" ($size octets)');
    _current = _Incoming(name: name, expectedSize: size);
    onProgress?.call(name, 0, size);
    return true;
  }

  Future<void> handleBinary(Uint8List bytes) async {
    final rx = _current;
    if (rx == null) {
      debugPrint('[FileReceiver] chunk reçu sans header, ignoré');
      return;
    }
    rx.builder.add(bytes);
    onProgress?.call(rx.name, rx.builder.length, rx.expectedSize);

    if (rx.builder.length >= rx.expectedSize) {
      final savedPath = await _saveIncoming(rx);
      debugPrint('[FileReceiver] sauvegardé: $savedPath');
      try {
        sendAck(jsonEncode({'type': 'file_received'}));
      } catch (_) {
        // ack perdu = pas grave, l'autre côté gère son timeout.
      }
      _current = null;
      onCompleted?.call(savedPath);
    }
  }

  Future<String> _saveIncoming(_Incoming rx) async {
    final dir = await getTemporaryDirectory();
    final safeName = _sanitizeFilename(rx.name);
    final path = '${dir.path}${Platform.pathSeparator}$safeName';
    final tmpFile = File(path);
    await tmpFile.writeAsBytes(rx.builder.takeBytes(), flush: true);

    try {
      final saved = await FlutterFileDialog.saveFile(
        params: SaveFileDialogParams(
          sourceFilePath: tmpFile.path,
          fileName: safeName,
        ),
      );
      if (saved != null && saved.isNotEmpty) {
        try {
          await tmpFile.delete();
        } catch (_) {}
        return saved;
      }
      debugPrint(
        '[FileReceiver] save annulé, fichier dans cache: ${tmpFile.path}',
      );
    } catch (e) {
      debugPrint('[FileReceiver] saveFile échec: $e');
    }
    return tmpFile.path;
  }

  static String _sanitizeFilename(String name) {
    final cleaned = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    return cleaned.isEmpty ? 'file.bin' : cleaned;
  }
}

class _Incoming {
  final String name;
  final int expectedSize;
  final BytesBuilder builder = BytesBuilder(copy: false);

  _Incoming({required this.name, required this.expectedSize});
}
