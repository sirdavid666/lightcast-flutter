import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app/director_app.dart';
import 'services/signaling_server.dart';
import 'services/director_webrtc_transport.dart';

// Global instances so the app can access the WebRTC connection
late SignalingServer signalingServer;
late DirectorWebRTCTransport directorTransport;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // 1. Initialize the WebRTC receiver
  directorTransport = DirectorWebRTCTransport();
  await directorTransport.initialize();

  // 2. Start the local signaling server on port 8080
  signalingServer = SignalingServer(
    onOfferReceived: directorTransport.handleOffer,
    onCandidateReceived: directorTransport.handleCandidate,
  );
  await signalingServer.start();

  runApp(const DirectorApp());
}
