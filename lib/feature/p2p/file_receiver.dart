// Réception d'un fichier sur un DataChannel (côté B).
// Header file_start -> chunks binaires -> ack file_received.
// Médias (image/vidéo) -> galerie. Sinon -> boîte "Enregistrer sous".

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';

typedef ReceiverProgressCallback =
    void Function(String fileName, int received, int total);
typedef ReceiverCompletedCallback = void Function(String savedPath);
typedef AckSender = void Function(String json);

const _imageExts = {'.jpg', '.jpeg', '.png', '.gif', '.webp', '.heic', '.bmp'};
const _videoExts = {'.mp4', '.mov', '.mkv', '.webm', '.3gp', '.avi'};

class FileReceiver {
  final ReceiverProgressCallback? onProgress;
  final ReceiverCompletedCallback? onCompleted;
  final VoidCallback? onAllCompleted;
  final AckSender sendAck;

  _Incoming? _current;

  FileReceiver({
    required this.sendAck,
    this.onProgress,
    this.onCompleted,
    this.onAllCompleted,
  });

  bool handleText(String raw) {
    final data = jsonDecode(raw);
    if (data is! Map<String, dynamic>) return false;

    if (data['type'] == 'transfer_done') {
      onAllCompleted?.call();
      return true;
    }
    if (data['type'] != 'file_start') return false;

    final name = data['name'] as String? ?? 'file.bin';
    final size = (data['size'] as num?)?.toInt() ?? 0;
    _current = _Incoming(name: name, expectedSize: size);
    onProgress?.call(name, 0, size);
    return true;
  }

  Future<void> handleBinary(Uint8List bytes) async {
    final rx = _current;
    if (rx == null) return;

    rx.builder.add(bytes);
    onProgress?.call(rx.name, rx.builder.length, rx.expectedSize);
    if (rx.builder.length < rx.expectedSize) return;

    final savedPath = await _saveIncoming(rx);
    debugPrint('[FileReceiver] sauvegardé: $savedPath');
    try {
      sendAck(jsonEncode({'type': 'file_received'}));
    } catch (_) {}
    _current = null;
    onCompleted?.call(savedPath);
  }

  Future<String> _saveIncoming(_Incoming rx) async {
    final name = _sanitizeFilename(rx.name);
    final dir = await getTemporaryDirectory();
    final tmp = File('${dir.path}${Platform.pathSeparator}$name');
    await tmp.writeAsBytes(rx.builder.takeBytes(), flush: true);

    final ext = _ext(name);
    final isImage = _imageExts.contains(ext);
    if (isImage || _videoExts.contains(ext)) {
      final saved = await _saveToGallery(tmp, name, isImage: isImage);
      if (saved != null) {
        tmp.delete().ignore();
        return saved;
      }
    }

    try {
      final saved = await FlutterFileDialog.saveFile(
        params: SaveFileDialogParams(sourceFilePath: tmp.path, fileName: name),
      );
      if (saved != null && saved.isNotEmpty) {
        tmp.delete().ignore();
        return saved;
      }
    } catch (e) {
      debugPrint('[FileReceiver] saveFile: $e');
    }
    return tmp.path;
  }

  Future<String?> _saveToGallery(
    File file,
    String name, {
    required bool isImage,
  }) async {
    final ps = await PhotoManager.requestPermissionExtend();
    if (!ps.hasAccess) return null;
    try {
      final asset = isImage
          ? await PhotoManager.editor.saveImageWithPath(file.path, title: name)
          : await PhotoManager.editor.saveVideo(file, title: name);
      return (await asset.file)?.path;
    } catch (e) {
      debugPrint('[FileReceiver] saveToGallery: $e');
      return null;
    }
  }

  static String _ext(String name) {
    final i = name.lastIndexOf('.');
    return i < 0 ? '' : name.substring(i).toLowerCase();
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
