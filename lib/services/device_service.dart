import 'package:device_info_plus/device_info_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'api_service.dart';

class DeviceService {
  final ApiService _api = ApiService();
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  final Uuid _uuid = Uuid();

  static const String _uuidKey = "device_uuid";

  /// Récupère ou génère un UUID unique et persistant
  Future<String> _getDeviceUuid() async {
    final prefs = await SharedPreferences.getInstance();
    String? uuid = prefs.getString(_uuidKey);
    if (uuid == null) {
      uuid = _uuid.v4();
      await prefs.setString(_uuidKey, uuid);
    }
    return uuid;
  }

  /// Récupère l'UUID du device (méthode publique)
  Future<String> getDeviceUuid() async {
    return _getDeviceUuid();
  }

  /// Récupère les infos du device + géolocalisation
  Future<Map<String, dynamic>> getDeviceData() async {
    String deviceName = "Unknown";
    String os = "Unknown";

    try {
      final platform = await _deviceInfo.deviceInfo;
      if (platform is AndroidDeviceInfo) {
        final brand = platform.brand;
        final model = platform.model;
        deviceName = "$brand $model".trim();
        if (deviceName.isEmpty) deviceName = "Android Device";
        os = "Android ${platform.version.release}";
      } else if (platform is IosDeviceInfo) {
        deviceName = platform.name;
        os = "iOS ${platform.systemVersion}";
      }
    } catch (e) {}

    final deviceUuid = await _getDeviceUuid();

    Position position;
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception("Service de localisation désactivé");
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception("Permission localisation refusée");
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception("Permission localisation refusée définitivement");
      }

      position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      position = Position(
        longitude: 0.0,
        latitude: 0.0,
        timestamp: DateTime.now(),
        accuracy: 0.0,
        altitude: 0.0,
        heading: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
        headingAccuracy: 0.0,
        altitudeAccuracy: 0.0,
      );
    }

    return {
      "uuid": deviceUuid,
      "device_name": deviceName,
      "os": os,
      "last_seen": DateTime.now().toIso8601String(),
      "geolocalisation": {
        "type": "Point",
        "coordinates": [position.longitude, position.latitude],
      },
    };
  }

  /// Envoie les infos du device au backend
  Future<Map<String, dynamic>> sendDeviceData() async {
    final deviceData = await getDeviceData();
    return await _api.post('/devices/add_db', deviceData);
  }

  // get nearby devices
  Future<List<dynamic>> getNearbyDevices() async {
    Position position;
    try {
      position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      return [];
    }

    final myUuid = await _getDeviceUuid();

    final data = {
      "longitude": position.longitude,
      "latitude": position.latitude,
      "uuid": myUuid,
    };

    final response = await _api.post('/devices/nearby', data);

    if (response["devices"] == null) {
      return [];
    }

    return response["devices"];
  }
}
