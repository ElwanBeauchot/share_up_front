import 'dart:async';
import 'package:flutter/foundation.dart';
import 'scan_state.dart';
import 'package:share_up_front/services/device_service.dart';

class ScanController extends ValueNotifier<ScanState> {
  ScanController() : super(const ScanState());

  final DeviceService _deviceService = DeviceService();
  Timer? _periodicTimer;

  @override
  void dispose() {
    _periodicTimer?.cancel();
    super.dispose();
  }

  void startScan() {
    value = value.copyWith(scanning: true, devices: const []);
    _performScan();

    if (_periodicTimer == null) {
      _periodicTimer = Timer.periodic(
        const Duration(seconds: 5),
        (_) => _performScan(),
      );
    }
  }

  void _performScan() async {
    try {
      final nearbyDevices = await _deviceService.getNearbyDevices();

      final devices = nearbyDevices.map<ScanDevice>((d) {
        final geo = d["geolocalisation"] ?? {};
        final coords = geo["coordinates"] ?? [0.0, 0.0];

        return ScanDevice(
          uuid: d["uuid"] ?? "",
          deviceName: d["device_name"] ?? "",
          os: d["os"] ?? "",
          lastSeen: d["last_seen"] ?? "",
          geolocalisation: GeoLoc(
            type: geo["type"] ?? "Point",
            coordinates: [
              (coords[0] as num).toDouble(),
              (coords[1] as num).toDouble(),
            ],
          ),
        );
      }).toList();

      value = value.copyWith(scanning: false, devices: devices);
    } catch (e) {
      debugPrint("Erreur scan: $e");
      value = value.copyWith(scanning: false, devices: []);
    }
  }
}
