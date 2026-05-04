import 'dart:math';

import 'package:flutter/foundation.dart';
import '../../models/device_model.dart';
import '../../services/api_service.dart';
import '../../services/device_service.dart';
import 'scan_state.dart';

class ScanController extends ValueNotifier<ScanState> {
  ScanController() : super(const ScanState());

  Future<void> loadDevices() async {

    final apiService = ApiService();
    final deviceService = DeviceService(apiService);

    value = value.copyWith(
      isLoading: true,
      errorMessage: null,
    );

    try {
      final position = await deviceService.getDevicePosition();
      final myUuid = await deviceService.getDeviceUuid();
      final deviceInfo = await deviceService.getDeviceInfo();
      await deviceService.sendDeviceData(position, myUuid, deviceInfo); // on update la position de notre device
      final result = await deviceService.getNearbyDevices(position, myUuid);

      if (result.isNotEmpty){
        value = value.copyWith(
          isLoading: false,
          devices: result,
          errorMessage: null,
          animationSeed: value.animationSeed + 1,
        );
      } else {
        value = value.copyWith(
          isLoading: false,
          devices: [],
          errorMessage: 'Aucun appareil à proximité.',
        );
      }


    } catch (_) {
      value = value.copyWith(
        isLoading: false,
        errorMessage: 'Impossible de charger les appareils a proximite.',
      );
    }
  }
}
