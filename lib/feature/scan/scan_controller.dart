import 'dart:async';
import 'package:flutter/foundation.dart';
import 'scan_state.dart';
import 'package:share_up_front/services/device_service.dart';

class ScanController extends ValueNotifier<ScanState> {
  ScanController() : super(const ScanState());

  final DeviceService _deviceService = DeviceService();
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void startScan() {
    value = value.copyWith(scanning: true, devices: const []);

    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 2), () async {
      try {
        final nearbyDevices = await _deviceService.getNearbyDevices();

        // Conversion Map -> ScanDevice
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

        value = value.copyWith(
          scanning: false,
          devices: devices,
        );
      } catch (e) {
        value = value.copyWith(scanning: false);
      }
    });

  }
}