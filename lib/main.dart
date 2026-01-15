import 'package:flutter/material.dart';
import 'app.dart';
import 'services/device_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    final deviceService = DeviceService();
    await deviceService.sendDeviceData();
  } catch (e) {
    print('[APP] Erreur enregistrement device');
  }

  runApp(const ShareUpApp());
}
