// feature/select_files/select_files_controller.dart
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'select_files_state.dart';
import '../../services/p2p_service.dart';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/services.dart';

class SelectFilesController extends ChangeNotifier {
  SelectFilesState _state;
  final String _targetDeviceUuid;
  final P2PService _p2pService = P2PService.instance;

  SelectFilesState get state => _state;

  SelectFilesController({
    required String targetDeviceName,
    required String targetDeviceUuid,
    List<SelectableFile>? initialFiles,
  }) : _targetDeviceUuid = targetDeviceUuid,
       _state = SelectFilesState(
         targetDeviceName: targetDeviceName,
         files: initialFiles ?? const [],
         selectedIds: <String>{},
         isSending: false,
       );

  void toggleSelection(String id) {
    final next = Set<String>.from(_state.selectedIds);
    if (next.contains(id)) {
      next.remove(id);
    } else {
      next.add(id);
    }
    _state = _state.copyWith(selectedIds: next);
    notifyListeners();
  }

  void clearSelection() {
    _state = _state.copyWith(selectedIds: <String>{});
    notifyListeners();
  }

  Future<void> addFilesFromDevice() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: false,
      type: FileType.any,
    );

    if (result == null) return;

    final newFiles = result.files
        .where((f) => f.path != null)
        .map(
          (f) => SelectableFile(
            id: _randomId(),
            name: f.name,
            bytes: f.size,
            kind: _inferKind(f.name),
            path: f.path,
          ),
        )
        .toList();

    final merged = [...newFiles, ..._state.files];

    _state = _state.copyWith(files: merged);
    notifyListeners();
  }

  Future<void> sendSelected() async {
    if (!_state.canSend) return;

    _state = _state.copyWith(isSending: true);
    notifyListeners();

    try {
      await _p2pService.connectToDevice(_targetDeviceUuid);
      final selected = _state.files
          .where((f) => _state.selectedIds.contains(f.id))
          .toList();
      for (final file in selected) {
        await _sendFile(file);
      }
      clearSelection();
      await _p2pService.disconnect();
    } catch (e) {
      debugPrint("Erreur envoi: $e");
    } finally {
      _state = _state.copyWith(isSending: false);
      notifyListeners();
    }
  }

  Future<void> _sendFile(SelectableFile file) async {
    final fileBytes = file.path != null
        ? await File(file.path!).readAsBytes()
        : (await rootBundle.load(
            'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png',
          )).buffer.asUint8List();

    final dataUri =
        'data:${_getMimeType(file.kind)};base64,${base64Encode(fileBytes)}';

    for (int i = 0; i < 30; i++) {
      if (_p2pService.dataChannelState ==
          RTCDataChannelState.RTCDataChannelOpen) {
        await _p2pService.sendMessage(dataUri);
        return;
      }
      await Future.delayed(const Duration(milliseconds: 500));
    }
  }

  String _getMimeType(FileKind kind) {
    switch (kind) {
      case FileKind.image:
        return 'image/png';
      case FileKind.pdf:
        return 'application/pdf';
      case FileKind.audio:
        return 'audio/mpeg';
      case FileKind.video:
        return 'video/mp4';
      case FileKind.ppt:
        return 'application/vnd.ms-powerpoint';
      case FileKind.other:
        return 'application/octet-stream';
    }
  }

  FileKind _inferKind(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.heic'))
      return FileKind.image;

    if (lower.endsWith('.pdf')) return FileKind.pdf;

    if (lower.endsWith('.mp3') ||
        lower.endsWith('.wav') ||
        lower.endsWith('.m4a') ||
        lower.endsWith('.aac') ||
        lower.endsWith('.flac'))
      return FileKind.audio;

    if (lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.mkv') ||
        lower.endsWith('.avi'))
      return FileKind.video;

    if (lower.endsWith('.ppt') || lower.endsWith('.pptx')) return FileKind.ppt;

    return FileKind.other;
  }

  String _randomId() {
    final r = Random();
    return '${DateTime.now().microsecondsSinceEpoch}_${r.nextInt(1 << 32)}';
  }
}
