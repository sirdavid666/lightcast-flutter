import 'package:flutter_webrtc/flutter_webrtc.dart';

// Stub class to prevent build errors in Director Screen
class DirectorWebRTCTransport {
  Future<void> initialize(dynamic signalingServer) async {}
  Future<void> setupCamera(String role) async {}
  
  RTCVideoRenderer? getRenderer(String role) => null;
  bool isConnected(String role) => false;
  
  Future<void> dispose() async {}
}

// Global instance
final DirectorWebRTCTransport directorTransport = DirectorWebRTCTransport();
