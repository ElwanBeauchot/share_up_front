// feature/select_files/select_files_state.dart
import 'dart:io';

enum FileKind { image, pdf, audio, video, ppt, other }

class SelectableFile {
  final String id;
  final String name;
  final int bytes;
  final FileKind kind;

  final String? path;

  const SelectableFile({
    required this.id,
    required this.name,
    required this.bytes,
    required this.kind,
    this.path,
  });

  bool get isLocal => path != null;

  File? get localFile => path == null ? null : File(path!);
}

class SelectFilesState {
  final String targetDeviceName;
  final List<SelectableFile> files;
  final Set<String> selectedIds;
  final bool isSending;

  const SelectFilesState({
    required this.targetDeviceName,
    required this.files,
    required this.selectedIds,
    required this.isSending,
  });

  bool get canSend => selectedIds.isNotEmpty && !isSending;

  SelectFilesState copyWith({
    String? targetDeviceName,
    List<SelectableFile>? files,
    Set<String>? selectedIds,
    bool? isSending,
  }) {
    return SelectFilesState(
      targetDeviceName: targetDeviceName ?? this.targetDeviceName,
      files: files ?? this.files,
      selectedIds: selectedIds ?? this.selectedIds,
      isSending: isSending ?? this.isSending,
    );
  }
}
