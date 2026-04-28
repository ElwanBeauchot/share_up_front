import 'package:flutter/material.dart';
import 'package:share_up_front/services/api_service.dart';
import 'package:flutter/services.dart';
import 'app.dart';
import 'services/device_service.dart';
import 'services/p2p_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    // lock screen orientation to portrait
    DeviceOrientation.portraitUp,
  ]);
  await dotenv.load(fileName: ".env");
  try {
    final apiService = ApiService();
    final deviceService = DeviceService(apiService);

    // on recupere les infos du device et on les envoie à l'api pour l'enregistrer
    // maybe faire un splash screen pour attendre que le process soit terminé
    final uuid = await deviceService.getDeviceUuid();
    final deviceInfo = await deviceService.getDeviceInfo();
    final position = await deviceService.getDevicePosition();

    final result = await deviceService.sendDeviceData(
      position,
      uuid,
      deviceInfo,
    );
    print("Device enregistré avant affichage de l'app: $result");
  } catch (e) {
    print("Erreur enregistrement device: $e");
  }

  P2PService().messages.listen((text) {
    print('[P2P] message reçu: $text');
  });
  P2PService().startListening(); // ouvre la connexion SSE /p2p/events/$myUuid

  runApp(const ShareUpApp());
}
