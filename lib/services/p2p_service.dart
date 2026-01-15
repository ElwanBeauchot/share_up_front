import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:convert';
import 'api_service.dart';
import 'device_service.dart';

class P2PService {
  RTCPeerConnection? _peerConnection;
  RTCDataChannel? _dataChannel;
  final ApiService _api = ApiService();
  final DeviceService _deviceService = DeviceService();
  Timer? _pollingTimer;
  String? _remoteDeviceUuid;
  String? _myUuid;
  Function(String)? onMessageReceived;

  void startListening() {
    _deviceService.getDeviceUuid().then((uuid) {
      _myUuid = uuid;
      _startPolling();
    });
  }

  Future<void> connectToDevice(String deviceUuid) async {
    await disconnect();
    _remoteDeviceUuid = deviceUuid;
    _myUuid ??= await _deviceService.getDeviceUuid();

    _peerConnection = await createPeerConnection({
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
      ],
    });

    _peerConnection!.onIceCandidate = (c) => _sendIceCandidate(c);

    _peerConnection!.onConnectionState = (state) {
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        print('[P2P] État: $state');
      }
    };

    _peerConnection!.onDataChannel = (ch) {
      _dataChannel = ch;
      _dataChannel!.onMessage = (msg) => onMessageReceived?.call(msg.text);
    };

    _dataChannel = await _peerConnection!.createDataChannel(
      'messages',
      RTCDataChannelInit(),
    );

    _dataChannel!.onMessage = (msg) => onMessageReceived?.call(msg.text);

    final offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);

    await _api.post('/p2p/offer', {
      'from': _myUuid,
      'to': deviceUuid,
      'sdp': offer.sdp,
      'type': offer.type,
    });

    _startPolling();
  }

  Future<void> _sendIceCandidate(RTCIceCandidate candidate) async {
    if (_myUuid == null || _remoteDeviceUuid == null) return;
    await _api.post('/p2p/ice', {
      'from': _myUuid,
      'to': _remoteDeviceUuid,
      'candidate': candidate.candidate,
      'sdpMid': candidate.sdpMid,
      'sdpMLineIndex': candidate.sdpMLineIndex,
    });
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(Duration(seconds: 2), (_) async {
      if (_myUuid == null) return;
      final res = await _api.get('/p2p/messages/$_myUuid');
      final msgs = res['messages'] as List?;
      if (msgs == null || msgs.isEmpty) return;
      for (var msg in msgs) {
        await _handleSignalMessage(msg);
      }
    });
  }

  Future<void> _handleSignalMessage(Map<String, dynamic> msg) async {
    final type = msg['type'] as String?;
    if (type == null || _peerConnection == null && type != 'offer') return;

    if (type == 'offer') {
      if (_peerConnection != null) await disconnect();
      _myUuid ??= await _deviceService.getDeviceUuid();
      _remoteDeviceUuid = msg['from'] as String?;
      _peerConnection = await createPeerConnection({
        'iceServers': [
          {'urls': 'stun:stun.l.google.com:19302'},
        ],
      });

      _peerConnection!.onIceCandidate = (c) => _sendIceCandidate(c);
      _peerConnection!.onConnectionState = (state) {
        if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected ||
            state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
            state ==
                RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
          print('[P2P] État: $state');
        }
      };
      _peerConnection!.onDataChannel = (ch) {
        _dataChannel = ch;
        _dataChannel!.onMessage = (msg) => onMessageReceived?.call(msg.text);
      };

      await _peerConnection!.setRemoteDescription(
        RTCSessionDescription(msg['sdp'], 'offer'),
      );

      final answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);

      await _api.post('/p2p/answer', {
        'from': _myUuid,
        'to': msg['from'],
        'sdp': answer.sdp,
        'type': answer.type,
      });
      _startPolling();
    } else if (type == 'answer') {
      await _peerConnection!.setRemoteDescription(
        RTCSessionDescription(msg['sdp'], 'answer'),
      );
    } else if (type == 'ice') {
      await _peerConnection!.addCandidate(
        RTCIceCandidate(msg['candidate'], msg['sdpMid'], msg['sdpMLineIndex']),
      );
    }
  }

  Future<void> sendFile() async {
    Uint8List imageBytes;
    try {
      final byteData = await rootBundle.load(
        'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png',
      );
      imageBytes = byteData.buffer.asUint8List();
    } catch (e) {
      return;
    }

    final base64Image = base64Encode(imageBytes);
    final content = 'data:image/png;base64,$base64Image';

    for (int i = 0; i < 30; i++) {
      if (_dataChannel?.state == RTCDataChannelState.RTCDataChannelOpen) {
        _dataChannel!.send(RTCDataChannelMessage(content));
        return;
      }
      await Future.delayed(const Duration(milliseconds: 500));
    }
  }

  Future<void> disconnect() async {
    await _dataChannel?.close();
    await _peerConnection?.close();
    _dataChannel = null;
    _peerConnection = null;
    _remoteDeviceUuid = null;
  }
}
