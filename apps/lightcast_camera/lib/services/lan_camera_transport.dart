import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Handles WebRTC transport for camera phones to send video to Director.
class LanCameraTransport {
  final String role;
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  final RTCVideoRenderer localRenderer = RTCVideoRenderer();
  String? _directorIp;
  bool _isRunning = false;
  WebSocketChannel? _channel;

  LanCameraTransport({required this.role});

  bool get isRunning => _isRunning;

  Future<void> start(String directorIp) async {
    if (_isRunning) return;
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
      'iceServers': [{'urls': 'stun:stun.l.google.com:19302'}],
    }, {'mandatory': {}, 'optional': []});

    _localStream!.getTracks().forEach((track) {
      _peerConnection!.addTrack(track, _localStream!);
    });

    // Handle ICE candidates (network path discovery)
    _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
      if (candidate.candidate != null) {
        _sendSignalingMessage({
          'type': 'candidate',
          'candidate': candidate.toMap(),
        });
      }
    };

    // Create the video/audio offer
    final offer = await _peerConnection!.createOffer({
      'offerToReceiveVideo': 1,
      'offerToReceiveAudio': 1,
    });
    await _peerConnection!.setLocalDescription(offer);

    // Connect to the Director's signaling server with the specific role path
    _channel = WebSocketChannel.connect(Uri.parse('ws://$_directorIp:8080/$role'));
    
    // Listen for the Director's answer
    _channel!.stream.listen((message) async {
      final data = jsonDecode(message);
      if (data['type'] == 'answer') {
        await _peerConnection!.setRemoteDescription(
          RTCSessionDescription(data['sdp'], 'answer'),
        );
        debugPrint('[LanCameraTransport] ✅ Connected! Remote description set.');
      } else if (data['type'] == 'candidate') {
        await _peerConnection!.addCandidate(
          RTCIceCandidate(
            data['candidate']['candidate'],
            data['candidate']['sdpMid'],
            data['candidate']['sdpMLineIndex'],
          ),
        );
      }
    });

    // Send the offer to the Director
    _sendSignalingMessage({
      'type': 'offer',
      'sdp': offer.sdp,
    });

    _isRunning = true;
    debugPrint('[LanCameraTransport] 📡 Offer sent, waiting for Director to answer...');
  }

  void _sendSignalingMessage(Map<String, dynamic> message) {
    if (_channel != null) {
      _channel!.sink.add(jsonEncode(message));
    }
  }

  Future<void> stop() async {
    debugPrint('[LanCameraTransport] Stopping...');
    await _channel?.sink.close();
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
