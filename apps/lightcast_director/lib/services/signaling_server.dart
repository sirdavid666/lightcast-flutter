import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class SignalingServer {
  io.HttpServer? _server;
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
        print('[SignalingServer] 📱 Camera connected!');

        webSocket.stream.listen((message) {
          try {
            final data = jsonDecode(message);
            print('[SignalingServer] Received: ${data['type']}');

            if (data['type'] == 'offer') {
              onOfferReceived(data);
            } else if (data['type'] == 'candidate') {
              onCandidateReceived(data);
            }
          } catch (e) {
            print('[SignalingServer] Error parsing message: $e');
          }
        }, onDone: () {
          print('[SignalingServer] Camera disconnected');
          _cameraChannel = null;
        });
      }),
    );

    _server = await io.serve(handler, '0.0.0.0', 8080);
    print('[SignalingServer] 🟢 Listening for cameras on port ${_server!.port}');
  }

  void sendAnswer(Map<String, dynamic> answer) {
    if (_cameraChannel != null) {
      _cameraChannel!.sink.add(jsonEncode(answer));
      print('[SignalingServer] Sent answer to camera');
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
    print('[SignalingServer] Stopped');
    }
}
