import 'package:flutter/material.dart';
import 'app.dart';
import 'services/device_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    final deviceService = DeviceService();
    final result = await deviceService.sendDeviceData();
    print("Device enregistré avant affichage de l'app: $result");
  } catch (e) {
    print("Erreur enregistrement device: $e");
  }

  runApp(const ShareUpApp());
}
