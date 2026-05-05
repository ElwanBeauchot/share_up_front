import '../../models/device_model.dart';

class DeviceModel {
  final String uuid;
  final String name;
  final String os;

  const DeviceModel({required this.uuid, required this.name, required this.os});

  factory DeviceModel.fromJson(Map<String, dynamic> json) {
    return DeviceModel(
      uuid: json['uuid'] ?? '',
      name: json['device_name'] ?? '',
      os: json['os'] ?? '',
    );
  }
}

class ScanState {
  final bool isLoading;
  final List<DeviceScanModel> devices;
  final String? errorMessage;
  final int animationSeed;

  const ScanState({
    this.isLoading = true,
    this.devices = const [],
    this.errorMessage,
    this.animationSeed = 0,
  });

  ScanState copyWith({
    bool? isLoading,
    List<DeviceScanModel>? devices,
    String? errorMessage,
    int? animationSeed,
  }) {
    return ScanState(
      isLoading: isLoading ?? this.isLoading,
      devices: devices ?? this.devices,
      errorMessage: errorMessage,
      animationSeed: animationSeed ?? this.animationSeed,
    );
  }
}
