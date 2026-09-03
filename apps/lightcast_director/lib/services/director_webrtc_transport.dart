import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'signaling_server.dart';

class DirectorWebRTCTransport {
  // Map to hold peer connections and renderers for each role
  final Map<String, RTCPeerConnection> _peerConnections = {};
  final Map<String, RTCVideoRenderer> _renderers = {};
  SignalingServer? _signalingServer;

  DirectorWebRTCTransport();

  Future<void> initialize(SignalingServer signalingServer) async {
    _signalingServer = signalingServer;
  }

  Future<void> setupCamera(String role) async {
    if (_renderers.containsKey(role)) return; // Already set up

    final renderer = RTCVideoRenderer();
    await renderer.initialize();
    _renderers[role] = renderer;

    final peerConnection = await createPeerConnection({
      'iceServers': [{'urls': 'stun:stun.l.google.com:19302'}],
    }, {'mandatory': {}, 'optional': []});

    peerConnection.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty) {
        renderer.srcObject = event.streams[0];
        debugPrint('[DirectorWebRTC] ✅ Received $role camera track!');
      }
    };

    peerConnection.onIceCandidate = (RTCIceCandidate candidate) {
      if (candidate.candidate != null && _signalingServer != null) {
        _signalingServer!.sendCandidate(role, {
          'type': 'candidate',
          'candidate': {
            'candidate': candidate.candidate,
            'sdpMid': candidate.sdpMid,
            'sdpMLineIndex': candidate.sdpMLineIndex,
          },
        });
      }
    };

    _peerConnections[role] = peerConnection;
  }

  void handleOffer(String role, Map<String, dynamic> data) async {
    debugPrint('[DirectorWebRTC] Received $role offer...');
    final peerConnection = _peerConnections[role];
    if (peerConnection == null) return;

    await peerConnection.setRemoteDescription(
      RTCSessionDescription(data['sdp'], 'offer'),
    );

    final answer = await peerConnection.createAnswer();
    await peerConnection.setLocalDescription(answer);

    if (_signalingServer != null) {
      _signalingServer!.sendAnswer(role, {
        'type': 'answer',
        'sdp': answer.sdp,
      });
    }
  }

  void handleCandidate(String role, Map<String, dynamic> data) async {
    final peerConnection = _peerConnections[role];
    if (peerConnection == null) return;

    await peerConnection.addCandidate(
      RTCIceCandidate(
        data['candidate']['candidate'],
        data['candidate']['sdpMid'],
        data['candidate']['sdpMLineIndex'],
      ),
    );
  }

  RTCVideoRenderer? getRenderer(String role) => _renderers[role];
  bool isConnected(String role) => _renderers[role]?.srcObject != null;

  Future<void> dispose() async {
    for (var pc in _peerConnections.values) {
      await pc.close();
    }
    for (var renderer in _renderers.values) {
      await renderer.dispose();
    }
  }
}
