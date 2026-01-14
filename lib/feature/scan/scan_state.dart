class ScanState {
  final bool scanning;
  final List<ScanDevice> devices;

  const ScanState({
    this.scanning = true,
    this.devices = const [],
  });

  ScanState copyWith({
    bool? scanning,
    List<ScanDevice>? devices,
  }) {
    return ScanState(
      scanning: scanning ?? this.scanning,
      devices: devices ?? this.devices,
    );
  }
}

class ScanDevice {
  final String name;
  final String platform;

  const ScanDevice({
    required this.name,
    required this.platform,
  });
}
