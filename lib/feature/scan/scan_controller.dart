import 'dart:async';
import 'package:flutter/foundation.dart';
import 'scan_state.dart';

class ScanController extends ValueNotifier<ScanState> {
  ScanController() : super(const ScanState());

  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void startScan() {
    // UI => loader, on vide la liste
    value = value.copyWith(scanning: true, devices: const []);

    // Simule un scan (plus tard tu remplaces par BLE/WiFi/Serveur)
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 2), () {
      value = value.copyWith(
        scanning: false,
        devices: const [
          ScanDevice(name: 'iPhone de Marie', platform: 'iOS'),
          ScanDevice(name: 'Samsung Galaxy S23', platform: 'Android'),
          ScanDevice(name: 'MacBook Pro', platform: 'macOS'),
          ScanDevice(name: 'iPad Air', platform: 'iOS'),
          ScanDevice(name: 'Pixel 8', platform: 'Android'),
        ],
      );
    });
  }
}
