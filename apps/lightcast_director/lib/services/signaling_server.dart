import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'streaming_service.dart';

typedef CameraStatusCallback = void Function(String role, bool connected);

class SignalingServer {
  HttpServer? _server;
  final Map<String, WebSocketChannel> _channels = {};
  final CameraStatusCallback? onCameraStatusChanged;

  SignalingServer({this.onCameraStatusChanged});

  Future<void> start() async {
    if (_server != null) return;
    final websocketHandler = webSocketHandler((webSocket, HttpRequest request) {
      final role = request.uri.pathSegments.isNotEmpty
          ? request.uri.pathSegments.first
          : 'unknown';
      _channels[role]?.sink.close();
      _channels[role] = webSocket;
      onCameraStatusChanged?.call(role, true);
      debugPrint('[SignalingServer] camera connected: $role');

      webSocket.stream.listen((message) {
        unawaited(_handleMessage(role, webSocket, message));
      }, onError: (Object error) {
        debugPrint('[SignalingServer] WebSocket error for $role: $error');
      }, onDone: () {
        if (identical(_channels[role], webSocket)) {
          _channels.remove(role);
          onCameraStatusChanged?.call(role, false);
        }
        debugPrint('[SignalingServer] camera disconnected: $role');
      });
    });
    final handler = const Pipeline().addHandler((request) {
      if (request.method == 'GET' &&
          request.url.pathSegments.length == 2 &&
          request.url.pathSegments[0] == 'lightcast' &&
          request.url.pathSegments[1] == 'health') {
        return Response.ok(
          jsonEncode({
            'service': 'lightcast-director',
            'protocolVersion': 1,
          }),
          headers: const {'content-type': 'application/json'},
        );
      }
      return websocketHandler(request);
    });
    _server = await io.serve(handler, '0.0.0.0', 8080);
    debugPrint('[SignalingServer] Listening for cameras on port ' + _server!.port.toString());
  }

  Future<void> _handleMessage(
    String role,
    WebSocketChannel webSocket,
    dynamic message,
  ) async {
    try {
      final data = jsonDecode(message as String) as Map<String, dynamic>;
      if (data['type'] == 'offer') {
        debugPrint('[SignalingServer] offer received from $role');
        final answerSdp = await StreamingService.handleOffer(
          data['sdp'] as String? ?? '',
          role: role,
        ).timeout(const Duration(seconds: 15));
        if (answerSdp == null || answerSdp.isEmpty) {
          webSocket.sink.add(jsonEncode({
            'type': 'error',
            'message': 'Director failed to create a WebRTC answer',
          }));
        } else if (identical(_channels[role], webSocket)) {
          webSocket.sink.add(jsonEncode({'type': 'answer', 'sdp': answerSdp}));
        }
      } else if (data['type'] == 'candidate') {
        final raw = data['candidate'];
        final candidate = raw is Map ? Map<String, dynamic>.from(raw) : data;
        await StreamingService.addIceCandidate(
          role: role,
          sdp: candidate['candidate'] as String? ?? '',
          mid: candidate['sdpMid'] as String?,
          lineIndex: (candidate['sdpMLineIndex'] as num?)?.toInt() ?? 0,
        );
      }
    } catch (error, stack) {
      debugPrint('[SignalingServer] message error for $role: $error\\n$stack');
      webSocket.sink.add(jsonEncode({
        'type': 'error',
        'message': 'Director could not process signaling data',
      }));
    }
  }

  Future<void> stop() async {
    for (final channel in _channels.values) {
      await channel.sink.close();
    }
    _channels.clear();
    await _server?.close();
    _server = null;
  }
}