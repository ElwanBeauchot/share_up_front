// Construit la config iceServers (STUN/TURN) attendue par flutter_webrtc à
// partir des variables d'env. STUN = découverte d'IP publique côté NAT,
// TURN = relais utilisé en fallback quand le P2P direct est impossible.

import 'package:flutter_dotenv/flutter_dotenv.dart';

Map<String, dynamic> buildIceConfig() {
  final servers = <Map<String, dynamic>>[];
  final stun = dotenv.env['STUN_URL'];
  final turn = dotenv.env['TURN_URL'];
  if (stun != null && stun.isNotEmpty) {
    servers.add({'urls': stun});
  }
  if (turn != null && turn.isNotEmpty) {
    servers.add({
      'urls': turn,
      'username': dotenv.env['TURN_USER'] ?? '',
      'credential': dotenv.env['TURN_PASS'] ?? '',
    });
  }
  return {'iceServers': servers};
}
