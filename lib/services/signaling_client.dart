import 'dart:async';
import 'api_service.dart';

/// Parle au backend pour la signalisation P2P. Ne connaît rien à WebRTC.
class SignalingClient {
  final ApiService api;
  final String myUuid;

  StreamSubscription<Map<String, dynamic>>? sseSub;
  final StreamController<Map<String, dynamic>> controller =
      StreamController<Map<String, dynamic>>.broadcast();

  SignalingClient({required this.api, required this.myUuid});

  Stream<Map<String, dynamic>> get signals => controller.stream;

  void start() {
    if (sseSub != null) return;
    log('ouverture SSE /p2p/events/$myUuid');
    sseSub = api.streamEvents('/p2p/events/$myUuid').listen(
      controller.add,
      onError: (e) {
        log('SSE erreur: $e');
        sseSub = null;
      },
      onDone: () {
        log('SSE fermé par le serveur');
        sseSub = null;
      },
    );
  }

  void stop() {
    if (sseSub != null) {
      log('arrêt SSE');
      sseSub!.cancel();
      sseSub = null;
    }
  }

  /// Envoie un signal au backend (type = offer / answer / ice).
  Future<void> send(String type, String toUuid, Map<String, dynamic> payload) async {
    final res = await api.post('/p2p/$type', {
      'from_uuid': myUuid,
      'to_uuid': toUuid,
      ...payload,
    });
    if (res['code'] != 200) {
      throw Exception('POST /p2p/$type → ${res['code']} (${res['message']})');
    }
  }

  void log(String msg) => print('[Sig] $msg');
}
