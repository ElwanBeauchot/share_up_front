import 'package:flutter/foundation.dart';
import 'scan_state.dart';

class ScanController extends ValueNotifier<ScanState> {
  ScanController() : super(const ScanState());

  Future<void> loadDevices() async {
    // TODO: remplacer ce faux chargement par le vrai scan reseau/API.
    // Exemple plus tard:
    // 1. await deviceService.getNearbyDevices()
    // 2. mapper la reponse back en DeviceModel
    // 3. mettre a jour devices avec les vraies donnees
    value = value.copyWith(
      isLoading: true,
      errorMessage: null,
    );

    try {
      await Future.delayed(const Duration(milliseconds: 1400));

      value = value.copyWith(
        isLoading: false,
        devices: const [
          DeviceModel(
            name: 'iPhone de Marie',
            os: 'iOS',
          ),
          DeviceModel(
            name: 'Samsung Galaxy S23',
            os: 'Android',
          ),
          DeviceModel(
            name: 'MacBook Pro',
            os: 'macOS',
          ),
          DeviceModel(
            name: 'iPad Air',
            os: 'iOS',
          ),
          DeviceModel(
            name: 'Pixel 8',
            os: 'Android',
          ),
        ],
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
