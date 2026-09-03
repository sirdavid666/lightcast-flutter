import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'signaling_server.dart';

class DirectorWebRTCTransport {
  RTCPeerConnection? _peerConnection;
  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();
  bool _isConnected = false;

  DirectorWebRTCTransport();

  Future<void> initialize() async {
    await remoteRenderer.initialize();
    
    _peerConnection = await createPeerConnection({
      'iceServers': [{'urls': 'stun:stun.l.google.com:19302'}],
    }, {'mandatory': {}, 'optional': []});

    // When the camera sends video, display it!
    _peerConnection!.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty) {
        remoteRenderer.srcObject = event.streams[0];
        _isConnected = true;
        debugPrint('[DirectorWebRTC] ✅ Remote camera track received!');
      }
    };

    _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
      if (candidate.candidate != null) {
        // We need to pass the signaling server instance, handled in main.dart
      }
    };
  }

  void handleOffer(Map<String, dynamic> data) async {
    debugPrint('[DirectorWebRTC] Received offer, creating answer...');
    await _peerConnection!.setRemoteDescription(
      RTCSessionDescription(data['sdp'], 'offer'),
    );

    final answer = await _peerConnection!.createAnswer();
    await _peerConnection!.setLocalDescription(answer);

    // Send the answer back to the camera
    signalingServer.sendAnswer({
      'type': 'answer',
      'sdp': answer.sdp,
    });
  }

  void handleCandidate(Map<String, dynamic> data) async {
    await _peerConnection!.addCandidate(
      RTCIceCandidate(
        data['candidate']['candidate'],
        data['candidate']['sdpMid'],
        data['candidate']['sdpMLineIndex'],
      ),
    );
  }

  RTCVideoRenderer get renderer => remoteRenderer;
  bool get isConnected => _isConnected;

  Future<void> dispose() async {
    await _peerConnection?.close();
    await remoteRenderer.dispose();
  }
}
