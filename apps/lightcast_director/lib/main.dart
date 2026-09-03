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

  // 2. Start the local signaling server on port 8080
  signalingServer = SignalingServer(
    onOfferReceived: directorTransport.handleOffer,
    onCandidateReceived: directorTransport.handleCandidate,
  );
  await signalingServer.start();
  
  // 3. Initialize the transport with the signaling server
  await directorTransport.initialize(signalingServer);
  
  // 4. Setup both camera slots (Pastor and Crowd)
  await directorTransport.setupCamera('pastor');
  await directorTransport.setupCamera('crowd');

  runApp(const DirectorApp());
}
