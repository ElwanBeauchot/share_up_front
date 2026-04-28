import 'package:device_info_plus/device_info_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/device_model.dart';
import 'api_service.dart';

class DeviceService {
  final ApiService _api;
  DeviceService(this._api);

  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  final Uuid _uuid = Uuid();

  static const String _uuidKey = "device_uuid";

  /// Récupère ou génère un UUID unique et persistant
  Future<String> getDeviceUuid() async {
    final prefs = await SharedPreferences.getInstance();
    String? uuid = prefs.getString(_uuidKey);
    if (uuid == null) {
      uuid = _uuid.v4();
      await prefs.setString(_uuidKey, uuid);
    }
    return uuid;
  }

  /// Récupère la position actuelle du device
  /// Gere si permissions refusees ou erreur liees a la localisation
  Future<Map<String, dynamic>> getDevicePosition() async {
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
      print("Erreur récupération position: $e");
      throw Exception("Impossible de récupérer la position du device");
    }
    return {"longitude": position.longitude, "latitude": position.latitude};
  }

  /// recuperer les infos du device (nom, os)
  Future<DeviceScanModel> getDeviceInfo() async {
    String deviceName = "Unknown";
    String os = "Unknown";

    try {
      final platform = await _deviceInfo.deviceInfo;
      if (platform is AndroidDeviceInfo) {
        final brand = platform.brand;
        final model = platform.model;
        deviceName = "$brand $model".trim();
        if (deviceName.isEmpty) deviceName = "Android Device"; // cas android
        os = "Android ${platform.version.release}";
      } else if (platform is IosDeviceInfo) { // cas ios
        deviceName = platform.name;
        os = "iOS ${platform.systemVersion}";
      }
      // pour plus tard : rajouter d'autres plateformes
    } catch (e) {
      print("Erreur récupération device info: $e");
    }

    return DeviceScanModel(
      name: deviceName,
      os: os
    );
  }

  /// Send device data to backend
  Future<Map<String, dynamic>> sendDeviceData(Map<String, dynamic> position, String deviceUuid, DeviceScanModel deviceInfo) async {

    if (deviceUuid.isEmpty) {
      throw Exception("UUID du device est vide");
    }

    if (deviceInfo.name.isEmpty || deviceInfo.os.isEmpty) {
      throw Exception("Informations du device incomplètes");
    }

    if (position["longitude"] == null || position["latitude"] == null) {
      throw Exception("Position du device invalide");
    }

    final deviceData = {
      "uuid": deviceUuid,
      "device_name": deviceInfo.name,
      "os": deviceInfo.os,
      "last_seen": DateTime.now().toIso8601String(),
      "geolocalisation": {
        "type": "Point",
        "coordinates": [position["longitude"], position["latitude"]],
      },
    };

    final response = await _api.post('/devices/add', deviceData);

    if (response['code'] != 200 || response['data'] == null) {
      throw Exception("Erreur enregistrement device: ${response['message']}");
    }
    return response;
  }

  /// get nearby devices
  Future<List<DeviceScanModel>> getNearbyDevices(Map<String, dynamic> position, String myUuid) async {

    if(position["longitude"] == null || position["latitude"] == null) {
      throw Exception("Position du device invalide");
    }
    if (myUuid.isEmpty) {
      throw Exception("UUID du device est vide");
    }

    final data = {
      "longitude": position["longitude"],
      "latitude": position["latitude"],
      "uuid": myUuid,
    };
    final response = await _api.post('/devices/nearby', data);

    if (response['code'] != 200 || response['data'] == null) {
      throw Exception("Erreur récupération devices proches: ${response['message']}");
    } else if((response['data']["devices"] as List).isEmpty) {
      return [];
    }
    List devicesJson = response['data']["devices"];
    List<DeviceScanModel> devices = devicesJson.map((e)=> DeviceScanModel.fromJson(e)).toList();
    return devices;
  }
}
