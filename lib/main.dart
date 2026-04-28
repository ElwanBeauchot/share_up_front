import 'package:flutter/material.dart';
import 'app.dart';
import 'services/device_service.dart';
import 'services/p2p_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  try {
    final deviceService = DeviceService();
    final result = await deviceService.sendDeviceData();
    print("Device enregistré avant affichage de l'app: $result");
  } catch (e) {
    print("Erreur enregistrement device: $e");
  }

  P2PService().onMessageReceived = (text) {
    print('[P2P] message reçu: $text');
  };
  P2PService().startListening();

  runApp(const ShareUpApp());
}
