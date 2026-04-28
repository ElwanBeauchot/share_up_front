import 'package:flutter/foundation.dart';
import '../../services/p2p_service.dart';
import 'select_files_state.dart';

class SelectFilesController extends ValueNotifier<SelectFilesState> {
  final String deviceUuid;
  final P2PService _p2p = P2PService();

  SelectFilesController({
    required String deviceName,
    required this.deviceUuid,
  }) : super(SelectFilesState(deviceName: deviceName));

  Future<void> sendHello() async {
    value = value.copyWith(isSending: true, errorMessage: null);
    try {
      _p2p.onMessageReceived = (text) {
        print('[P2P] message reçu: $text');
      };
      await _p2p.connectToDevice(deviceUuid);
      await _p2p.sendMessage();
    } catch (e) {
      value = value.copyWith(
        errorMessage: 'Échec de l\'envoi P2P: $e',
      );
    } finally {
      value = value.copyWith(isSending: false);
    }
  }

  Future<void> loadFiles() async {
    // TODO: remplacer ce faux chargement par la vraie recuperation
    // des fichiers disponibles ou des metadonnees utiles avant affichage.
    // Exemple plus tard:
    // 1. await api/service/controller pour charger les fichiers
    // 2. mapper la reponse back en FileItemModel
    // 3. mettre a jour files avec les vraies donnees
    value = value.copyWith(
      isLoading: true,
      errorMessage: null,
    );

    try {
      await Future.delayed(const Duration(milliseconds: 950));

      value = value.copyWith(
        isLoading: false,
        files: const [
          FileItemModel(
            name: 'Photo_vacances.jpg',
            size: '2.4 MB',
            type: FileType.image,
          ),
          FileItemModel(
            name: 'Document.pdf',
            size: '1.2 MB',
            type: FileType.document,
          ),
          FileItemModel(
            name: 'Musique.mp3',
            size: '4.8 MB',
            type: FileType.audio,
          ),
          FileItemModel(
            name: 'Vidéo_family.mp4',
            size: '12.5 MB',
            type: FileType.video,
          ),
          FileItemModel(
            name: 'Présentation.pptx',
            size: '3.1 MB',
            type: FileType.document,
          ),
        ],
        errorMessage: null,
        animationSeed: value.animationSeed + 1,
      );
    } catch (_) {
      value = value.copyWith(
        isLoading: false,
        errorMessage: 'Impossible de charger les fichiers disponibles.',
      );
    }
  }

  void toggleFileSelection(int index) {
    final updatedFiles = List<FileItemModel>.from(value.files);
    final file = updatedFiles[index];
    updatedFiles[index] = file.copyWith(
      isSelected: !file.isSelected,
    );

    value = value.copyWith(files: updatedFiles);
  }
}
