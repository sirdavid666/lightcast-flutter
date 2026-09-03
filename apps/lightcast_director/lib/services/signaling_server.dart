import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class SignalingServer {
  HttpServer? _server;
  final Map<String, WebSocketChannel> _channels = {};
  
  final Function(String role, Map<String, dynamic>) onOfferReceived;
  final Function(String role, Map<String, dynamic>) onCandidateReceived;

  SignalingServer({required this.onOfferReceived, required this.onCandidateReceived});

  Future<void> start() async {
    final handler = const Pipeline().addHandler(
      webSocketHandler((webSocket, HttpRequest request) {
        final role = request.uri.pathSegments.isNotEmpty ? request.uri.pathSegments.first : 'unknown';
        _channels[role] = webSocket;
        debugPrint('[SignalingServer] 📱 $role camera connected!');

        webSocket.stream.listen((message) {
          try {
            final data = jsonDecode(message);
            debugPrint('[SignalingServer] Received from $role: ${data['type']}');
            if (data['type'] == 'offer') onOfferReceived(role, data);
            else if (data['type'] == 'candidate') onCandidateReceived(role, data);
          } catch (e) {
            debugPrint('[SignalingServer] Error parsing message: $e');
          }
        }, onDone: () {
          debugPrint('[SignalingServer] $role camera disconnected');
          _channels.remove(role);
        });
      }),
    );

    _server = await io.serve(handler, '0.0.0.0', 8080);
    debugPrint('[SignalingServer]  Listening for cameras on port ${_server!.port}');
  }

  void sendAnswer(String role, Map<String, dynamic> answer) {
    if (_channels[role] != null) {
      _channels[role]!.sink.add(jsonEncode(answer));
    }
  }

  void sendCandidate(String role, Map<String, dynamic> candidate) {
    if (_channels[role] != null) {
      _channels[role]!.sink.add(jsonEncode(candidate));
    }
  }

  Future<void> stop() async {
    for (var channel in _channels.values) { await channel.sink.close(); }
    await _server?.close();
  }
}
