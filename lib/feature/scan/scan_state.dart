class DeviceModel {
  final String name;
  final String os;

  const DeviceModel({
    required this.name,
    required this.os,
  });
}

class ScanState {
  final bool isLoading;
  final List<DeviceModel> devices;
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
    List<DeviceModel>? devices,
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
