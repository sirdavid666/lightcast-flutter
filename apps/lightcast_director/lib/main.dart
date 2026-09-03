import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app/director_app.dart';
import 'services/signaling_server.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Start the local signaling server to listen for Camera phones
  final signalingServer = SignalingServer();
  await signalingServer.start();

  runApp(const DirectorApp());
}
