class DeviceModel {
  final String uuid;
  final String name;
  final String os;
  final DateTime lastSeen;
  final String id;
  final double longitude;
  final double latitude;

  const DeviceModel({
    required this.uuid,
    required this.name,
    required this.os,
    required this.lastSeen,
    required this.id,
    required this.longitude,
    required this.latitude,
  });

  factory DeviceModel.fromJson(Map<String, dynamic> json) {
    return DeviceModel(
      uuid: json['uuid'] ?? '',
      name: json['device_name'] ?? '',
      os: json['os'] ?? '',
      lastSeen: DateTime.parse(json['last_seen'] ?? DateTime.now().toIso8601String()),
      id: json['_id'] ?? '',
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class DeviceScanModel {
  final String uuid;
  final String name;
  final String os;

  const DeviceScanModel({
    this.uuid = '',
    required this.name,
    required this.os,
  });

  factory DeviceScanModel.fromJson(Map<String, dynamic> json) {
    return DeviceScanModel(
      uuid: json['uuid'] ?? '',
      name: json['device_name'] ?? '',
      os: json['os'] ?? '',
    );
  }
}