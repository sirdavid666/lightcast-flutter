import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'director_discovery.dart';

enum CameraTransportStatus { connecting, connected, disconnected, failed }

typedef CameraTransportStatusCallback = void Function(
  CameraTransportStatus status,
  String? error,
);

typedef CameraTransportStageCallback = void Function(String stage);

class LanCameraTransport {
  final String role;
  final CameraTransportStatusCallback? onStateChanged;
  final CameraTransportStageCallback? onStageChanged;
  final DirectorDiscovery discovery;
  final int maxAutoRetries;

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  final RTCVideoRenderer localRenderer = RTCVideoRenderer();
  String? _directorIp;
  bool _isRunning = false;
  bool _channelReady = false;
  bool _hasConnected = false;
  bool _stopping = false;
  WebSocketChannel? _channel;
  Timer? _connectionTimer;
  final List<Map<String, dynamic>> _pendingCandidates = [];

  int _retryAttempt = 0;
  String? _lastDirectorIpArg;
  String? _lastStageFailed;

  LanCameraTransport({
    required this.role,
    this.onStateChanged,
    this.onStageChanged,
    DirectorDiscovery? discovery,
    this.maxAutoRetries = 2,
  }) : discovery = discovery ?? DirectorDiscovery();

  bool get isRunning => _isRunning;

  void _notify(CameraTransportStatus status, [String? error]) =>
      onStateChanged?.call(status, error);

  void _stage(String label) {
    debugPrint('[LanCameraTransport] stage: $label');
    onStageChanged?.call(label);
  }

  Future<void> start([String? directorIp]) async {
    if (_isRunning) return;
    _lastDirectorIpArg = directorIp;
    _retryAttempt = 0;
    await _attemptConnect(directorIp);
  }

  Future<void> _attemptConnect(String? directorIp) async {
    _stopping = false;
    _hasConnected = false;
    _notify(CameraTransportStatus.connecting);

    try {
      final configuredHost = directorIp?.trim();
      if (configuredHost == null || configuredHost.isEmpty) {
        _stage('Finding Director...');
      }
      _directorIp = configuredHost == null || configuredHost.isEmpty
          ? await discovery.discover()
          : configuredHost;
      if (_directorIp == null) {
        _lastStageFailed = 'Finding Director';
        throw SocketException(
          'No LightCast Director found on the local network',
        );
      }
      if (configuredHost != null && configuredHost.isNotEmpty) {
        await discovery.rememberHost(configuredHost);
      }
      debugPrint(
        '[LanCameraTransport] Starting for role: $role, Director: $_directorIp',
      );
      await localRenderer.initialize();
      final mediaConstraints = <String, dynamic>{
        'audio': true,
        'video': {
          'facingMode': 'environment',
          'width': {'ideal': 1280},
          'height': {'ideal': 720},
        },
      };
      _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
      localRenderer.srcObject = _localStream;
      _peerConnection = await createPeerConnection({
        'iceServers': [{'urls': 'stun:stun.l.google.com:19302'}],
      }, {'mandatory': {}, 'optional': []});
      for (final track in _localStream!.getTracks()) {
        await _peerConnection!.addTrack(track, _localStream!);
      }

      _peerConnection!.onIceConnectionState = (state) {
        final value = state.toString().toLowerCase();
        if (value.contains('connected') || value.contains('completed')) {
          _hasConnected = true;
          _connectionTimer?.cancel();
          _stage('Connected');
          _notify(CameraTransportStatus.connected);
        } else if (value.contains('checking')) {
          _stage('ICE connecting...');
        } else if (value.contains('failed') || value.contains('closed')) {
          _lastStageFailed = 'ICE connecting';
          unawaited(_fail('WebRTC ICE state: $state'));
        }
      };
      _peerConnection!.onIceCandidate = (candidate) {
        if (candidate.candidate != null) {
          _sendSignalingMessage({
            'type': 'candidate',
            'candidate': candidate.toMap(),
          });
        }
      };

      final offer = await _peerConnection!.createOffer({
        'offerToReceiveVideo': 1,
        'offerToReceiveAudio': 1,
      });
      await _peerConnection!.setLocalDescription(offer);

      _stage('Connecting to Director...');
      _channel = WebSocketChannel.connect(
        Uri.parse('ws://$_directorIp:8080/$role'),
      );
      try {
        await _channel!.ready.timeout(const Duration(seconds: 8));
      } catch (_) {
        _lastStageFailed = 'Signaling connection';
        rethrow;
      }
      _channelReady = true;
      _stage('Signaling connected');
      _channel!.stream.listen((message) async {
        try {
          final data = jsonDecode(message as String) as Map<String, dynamic>;
          if (data['type'] == 'answer') {
            await _peerConnection?.setRemoteDescription(
              RTCSessionDescription(data['sdp'] as String, 'answer'),
            );
            _stage('ICE connecting...');
            debugPrint('[LanCameraTransport] Answer received. Waiting for ICE connection.');
          } else if (data['type'] == 'candidate') {
            final candidate = Map<String, dynamic>.from(data['candidate'] as Map);
            await _peerConnection?.addCandidate(RTCIceCandidate(
              candidate['candidate'] as String?,
              candidate['sdpMid'] as String?,
              (candidate['sdpMLineIndex'] as num?)?.toInt(),
            ));
          } else if (data['type'] == 'error') {
            _lastStageFailed = 'Waiting for Director answer';
            await _fail(data['message'] as String? ?? 'Director rejected the offer');
          }
        } catch (error) {
          await _fail('Invalid signaling response: $error');
        }
      }, onError: (Object error) {
        unawaited(_fail('WebSocket error: $error'));
      }, onDone: () {
        if (!_stopping && !_hasConnected) {
          unawaited(_fail('Director closed the signaling connection'));
        }
      });

      _flushPendingCandidates();
      _sendSignalingMessage({'type': 'offer', 'sdp': offer.sdp});
      _stage('Waiting for Director answer...');
      _isRunning = true;
      _connectionTimer = Timer(const Duration(seconds: 20), () {
        if (!_hasConnected) {
          _lastStageFailed ??= 'Waiting for Director answer';
          unawaited(_fail('Timed out waiting for WebRTC connection'));
        }
      });
      debugPrint('[LanCameraTransport] Offer sent, waiting for Director answer and ICE.');
    } catch (error) {
      await _closeResources();
      final shouldRetry = !_stopping && _retryAttempt < maxAutoRetries;
      if (shouldRetry) {
        _retryAttempt++;
        _stage('Retrying (${_retryAttempt}/$maxAutoRetries)...');
        await Future<void>.delayed(const Duration(seconds: 2));
        await _attemptConnect(_lastDirectorIpArg);
        return;
      }
      _isRunning = false;
      final stageInfo = _lastStageFailed != null ? ' (failed at: $_lastStageFailed)' : '';
      _notify(CameraTransportStatus.failed, '${error.toString()}$stageInfo');
    }
  }

  void _flushPendingCandidates() {
    for (final candidate in List<Map<String, dynamic>>.from(_pendingCandidates)) {
      _channel?.sink.add(jsonEncode(candidate));
    }
    _pendingCandidates.clear();
  }

  void _sendSignalingMessage(Map<String, dynamic> message) {
    if (_channel == null || !_channelReady) {
      if (message['type'] == 'candidate') _pendingCandidates.add(message);
      return;
    }
    _channel!.sink.add(jsonEncode(message));
  }

  Future<void> _fail(String error) async {
    if (_stopping) return;
    _stopping = true;
    await _closeResources();
    _isRunning = false;

    final shouldRetry = _retryAttempt < maxAutoRetries;
    if (shouldRetry) {
      _retryAttempt++;
      _stage('Retrying (${_retryAttempt}/$maxAutoRetries)...');
      await Future<void>.delayed(const Duration(seconds: 2));
      await _attemptConnect(_lastDirectorIpArg);
      return;
    }
    final stageInfo = _lastStageFailed != null ? ' (failed at: $_lastStageFailed)' : '';
    _notify(CameraTransportStatus.failed, '$error$stageInfo');
  }

  Future<void> _closeResources() async {
    _connectionTimer?.cancel();
    _connectionTimer = null;
    await _channel?.sink.close();
    for (final track in _localStream?.getTracks() ?? <MediaStreamTrack>[]) {
      track.stop();
    }
    await _localStream?.dispose();
    await _peerConnection?.close();
    await localRenderer.dispose();
    _channel = null;
    _channelReady = false;
    _localStream = null;
    _peerConnection = null;
    _pendingCandidates.clear();
  }

  Future<void> stop() async {
    if (_stopping && !_isRunning) return;
    _stopping = true;
    await _closeResources();
    _isRunning = false;
    _hasConnected = false;
    _stopping = false;
    _notify(CameraTransportStatus.disconnected);
  }
}
