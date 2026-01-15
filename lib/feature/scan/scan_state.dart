class ScanState {
  final bool scanning;
  final List<ScanDevice> devices;

  const ScanState({this.scanning = true, this.devices = const []});

  ScanState copyWith({bool? scanning, List<ScanDevice>? devices}) {
    return ScanState(
      scanning: scanning ?? this.scanning,
      devices: devices ?? this.devices,
    );
  }
}

class GeoLoc {
  final String type;
  final List<double> coordinates;

  GeoLoc({required this.type, required this.coordinates});

  factory GeoLoc.fromJson(Map<String, dynamic> json) {
    return GeoLoc(
      type: json['type'],
      coordinates: List<double>.from(
        json['coordinates'].map((x) => x.toDouble()),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {'type': type, 'coordinates': coordinates};
  }
}

class ScanDevice {
  final String uuid;
  final String deviceName;
  final String os;
  final String lastSeen;
  final GeoLoc geolocalisation;

  ScanDevice({
    required this.uuid,
    required this.deviceName,
    required this.os,
    required this.lastSeen,
    required this.geolocalisation,
  });

  factory ScanDevice.fromJson(Map<String, dynamic> json) {
    return ScanDevice(
      uuid: json['uuid'],
      deviceName: json['device_name'],
      os: json['os'],
      lastSeen: json['last_seen'],
      geolocalisation: GeoLoc.fromJson(json['geolocalisation']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uuid': uuid,
      'device_name': deviceName,
      'os': os,
      'last_seen': lastSeen,
      'geolocalisation': geolocalisation.toJson(),
    };
  }
}
