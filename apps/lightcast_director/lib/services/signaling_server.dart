import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart'; // Added this import
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class SignalingServer {
  HttpServer? _server;
  WebSocketChannel? _cameraChannel;
  
  final Function(Map<String, dynamic>) onOfferReceived;
  final Function(Map<String, dynamic>) onCandidateReceived;

  SignalingServer({
    required this.onOfferReceived,
    required this.onCandidateReceived,
  });

  Future<void> start() async {
    final handler = const Pipeline().addHandler(
      webSocketHandler((webSocket) {
        _cameraChannel = webSocket;
        debugPrint('[SignalingServer] 📱 Camera connected!');

        webSocket.stream.listen((message) {
          try {
            final data = jsonDecode(message);
            debugPrint('[SignalingServer] Received: ${data['type']}');

            if (data['type'] == 'offer') {
              onOfferReceived(data);
            } else if (data['type'] == 'candidate') {
              onCandidateReceived(data);
            }
          } catch (e) {
            debugPrint('[SignalingServer] Error parsing message: $e');
          }
        }, onDone: () {
          debugPrint('[SignalingServer] Camera disconnected');
          _cameraChannel = null;
        });
      }),
    );

    _server = await io.serve(handler, '0.0.0.0', 8080);
    debugPrint('[SignalingServer] 🟢 Listening for cameras on port ${_server!.port}');
  }

  void sendAnswer(Map<String, dynamic> answer) {
    if (_cameraChannel != null) {
      _cameraChannel!.sink.add(jsonEncode(answer));
      debugPrint('[SignalingServer] Sent answer to camera');
    }
  }

  void sendCandidate(Map<String, dynamic> candidate) {
    if (_cameraChannel != null) {
      _cameraChannel!.sink.add(jsonEncode(candidate));
    }
  }

  Future<void> stop() async {
    await _cameraChannel?.sink.close();
    await _server?.close();
    debugPrint('[SignalingServer] Stopped');
  }
}
