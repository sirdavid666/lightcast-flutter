import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

void main() {
  runApp(const CameraApp());
}

class CameraApp extends StatelessWidget {
  const CameraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LightCast Camera',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const CameraScreen(),
    );
  }
}

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

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
    // Use BACK camera
    final Map<String, dynamic> mediaConstraints = {
      'video': {
        'facingMode': 'environment',
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

      // TODO: Implement signaling to send offer to director
      setState(() {
        _isConnected = true;
        _status = 'Connected - Ready to stream';
      });
    } catch (e) {
      setState(() => _status = 'Connection failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LIGHTCAST CAMERA'),
        backgroundColor: Colors.red[700],
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              color: Colors.black,
              child: _localRenderer != null
                  ? RTCVideoView(_localRenderer!, mirror: false)
                  : const Center(child: CircularProgressIndicator()),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            color: Colors.black87,
            child: Column(
              children: [
                Text(
                  _status,
                  style: const TextStyle(fontSize: 16, color: Colors.white),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _isConnected ? null : _connectToDirector,
                    icon: const Icon(Icons.videocam, size: 24),
                    label: Text(
                      _isConnected ? 'CONNECTED' : 'CONNECT TO DIRECTOR',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isConnected ? Colors.grey : Colors.red[700],
                      disabledBackgroundColor: Colors.grey,
                    ),
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
