import 'dart:convert'; // Transforme les données en JSON et inversement
import 'dart:io'; // verifie si le fichier existe

import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart' as file_picker;
import 'package:image_picker/image_picker.dart' as image_picker;
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:shared_preferences/shared_preferences.dart'; // sauvergarde fichier localement
import '../../services/p2p_service.dart';
import 'select_files_state.dart';

// CONSTANTES
const _recentFilesStorageKey =
    'select_files_recent_files'; // Nom ou on sauvergarde les fichiers localement
const _maxRecentFiles = 10; // limite de fichier sauvergarder en local
const _mediaStorageFolderName = 'recent_media_files';

class SelectFilesController extends ValueNotifier<SelectFilesState> {
  final String deviceUuid;
  final P2PService _p2p = P2PService();

  SelectFilesController({
    required String deviceName,
    required this.deviceUuid,
  }) // Besoin nom de l'appareil cible pour le titre de la page
  : super(SelectFilesState(deviceName: deviceName));

  Future<void> sendSelectedFiles() async {
    final selected = value.selectedFiles;
    if (selected.isEmpty) return;

    // KISS: on envoie uniquement le premier fichier sélectionné.
    final filePath = selected.first.path;
    if (filePath == null || filePath.isEmpty) {
      value = value.copyWith(errorMessage: 'Chemin du fichier introuvable.');
      return;
    }

    value = value.copyWith(isSending: true, errorMessage: null);
    try {
      await _p2p.connectToDevice(deviceUuid, filePath: filePath);
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
              // transforme en fileItemModel p
              name: file.name,
              size: _formatFileSize(file.size),
              type: _fileTypeFromExtension(file.extension),
              path: file.path,
              isSelected: true,
            ),
          )
          .toList();

      await _addPickedFiles(pickedFiles);
    } catch (_) {
      value = value.copyWith(
        errorMessage: 'Impossible d\'ajouter les fichiers selectionnes.',
      );
    }
  }

  Future<void> addMediaAsset(AssetEntity asset) async {
    await addMediaAssets([asset]);
  }

  Future<void> addMediaAssets(List<AssetEntity> assets) async {
    try {
      if (assets.isEmpty) return;

      final pickedFiles = <FileItemModel>[];

      // On regarde chaque asset + leurs chemin et on les stock dans le dossier local
      for (final asset in assets) {
        final mediaFile = await asset.file;
        if (mediaFile == null) continue;

        final title = await asset.titleAsync;
        final savedFile = await _copyMediaToAppStorage(
          mediaFile,
          fileName: title.isNotEmpty
              ? title
              : _fileNameFromPath(mediaFile.path),
          stableId: asset.id,
        );
        final fileName = _fileNameFromPath(savedFile.path);

        pickedFiles.add(
          FileItemModel(
            name: fileName,
            size: _formatFileSize(await savedFile.length()),
            type: asset.type == AssetType.video
                ? FileType.video
                : FileType.image,
            path: savedFile.path,
            isSelected: true,
          ),
        );
      }

      await _addPickedFiles(pickedFiles);
    } catch (_) {
      value = value.copyWith(
        errorMessage: 'Impossible d\'ajouter les photos ou videos.',
      );
    }
  }

  Future<void> addMediaFilesFromAlbum() async {
    try {
      final picker = image_picker.ImagePicker();
      final result = await picker.pickMultipleMedia();

      if (result.isEmpty) return;

      final pickedFiles = <FileItemModel>[];

      // On regarde chaque asset + leurs chemin et on les stock dans le dossier local
      for (final media in result) {
        final sourceFile = File(media.path);
        final savedFile = await _copyMediaToAppStorage(
          sourceFile,
          fileName: media.name.isNotEmpty
              ? media.name
              : _fileNameFromPath(sourceFile.path),
        );
        final fileName = _fileNameFromPath(savedFile.path);

        pickedFiles.add(
          FileItemModel(
            name: fileName,
            size: _formatFileSize(await savedFile.length()),
            type: _fileTypeFromExtension(_extensionFromName(fileName)),
            path: savedFile.path,
            isSelected: true,
          ),
        );
      }

      await _addPickedFiles(pickedFiles);
    } catch (_) {
      value = value.copyWith(
        errorMessage: 'Impossible d\'ajouter les photos ou videos.',
      );
    }
  }

  // On donne l'index d'un fichier puis on l'inverse dans une nouvelle liste
  void toggleFileSelection(int index) {
    final updatedFiles = List<FileItemModel>.from(value.files);
    final file = updatedFiles[index];
    updatedFiles[index] = file.copyWith(isSelected: !file.isSelected);

    value = value.copyWith(files: updatedFiles);
  }

  Future<void> _addPickedFiles(List<FileItemModel> pickedFiles) async {
    final mergedFiles = _mergeFiles(value.files, pickedFiles);
    await _saveRecentFiles(mergedFiles);

    value = value.copyWith(
      files: mergedFiles,
      errorMessage: null,
      animationSeed: value.animationSeed + 1,
    );
  }
}

// Stocke les fichiers media pour shared preferences pour y acceder plus tard
Future<File> _copyMediaToAppStorage(
  File sourceFile, {
  required String fileName,
  String? stableId,
}) async {
  final appDirectory = await getApplicationDocumentsDirectory();
  final mediaDirectory = Directory(
    '${appDirectory.path}/$_mediaStorageFolderName',
  );

  if (!mediaDirectory.existsSync()) {
    mediaDirectory.createSync(recursive: true);
  }

  final safeFileName = _safeFileName(fileName); // Nom du fichier
  final safeStableId = stableId == null
      ? null
      : _safeFileName(
          stableId,
        ); // Récuperation d'un stable id pour le rajouter dans le name
  final destinationName = safeStableId == null
      ? '${DateTime.now().microsecondsSinceEpoch}_$safeFileName'
      : '${safeStableId}_$safeFileName';

  return sourceFile.copy('${mediaDirectory.path}/$destinationName');
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
      mergedFiles.removeAt(existingIndex);
      mergedFiles.insert(0, pickedFile.copyWith(isSelected: true));
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
    if (firstPath == secondPath) return true;
  }

  return firstFile.name == secondFile.name && firstFile.size == secondFile.size;
}

bool _fileStillExists(FileItemModel file) {
  final path = file.path;
  if (path == null || path.isEmpty) return false;

  return File(path).existsSync();
}

String _fileNameFromPath(String path) {
  // Récupère le nom du fichier à partir de son chemin
  return path.split(Platform.pathSeparator).last;
}

String? _extensionFromName(String name) {
  // Récupère l'extension du fichier à partir de son nom
  final dotIndex = name.lastIndexOf('.');
  if (dotIndex == -1 || dotIndex == name.length - 1) return null;

  return name.substring(dotIndex + 1);
}

String _safeFileName(String fileName) {
  // Récupère le nom du fichier à partir de son chemin
  final cleanName = fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
  if (cleanName.isNotEmpty) return cleanName;

  return 'media_${DateTime.now().millisecondsSinceEpoch}';
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
