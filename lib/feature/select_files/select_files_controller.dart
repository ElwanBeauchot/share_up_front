import 'dart:convert'; // Transforme les données en JSON et inversement
import 'dart:io'; // verifie si le fichier existe

import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart' as file_picker;
import 'package:shared_preferences/shared_preferences.dart'; // sauvergarde fichier localement
import '../../services/p2p_service.dart';
import 'select_files_state.dart';

// CONSTANTES
const _recentFilesStorageKey =
    'select_files_recent_files'; // Nom ou on sauvergarde les fichiers localement
const _maxRecentFiles = 10; // limite de fichier sauvergarder en local

class SelectFilesController extends ValueNotifier<SelectFilesState> {
  final String deviceUuid;
  final P2PService _p2p = P2PService();

  SelectFilesController({required String deviceName, required this.deviceUuid})
    : super(SelectFilesState(deviceName: deviceName));

  Future<void> sendHello() async {
    value = value.copyWith(isSending: true, errorMessage: null);
    try {
      await _p2p.connectToDevice(deviceUuid);
    } catch (e) {
      value = value.copyWith(errorMessage: 'Échec de l\'envoi P2P: $e');
    } finally {
      value = value.copyWith(isSending: false);
    }
  }

  Future<void> loadFiles() async {
    value = value.copyWith(isLoading: true, errorMessage: null);

    try {
      final recentFiles =
          await _loadRecentFiles(); // Essaie de récuperer les fichiers sauvergarder localement

      value = value.copyWith(
        isLoading: false,
        errorMessage: null,
        files: recentFiles,
        animationSeed: value.animationSeed + 1,
      );
    } catch (_) {
      value = value.copyWith(
        isLoading: false,
        errorMessage: 'Impossible de charger les fichiers recents.',
      );
    }
  }

  Future<void> addFiles() async {
    try {
      final result = await file_picker.FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: file_picker.FileType.any,
        withData: false,
      );

      if (result == null || result.files.isEmpty) return;

      final pickedFiles = result.files
          .map(
            (file) => FileItemModel(
              name: file.name,
              size: _formatFileSize(file.size),
              type: _fileTypeFromExtension(file.extension),
              path: file.path,
              isSelected: true,
            ),
          )
          .toList();

      final mergedFiles = _mergeFiles(value.files, pickedFiles);
      await _saveRecentFiles(mergedFiles);

      value = value.copyWith(
        files: mergedFiles,
        errorMessage: null,
        animationSeed: value.animationSeed + 1,
      );
    } catch (_) {
      value = value.copyWith(
        errorMessage: 'Impossible d\'ajouter les fichiers selectionnes.',
      );
    }
  }

  void toggleFileSelection(int index) {
    final updatedFiles = List<FileItemModel>.from(value.files);
    final file = updatedFiles[index];
    updatedFiles[index] = file.copyWith(isSelected: !file.isSelected);

    value = value.copyWith(files: updatedFiles);
  }
}

Future<List<FileItemModel>> _loadRecentFiles() async {
  final prefs =
      await SharedPreferences.getInstance(); // Récupère les fichiers sauvergarder localement
  final storedFiles =
      prefs.getStringList(_recentFilesStorageKey) ??
      const []; // Si aucun fichier n'est sauvergarder = liste vide
  // On remet en fileItemModel et on verifie qu'ils sont encore present dans le telephone avec le path
  final files = storedFiles
      .map(_fileFromJson)
      .whereType<FileItemModel>()
      .where(_fileStillExists)
      .map((file) => file.copyWith(isSelected: false))
      .take(_maxRecentFiles)
      .toList();

  await _saveRecentFiles(files);
  return files;
}

Future<void> _saveRecentFiles(List<FileItemModel> files) async {
  final prefs =
      await SharedPreferences.getInstance(); // Sauvergarde les fichiers localement
  final filesToStore = files
      .where((file) => file.path != null)
      .take(_maxRecentFiles)
      .map(_fileToJson)
      .toList();

  await prefs.setStringList(_recentFilesStorageKey, filesToStore);
}

List<FileItemModel> _mergeFiles(
  List<FileItemModel> currentFiles,
  List<FileItemModel> pickedFiles,
) {
  final mergedFiles = List<FileItemModel>.from(currentFiles);

  for (final pickedFile in pickedFiles) {
    // boucle pour chaque fichier selectionné pour verifier s'il existe déjà dans les fichiers récents
    final existingIndex = mergedFiles.indexWhere(
      (file) => _isSameFile(file, pickedFile),
    );

    if (existingIndex == -1) {
      mergedFiles.insert(0, pickedFile);
    } else {
      final existingFile = mergedFiles.removeAt(existingIndex);
      mergedFiles.insert(
        0,
        pickedFile.copyWith(isSelected: existingFile.isSelected),
      );
    }
  }

  return mergedFiles
      .take(_maxRecentFiles)
      .toList(); // On limite la liste à 10 fichiers récents
}

bool _isSameFile(FileItemModel firstFile, FileItemModel secondFile) {
  final firstPath = firstFile.path;
  final secondPath = secondFile.path;

  if (firstPath != null && secondPath != null) {
    return firstPath == secondPath;
  }

  return firstFile.name == secondFile.name;
}

bool _fileStillExists(FileItemModel file) {
  final path = file.path;
  if (path == null || path.isEmpty) return false;

  return File(path).existsSync();
}

String _fileToJson(FileItemModel file) {
  return jsonEncode({
    'name': file.name,
    'size': file.size,
    'type': file.type.name,
    'path': file.path,
  });
}

FileItemModel? _fileFromJson(String source) {
  try {
    final data = jsonDecode(source);
    if (data is! Map<String, dynamic>) return null;

    final name = data['name'];
    final size = data['size'];
    final path = data['path'];
    final typeName = data['type'];

    if (name is! String || size is! String || path is! String) return null;

    return FileItemModel(
      name: name,
      size: size,
      type: _fileTypeFromName(typeName),
      path: path,
    );
  } catch (_) {
    return null;
  }
}

FileType _fileTypeFromName(Object? typeName) {
  if (typeName is! String) return FileType.document;

  return FileType.values.firstWhere(
    (type) => type.name == typeName,
    orElse: () => FileType.document,
  );
}

String _formatFileSize(int bytes) {
  if (bytes < 1024) return '$bytes B';

  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';

  final mb = kb / 1024;
  if (mb < 1024) return '${mb.toStringAsFixed(1)} MB';

  final gb = mb / 1024;
  return '${gb.toStringAsFixed(1)} GB';
}

FileType _fileTypeFromExtension(String? extension) {
  final normalizedExtension = extension?.toLowerCase();

  const imageExtensions = {'jpg', 'jpeg', 'png', 'gif', 'webp', 'heic', 'heif'};
  const videoExtensions = {'mp4', 'mov', 'avi', 'mkv', 'webm', 'm4v'};
  const audioExtensions = {'mp3', 'wav', 'aac', 'flac', 'm4a', 'ogg'};

  if (imageExtensions.contains(normalizedExtension)) return FileType.image;
  if (videoExtensions.contains(normalizedExtension)) return FileType.video;
  if (audioExtensions.contains(normalizedExtension)) return FileType.audio;

  return FileType.document;
}
