enum FileType {
  image,
  document,
  audio,
  video,
}

class FileItemModel {
  final String name;
  final String size;
  final FileType type;
  final bool isSelected;

  const FileItemModel({
    required this.name,
    required this.size,
    required this.type,
    this.isSelected = false,
  });

  FileItemModel copyWith({
    String? name,
    String? size,
    FileType? type,
    bool? isSelected,
  }) {
    return FileItemModel(
      name: name ?? this.name,
      size: size ?? this.size,
      type: type ?? this.type,
      isSelected: isSelected ?? this.isSelected,
    );
  }
}

class SelectFilesState {
  final String deviceName;
  final bool isLoading;
  final List<FileItemModel> files;
  final String? errorMessage;
  final int animationSeed;
  final bool isSending;

  const SelectFilesState({
    required this.deviceName,
    this.isLoading = true,
    this.files = const [],
    this.errorMessage,
    this.animationSeed = 0,
    this.isSending = false,
  });

  List<FileItemModel> get selectedFiles {
    return files.where((file) => file.isSelected).toList();
  }

  bool get hasSelectedFiles => selectedFiles.isNotEmpty;

  SelectFilesState copyWith({
    String? deviceName,
    bool? isLoading,
    List<FileItemModel>? files,
    String? errorMessage,
    int? animationSeed,
    bool? isSending,
  }) {
    return SelectFilesState(
      deviceName: deviceName ?? this.deviceName,
      isLoading: isLoading ?? this.isLoading,
      files: files ?? this.files,
      errorMessage: errorMessage,
      animationSeed: animationSeed ?? this.animationSeed,
      isSending: isSending ?? this.isSending,
    );
  }
}
