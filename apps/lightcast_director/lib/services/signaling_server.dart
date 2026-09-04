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
        final role = request.uri.pathSegments.isNotEmpty
            ? request.uri.pathSegments.first
            : 'unknown';
        _channels[role] = webSocket;
        debugPrint('[SignalingServer] 📱 $role camera connected!');

        webSocket.stream.listen((message) async {
          try {
            final data = jsonDecode(message);
            if (data['type'] == 'offer') {
              debugPrint(
                '[SignalingServer] Received offer from $role, processing natively...',
              );
              final answerSdp = await StreamingService.handleOffer(
                data['sdp'] as String? ?? '',
                role: role,
              );
              if (answerSdp != null) {
                _channels[role]?.sink.add(
                  jsonEncode({'type': 'answer', 'sdp': answerSdp}),
                );
              }
            } else if (data['type'] == 'candidate') {
              await StreamingService.addIceCandidate(
                role: role,
                sdp: data['candidate'] as String? ?? '',
                mid: data['sdpMid'] as String?,
                lineIndex: (data['sdpMLineIndex'] as num?)?.toInt() ?? 0,
              );
            }
          } catch (error) {
            debugPrint('[SignalingServer] Error parsing message: $error');
          }
        }, onDone: () {
          debugPrint('[SignalingServer] $role camera disconnected');
          _channels.remove(role);
        });
      }),
    );

    _server = await io.serve(handler, '0.0.0.0', 8080);
    debugPrint(
      '[SignalingServer] Listening for cameras on port ${_server!.port}',
    );
  }

  Future<void> stop() async {
    for (final channel in _channels.values) {
      await channel.sink.close();
    }
    _channels.clear();
    await _server?.close();
  }
}