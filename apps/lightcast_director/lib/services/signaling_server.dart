import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'native_streaming_service.dart';
import 'streaming_service.dart';

typedef CameraStatusCallback = void Function(String role, bool connected);
typedef CameraIceDiagnosticsCallback = void Function(
  String role,
  String event,
);

class SignalingServer {
  HttpServer? _server;
  final Map<String, WebSocketChannel> _channels = {};
  final Map<String, List<Map<String, dynamic>>> _pendingLocalCandidates = {};
  final CameraStatusCallback? onCameraStatusChanged;
  final CameraIceDiagnosticsCallback? onIceDiagnostics;

  SignalingServer({
    this.onCameraStatusChanged,
    this.onIceDiagnostics,
  });

  Future<void> start() async {
    if (_server != null) return;

    NativeStreamingService.onLocalIceCandidate = _sendCandidateToCamera;
    // Install the native -> Dart handler before discovery can expose the
    // health endpoint and a camera can send its first offer.
    NativeStreamingService.init();

    final websocketHandler = webSocketHandler((webSocket, HttpRequest request) {
      final role = request.uri.pathSegments.isNotEmpty
          ? request.uri.pathSegments.first
          : 'unknown';
      _channels[role]?.sink.close();
      _channels[role] = webSocket;
      _flushPendingLocalCandidates(role, webSocket);
      onCameraStatusChanged?.call(role, true);
      debugPrint('[SignalingServer] camera connected: $role');

      webSocket.stream.listen((message) {
        unawaited(_handleMessage(role, webSocket, message));
      }, onError: (Object error) {
        debugPrint('[SignalingServer] WebSocket error for $role: $error');
      }, onDone: () {
        if (identical(_channels[role], webSocket)) {
          _channels.remove(role);
          _pendingLocalCandidates.remove(role);
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

  void _sendCandidateToCamera(String role, Map<String, dynamic> candidate) {
    final channel = _channels[role];
    if (channel == null) {
      _pendingLocalCandidates
          .putIfAbsent(role, () => <Map<String, dynamic>>[])
          .add(Map<String, dynamic>.from(candidate));
      debugPrint('[SignalingServer] queueing local candidate until camera connects: $role');
      return;
    }
    _sendCandidate(channel, role, candidate);
  }

  void _flushPendingLocalCandidates(
    String role,
    WebSocketChannel channel,
  ) {
    final pending = _pendingLocalCandidates.remove(role);
    if (pending == null) return;
    for (final candidate in pending) {
      _sendCandidate(channel, role, candidate);
    }
  }

  void _sendCandidate(
    WebSocketChannel channel,
    String role,
    Map<String, dynamic> candidate,
  ) {
    channel.sink.add(jsonEncode({
      'type': 'candidate',
      'candidate': {
        'candidate': candidate['sdp'],
        'sdpMid': candidate['mid'],
        'sdpMLineIndex': candidate['lineIndex'],
      },
    }));
    onIceDiagnostics?.call(role, 'candidateSentToCamera');
  }

  Future<void> _handleMessage(
    String role,
    WebSocketChannel webSocket,
    dynamic message,
  ) async {
    try {
      final data = jsonDecode(message as String) as Map<String, dynamic>;
      if (data['type'] == 'offer') {
        onIceDiagnostics?.call(role, 'offerReceived');
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
          onIceDiagnostics?.call(role, 'answerSent');
        }
      } else if (data['type'] == 'candidate') {
        final raw = data['candidate'];
        final candidate = raw is Map ? Map<String, dynamic>.from(raw) : data;
        if ((candidate['candidate'] as String? ?? '').isNotEmpty) {
          onIceDiagnostics?.call(role, 'candidateReceivedFromCamera');
        }
        await StreamingService.addIceCandidate(
          role: role,
          sdp: candidate['candidate'] as String? ?? '',
          mid: candidate['sdpMid'] as String?,
          lineIndex: (candidate['sdpMLineIndex'] as num?)?.toInt() ?? 0,
        );
      }
    } catch (error, stack) {
      debugPrint('[SignalingServer] message error for $role: $error\n$stack');
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
    _pendingLocalCandidates.clear();
    await _server?.close();
    _server = null;
  }
}
