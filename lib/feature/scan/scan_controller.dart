import 'dart:math';

import 'package:flutter/foundation.dart';
import '../../services/device_service.dart';
import 'scan_state.dart';

class ScanController extends ValueNotifier<ScanState> {
  ScanController() : super(const ScanState());

  Future<void> loadDevices() async {
    final deviceService = DeviceService();
    value = value.copyWith(
      isLoading: true,
      errorMessage: null,
    );

    try {
      final result = await deviceService.getNearbyDevices();
      List<DeviceModel> devices = result.map((e)=> DeviceModel.fromJson(e)).toList();
      value = value.copyWith(
        isLoading: false,
        devices: devices,
        errorMessage: null,
        animationSeed: value.animationSeed + 1,
      );
    } catch (_) {
      value = value.copyWith(
        isLoading: false,
        errorMessage: 'Impossible de charger les appareils a proximite.',
      );
    }
  }
}
