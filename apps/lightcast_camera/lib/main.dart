import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:lightcast_shared/lightcast_shared.dart';

void main() {
  runApp(const CameraApp(role: CameraRole.pastor));
}

class CameraApp extends StatelessWidget {
  const CameraApp({required this.role, super.key});
  final CameraRole role;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LightCast ${role.name}',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: CameraScreen(role: role),
    );
  }
}

class CameraScreen extends StatefulWidget {
  const CameraScreen({required this.role, super.key});
  final CameraRole role;

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  RTCVideoRenderer? _localRenderer;
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  String _status = 'Disconnected';
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    // Use BACK camera for both pastor and crowd
    final Map<String, dynamic> mediaConstraints = {
      'video': {
        'facingMode': 'environment', // Always use back camera
        'width': {'ideal': 1280},
        'height': {'ideal': 720},
        'frameRate': {'ideal': 30}
      },
      'audio': {
        'echoCancellation': true,
        'noiseSuppression': true
      }
    };

    try {
      _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
      _localRenderer = RTCVideoRenderer();
      await _localRenderer!.initialize();
      _localRenderer!.srcObject = _localStream;
      setState(() {});
    } catch (e) {
      setState(() => _status = 'Error: $e');
    }
  }

  Future<void> _connectToDirector() async {
    setState(() => _status = 'Connecting...');

    try {
      final config = <String, dynamic>{
        'iceServers': [
          {'urls': ['stun:stun.l.google.com:19302']}
        ]
      };

      _peerConnection = await createPeerConnection(config);

      _localStream?.getTracks().forEach((track) {
        _peerConnection?.addTrack(track, _localStream!);
      });

      final offer = await _peerConnection!.createOffer();
      await _peerConnection!.setLocalDescription(offer);

      // Send offer to director (you'll need to implement signaling)
      setState(() {
        _isConnected = true;
        _status = 'Connected';
      });
    } catch (e) {
      setState(() => _status = 'Connection failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.role.name.toUpperCase()} CAM'),
        backgroundColor: Colors.red[700],
      ),
      body: Column(
        children: [
          Expanded(
            child: _localRenderer != null
                ? RTCVideoView(_localRenderer!, mirror: false)
                : const Center(child: Text('Initializing camera...')),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(_status, style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _isConnected ? null : _connectToDirector,
                  icon: const Icon(Icons.videocam),
                  label: Text(_isConnected ? 'Connected' : 'Connect to Director'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isConnected ? Colors.grey : Colors.red[700],
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _localRenderer?.dispose();
    _localStream?.dispose();
    _peerConnection?.dispose();
    super.dispose();
  }
}
