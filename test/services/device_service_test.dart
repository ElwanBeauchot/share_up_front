import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:share_up_front/models/device_model.dart';
import 'package:share_up_front/services/device_service.dart';
import 'package:share_up_front/services/api_service.dart';

class MockApiService extends Mock implements ApiService {}

void main() {
  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });
  late DeviceService deviceService;
  late MockApiService mockApiService;

  final position = {
    "longitude": 2.3522,
    "latitude": 48.8566,
  };
  const myUuid = "test-uuid-123";

  group('DeviceService - getNearbyDevices', () {
    setUp(() {
      mockApiService = MockApiService();
      deviceService = DeviceService(mockApiService);
    });

    test('case success with devices', () async {
      // ARRANGE
      final mockResponse = {
        'code': 200,
        'data': {
          'devices': [
            {
              "uuid": "a94331ef-fb23-4747-aec6-fd36e4638f30",
              "device_name": "HUAWEI MAR-LX1A",
              "os": "Android 10",
              "last_seen": "2026-04-28T15:24:59.217000",
              "_id": "69f0c2240268dd937a07b79f",
              "longitude": 2.0779263,
              "latitude": 49.0396213
            },
            {
              "uuid": "a94331ef-fb23-4747-aec6-fd36e4638f30",
              "device_name": "JSN l21",
              "os": "Android 10",
              "last_seen": "2026-04-28T15:24:59.217000",
              "_id": "69f0c2240268dd937a07b79f",
              "longitude": 2.0779263,
              "latitude": 49.0396213
            },
          ]
        }
      };

      when(() => mockApiService.post('/devices/nearby', any()))
          .thenAnswer((_) async => mockResponse);

      // ACT
      final result = await deviceService.getNearbyDevices(position, myUuid);

      // ASSERT
      expect(result, isA<List<DeviceScanModel>>());
      expect(result.length, 2);
    });

    test('case success and no devices', () async {
      // ARRANGE
      final mockResponse = {
        'code': 200,
        'data': {
          'devices': []
        }
      };

      when(() => mockApiService.post('/devices/nearby', any()))
          .thenAnswer((_) async => mockResponse);

      // ACT
      final result = await deviceService.getNearbyDevices(position, myUuid);

      // ASSERT
      expect(result, isEmpty);
    });

    test('case error - empty uuid', () async {
      expect(
            () async => await deviceService.getNearbyDevices(position, ""),
        throwsA(predicate((e) =>
        e is Exception && e.toString().contains("UUID du device est vide"))),
      );
    });

     test('case error - invalid position', () async {
       final invalidPosition = {"longitude": null, "latitude": null};

       expect(
             () async => await deviceService.getNearbyDevices(invalidPosition, myUuid),
         throwsA(predicate((e) =>
         e is Exception && e.toString().contains("Position du device invalide"))),
       );
     });

    test('case error', () async {
      // ARRANGE
      final mockResponse = {
        'code': 500,
        'message': 'Internal error'
      };

      when(() => mockApiService.post('/devices/nearby', any()))
          .thenAnswer((_) async => mockResponse);

      // ACT & ASSERT
      expect(
        () async => await deviceService.getNearbyDevices(position, myUuid),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('DeviceService - sendDeviceData', () {
    setUp(() {
      mockApiService = MockApiService();
      deviceService = DeviceService(mockApiService);
    });

    final deviceInfo = DeviceScanModel(name: "Test Device", os: "Android 10");

    test('case success', () async {
      // ARRANGE
      final mockResponse = {
        'code': 200,
        'data': {},
        'message': 'success'
      };

      when(() => mockApiService.post('/devices/add', any()))
          .thenAnswer((_) async => mockResponse);

      // ACT
      final result = await deviceService.sendDeviceData(position, myUuid, deviceInfo);

      // ASSERT
      expect(result['message'], 'success');
    });

    test('case error - empty uuid', () async {
      final deviceInfo = DeviceScanModel(name: "Test Device", os: "Android 10");

      expect(
            () async => await deviceService.sendDeviceData(
          position,
          "",
          deviceInfo,
        ),
        throwsA(predicate((e) =>
        e is Exception && e.toString().contains("UUID du device est vide"))),
      );
    });

     test('case error - incomplete device info', () async {
       final incompleteDeviceInfo = DeviceScanModel(name: "", os: "Android 10");

       expect(
             () async => await deviceService.sendDeviceData(
           position,
           myUuid,
           incompleteDeviceInfo,
         ),
         throwsA(predicate((e) =>
         e is Exception && e.toString().contains("Informations du device incomplètes"))),
       );
     });

     test('case error - invalid position', () async {
       final invalidPosition = {"longitude": null, "latitude": null};

       expect(
             () async => await deviceService.sendDeviceData(
           invalidPosition,
           myUuid,
           deviceInfo,
         ),
         throwsA(predicate((e) =>
         e is Exception && e.toString().contains("Position du device invalide"))),
       );
     });

    test('case error', () async {
      // ARRANGE
      final mockResponse = {
        'code': 500,
        'message': 'Internal error'
      };

      when(() => mockApiService.post('/devices/add', any()))
          .thenAnswer((_) async => mockResponse);

      // ACT + ASSERT
      expect(
            () async =>
        await deviceService.sendDeviceData(position, myUuid, deviceInfo),
        throwsA(isA<Exception>()),
      );
    });
  });
}