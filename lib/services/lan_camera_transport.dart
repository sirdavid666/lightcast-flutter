import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

/// Handles WebRTC transport for camera phones to send video to Director.
class LanCameraTransport {
  final String role;
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  final RTCVideoRenderer localRenderer = RTCVideoRenderer();
  String? _directorIp;
  bool _isRunning = false;

  LanCameraTransport({required this.role});

  bool get isRunning => _isRunning;

  Future<void> start(String directorIp) async {
    if (_isRunning) {
      debugPrint('[LanCameraTransport] Already running');
      return;
    }

    _directorIp = directorIp;
    debugPrint('[LanCameraTransport] Starting for role: $role, Director: $_directorIp');

    await localRenderer.initialize();

    final Map<String, dynamic> mediaConstraints = {
      'audio': true,
      'video': {
        'facingMode': role == 'pastor' ? 'user' : 'environment',
        'width': {'ideal': 1280},
        'height': {'ideal': 720},
      },
    };

    _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
    localRenderer.srcObject = _localStream;

    _peerConnection = await createPeerConnection({
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
      ],
    }, {
      'mandatory': {},
      'optional': [],
    });

    _localStream!.getTracks().forEach((track) {
      _peerConnection!.addTrack(track, _localStream!);
    });

    final offer = await _peerConnection!.createOffer({
      'offerToReceiveVideo': 1,
      'offerToReceiveAudio': 1,
    });

    await _peerConnection!.setLocalDescription(offer);

    debugPrint('[LanCameraTransport] WebRTC offer created, waiting for signaling...');
    
    _isRunning = true;
    debugPrint('[LanCameraTransport] Started successfully');
  }

  Future<void> stop() async {
    debugPrint('[LanCameraTransport] Stopping...');
    
    _localStream?.getTracks().forEach((track) => track.stop());
    await _localStream?.dispose();
    await _peerConnection?.close();
    await localRenderer.dispose();
    
    _localStream = null;
    _peerConnection = null;
    _isRunning = false;
    
    debugPrint('[LanCameraTransport] Stopped');
  }
}
