import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'streaming_service.dart';

class SignalingServer {
  HttpServer? _server;
  final Map<String, WebSocketChannel> _channels = {};
  
  SignalingServer();

  Future<void> start() async {
    final handler = const Pipeline().addHandler(
      webSocketHandler((webSocket, HttpRequest request) {
        final role = request.uri.pathSegments.isNotEmpty ? request.uri.pathSegments.first : 'unknown';
        _channels[role] = webSocket;
        debugPrint('[SignalingServer] 📱 $role camera connected!');

        webSocket.stream.listen((message) async {
          try {
            final data = jsonDecode(message);
            if (data['type'] == 'offer') {
              debugPrint('[SignalingServer] Received offer from $role, processing natively...');
              // Pass the SDP to Kotlin to create the PeerConnection and extract the VideoTrack
              final answerSdp = await StreamingService.handleOffer(data['sdp']);
              if (answerSdp != null) {
                _channels[role]?.sink.add(jsonEncode({'type': 'answer', 'sdp': answerSdp}));
              }
            } else if (data['type'] == 'candidate') {
              // ICE candidates are handled automatically by the native PeerConnection in this simplified flow
              // For production, you would pass these to Kotlin as well.
            }
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

  Future<void> stop() async {
    for (var channel in _channels.values) {
      await channel.sink.close();
    }
    await _server?.close();
  }
}
