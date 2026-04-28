import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app.dart';
import 'services/device_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([ // lock screen orientation to portrait
    DeviceOrientation.portraitUp,
  ]);
  await dotenv.load(fileName: ".env");
  try {
    final deviceService = DeviceService();
    final result = await deviceService.sendDeviceData();
    print("Device enregistré avant affichage de l'app: $result");
  } catch (e) {
    print("Erreur enregistrement device: $e");
  }

  runApp(const ShareUpApp());
}
