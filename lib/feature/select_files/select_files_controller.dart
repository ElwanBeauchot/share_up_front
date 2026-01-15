// feature/select_files/select_files_controller.dart
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'select_files_state.dart';

class SelectFilesController extends ChangeNotifier {
  SelectFilesState _state;

  SelectFilesState get state => _state;

  SelectFilesController({
    required String targetDeviceName,
    List<SelectableFile>? initialFiles,
  }) : _state = SelectFilesState(
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

    final picked = result.files;

    final newFiles = picked
        .where((f) => f.path != null) // sur certaines plateformes web path peut être null
        .map((f) {
      final kind = _inferKind(f.name);
      return SelectableFile(
        id: _randomId(),
        name: f.name,
        bytes: f.size,
        kind: kind,
        path: f.path,
      );
    })
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
      final selected = _state.files
          .where((f) => _state.selectedIds.contains(f.id))
          .toList();

      // TODO: ici tu branches ton envoi réseau (WiFi Direct/BLE/HTTP etc.)
      // Par exemple:
      // await _transferService.sendFiles(selected);

      await Future.delayed(const Duration(milliseconds: 900)); // placeholder

      // après succès:
      clearSelection();
    } finally {
      _state = _state.copyWith(isSending: false);
      notifyListeners();
    }
  }

  FileKind _inferKind(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.heic')) return FileKind.image;

    if (lower.endsWith('.pdf')) return FileKind.pdf;

    if (lower.endsWith('.mp3') ||
        lower.endsWith('.wav') ||
        lower.endsWith('.m4a') ||
        lower.endsWith('.aac') ||
        lower.endsWith('.flac')) return FileKind.audio;

    if (lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.mkv') ||
        lower.endsWith('.avi')) return FileKind.video;

    if (lower.endsWith('.ppt') || lower.endsWith('.pptx')) return FileKind.ppt;

    return FileKind.other;
  }

  String _randomId() {
    final r = Random();
    return '${DateTime.now().microsecondsSinceEpoch}_${r.nextInt(1 << 32)}';
  }
}
