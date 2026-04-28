import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'dart:async';
import 'api_service.dart';
import 'device_service.dart';

class P2PService {
  static final P2PService _instance = P2PService._internal();
  factory P2PService() => _instance;
  P2PService._internal();

  RTCPeerConnection? _peerConnection;
  RTCDataChannel? _dataChannel;
  final ApiService _api = ApiService();
  late final DeviceService _deviceService = DeviceService(_api);
  Timer? _pollingTimer;
  String? _remoteDeviceUuid;
  String? _myUuid;
  Function(String)? onMessageReceived;

  // Tampon des ICE reçus avant que la description distante soit posée.
  // Sans ça, addCandidate échoue et certains candidats sont perdus.
  final List<Map<String, dynamic>> _icesEnAttente = [];
  bool _descriptionDistantePosee = false;

  static const Map<String, dynamic> _iceConfig = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {
        'urls': 'turn:openrelay.metered.ca:80',
        'username': 'openrelayproject',
        'credential': 'openrelayproject',
      },
      {
        'urls': 'turn:openrelay.metered.ca:443',
        'username': 'openrelayproject',
        'credential': 'openrelayproject',
      },
    ],
  };

  void startListening() {
    _deviceService.getDeviceUuid().then((uuid) {
      _myUuid = uuid;
      _startPolling();
    });
  }

  Future<void> connectToDevice(String deviceUuid) async {
    print('[P2P] connectToDevice → $deviceUuid');
    await disconnect();
    _remoteDeviceUuid = deviceUuid;
    _myUuid ??= await _deviceService.getDeviceUuid();

    _peerConnection = await createPeerConnection(_iceConfig);

    _peerConnection!.onIceCandidate = (c) => _sendIceCandidate(c);
    _peerConnection!.onConnectionState = (state) {
      print('[P2P] connection state: $state');
    };
    _peerConnection!.onDataChannel = (ch) {
      print('[P2P] onDataChannel (caller) reçu: ${ch.label}');
      _dataChannel = ch;
      _dataChannel!.onMessage = (msg) {
        print('[P2P] message reçu (caller): ${msg.text}');
        onMessageReceived?.call(msg.text ?? '');
      };
    };

    _dataChannel = await _peerConnection!.createDataChannel(
      'messages',
      RTCDataChannelInit(),
    );
    _dataChannel!.onDataChannelState = (state) {
      print('[P2P] data channel state (caller): $state');
    };
    _dataChannel!.onMessage = (msg) {
      print('[P2P] message reçu (caller): ${msg.text}');
      onMessageReceived?.call(msg.text ?? '');
    };

    final offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);
    print('[P2P] offer créée et envoyée au backend');

    await _api.post('/p2p/offer', {
      'from_uuid': _myUuid,
      'to_uuid': deviceUuid,
      'sdp': offer.sdp,
    });

    _startPolling();
  }

  Future<void> _sendIceCandidate(RTCIceCandidate candidate) async {
    if (_myUuid == null || _remoteDeviceUuid == null) return;
    if (candidate.candidate == null) return;
    await _api.post('/p2p/ice', {
      'from_uuid': _myUuid,
      'to_uuid': _remoteDeviceUuid,
      'candidate': candidate.candidate,
      'sdpMid': candidate.sdpMid,
      'sdpMLineIndex': candidate.sdpMLineIndex,
    });
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (_myUuid == null) return;
      try {
        final res = await _api.get('/p2p/messages/$_myUuid');
        final msgs = res['messages'] as List?;
        if (msgs == null) return;
        for (final msg in msgs) {
          try {
            await _handleSignalMessage(msg);
          } catch (e) {
            print('[P2P] erreur sur signal ${msg['type']}: $e');
          }
        }
      } catch (e) {
        print('[P2P] erreur de polling: $e');
      }
    });
  }

  Future<void> _handleSignalMessage(Map<String, dynamic> msg) async {
    final type = msg['type'] as String?;
    print('[P2P] signal reçu: type=$type from=${msg['from_uuid']}');
    if (type == null) return;

    if (type == 'offer') {
      if (_peerConnection != null) await disconnect();
      _myUuid ??= await _deviceService.getDeviceUuid();
      _remoteDeviceUuid = msg['from_uuid'] as String?;
      _peerConnection = await createPeerConnection(_iceConfig);
      _peerConnection!.onIceCandidate = (c) => _sendIceCandidate(c);
      _peerConnection!.onConnectionState = (state) {
        print('[P2P] connection state (receiver): $state');
      };
      _peerConnection!.onDataChannel = (ch) {
        print('[P2P] onDataChannel (receiver) reçu: ${ch.label}');
        _dataChannel = ch;
        _dataChannel!.onDataChannelState = (state) {
          print('[P2P] data channel state (receiver): $state');
        };
        _dataChannel!.onMessage = (msg) {
          print('[P2P] message reçu (receiver): ${msg.text}');
          onMessageReceived?.call(msg.text ?? '');
        };
      };
      await _peerConnection!.setRemoteDescription(
        RTCSessionDescription(msg['sdp'], 'offer'),
      );
      final answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);
      print('[P2P] answer créée, envoi au backend');
      await _api.post('/p2p/answer', {
        'from_uuid': _myUuid,
        'to_uuid': msg['from_uuid'],
        'sdp': answer.sdp,
      });
      _startPolling();
    } else if (type == 'answer') {
      print('[P2P] answer reçue, setRemoteDescription');
      await _peerConnection!.setRemoteDescription(
        RTCSessionDescription(msg['sdp'], 'answer'),
      );
    } else if (type == 'ice') {
      await _peerConnection!.addCandidate(
        RTCIceCandidate(msg['candidate'], msg['sdpMid'], msg['sdpMLineIndex']),
      );
    }
  }

  Future<void> sendMessage() async {
    for (int i = 0; i < 30; i++) {
      final state = _dataChannel?.state;
      if (state == RTCDataChannelState.RTCDataChannelOpen) {
        _dataChannel!.send(RTCDataChannelMessage('Hello P2P'));
        print('[P2P] sendMessage: "Hello P2P" envoyé');
        return;
      }
      print('[P2P] sendMessage: tentative ${i + 1}/30, state=$state');
      await Future.delayed(const Duration(milliseconds: 500));
    }
    print('[P2P] sendMessage: ABANDON, le canal ne s\'est jamais ouvert');
  }

  Future<void> disconnect() async {
    await _dataChannel?.close();
    await _peerConnection?.close();
    _dataChannel = null;
    _peerConnection = null;
    _remoteDeviceUuid = null;
  }
}
