// ignore_for_file: prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../state/camera_providers.dart';
import '../services/lan_camera_transport.dart';

class CameraRoleScreen extends ConsumerWidget {
  const CameraRoleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(cameraProvider);
    final controller = ref.read(cameraProvider.notifier);
    if (state.role != null) return const CameraPreviewScreen();
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.waves, color: Color(0xFF60A5FA), size: 56),
                  const SizedBox(height: 18),
                  const Text(
                    'LIGHTCAST',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 4),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Choose this phone\'s camera role',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade400),
                  ),
                  const SizedBox(height: 36),
                  _RoleCard(
                    icon: Icons.person_outline,
                    title: 'Pastor Camera',
                    subtitle: 'Pastor, worship leader, or stage',
                    onTap: () => controller.selectRole(CameraRole.pastor),
                  ),
                  const SizedBox(height: 14),
                  _RoleCard(
                    icon: Icons.groups_outlined,
                    title: 'Crowd Camera',
                    subtitle: 'Congregation, choir, or audience',
                    onTap: () => controller.selectRole(CameraRole.crowd),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: const Color(0xFF1D4ED8),
                  child: Icon(icon, color: Colors.white),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(subtitle, style: TextStyle(color: Colors.grey.shade400)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
      );
}

class CameraPreviewScreen extends ConsumerStatefulWidget {
  const CameraPreviewScreen({super.key});

  @override
  ConsumerState<CameraPreviewScreen> createState() =>
      _CameraPreviewScreenState();
}

class _CameraPreviewScreenState extends ConsumerState<CameraPreviewScreen>
    with WidgetsBindingObserver {
  LanCameraTransport? _transport;
  late final TextEditingController _directorIpController;
  String? _cameraError;
  bool _isConnecting = false;
  String _stageLabel = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _directorIpController = TextEditingController();
  }

  Future<void> _connectToDirector() async {
    if (_isConnecting) return;
    setState(() {
      _isConnecting = true;
      _cameraError = null;
      _stageLabel = 'Starting...';
    });
    final role = ref.read(cameraProvider).role == CameraRole.pastor ? 'pastor' : 'crowd';
    final transport = LanCameraTransport(
      role: role,
      onStageChanged: (stage) {
        if (!mounted) return;
        setState(() => _stageLabel = stage);
      },
      onStateChanged: (status, error) {
        if (!mounted) return;
        setState(() {
          if (status == CameraTransportStatus.connected) {
            _isConnecting = false;
            _cameraError = null;
          } else if (status == CameraTransportStatus.failed) {
            _isConnecting = false;
            _cameraError = error ?? 'Connection failed';
            _transport = null;
          } else if (status == CameraTransportStatus.disconnected) {
            _isConnecting = false;
            _transport = null;
            _stageLabel = '';
          }
        });
        ref.read(cameraProvider.notifier).setConnected(
              status == CameraTransportStatus.connected,
            );
      },
    );
    try {
      final manualIp = _directorIpController.text.trim();
      await transport.start(manualIp.isEmpty ? null : manualIp);
      if (!mounted) {
        await transport.stop();
        return;
      }
      setState(() => _transport = transport);
    } catch (error) {
      if (mounted) {
        setState(() {
          _isConnecting = false;
          _cameraError = 'Connection failed: $error';
        });
      }
      ref.read(cameraProvider.notifier).setConnected(false);
    }
  }

  Future<void> _disconnectFromDirector() async {
    await _transport?.stop();
    if (mounted) setState(() {
      _transport = null;
      _isConnecting = false;
      _stageLabel = '';
    });
    ref.read(cameraProvider.notifier).setConnected(false);
  }

  Future<void> _scanQrCode() async {
    final scannedIp = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('Scan Director QR')),
          body: MobileScanner(
            onDetect: (capture) {
              final barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                final value = barcode.rawValue;
                if (value != null && value.contains(RegExp(r'^\d{1,3}(\.\d{1,3}){3}$'))) {
                  Navigator.of(context).pop(value);
                  return;
                }
              }
            },
          ),
        ),
      ),
    );

    if (scannedIp != null && scannedIp.isNotEmpty) {
      await _connectWithScannedIp(scannedIp);
    }
  }

  Future<void> _connectWithScannedIp(String ip) async {
    _directorIpController.text = ip;
    await _connectToDirector();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _transport?.stop();
    _directorIpController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      _transport?.stop();
      if (mounted) {
        setState(() {
          _transport = null;
          _isConnecting = false;
          _stageLabel = '';
        });
        ref.read(cameraProvider.notifier).setConnected(false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(cameraProvider);
    final controller = ref.read(cameraProvider.notifier);
    final roleName = state.role == CameraRole.pastor ? 'PASTOR CAMERA' : 'CROWD CAMERA';
    return Scaffold(
      appBar: AppBar(
        title: Text(roleName, style: const TextStyle(fontSize: 14, letterSpacing: 1.3)),
        actions: [
          IconButton(
            tooltip: 'Change role',
            onPressed: controller.clearRole,
            icon: const Icon(Icons.swap_horiz),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(14, 4, 14, 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    colors: state.role == CameraRole.pastor
                        ? const [Color(0xFF18304F), Color(0xFF0D1727)]
                        : const [Color(0xFF49301C), Color(0xFF17100B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Stack(
                  children: [
                    if (_transport?.localRenderer.srcObject != null)
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: RTCVideoView(
                            _transport!.localRenderer,
                            objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                          ),
                        ),
                      )
                    else
                      const Center(
                        child: CircularProgressIndicator(),
                      ),
                    if (_cameraError != null)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.error_outline, color: Colors.redAccent, size: 32),
                              const SizedBox(height: 10),
                              Text(
                                _cameraError!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ),
                    Positioned(
                      top: 16,
                      left: 16,
                      child: _Badge(
                        label: state.connected ? '● SENDING FEED' : '○ NOT CONNECTED',
                        color: state.connected ? const Color(0xFF4ADE80) : Colors.orange,
                      ),
                    ),
                    Positioned(
                      bottom: 18,
                      left: 18,
                      right: 18,
                      child: Text(
                        _transport?.localRenderer.srcObject != null
                            ? 'REAL CAMERA • WEBRTC'
                            : _isConnecting
                                ? (_stageLabel.isEmpty ? 'CONNECTING TO DIRECTOR...' : _stageLabel.toUpperCase())
                                : 'NOT CONNECTED',
                        style: TextStyle(
                          color: Colors.white.withOpacity(.75),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 22),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _Metric(icon: Icons.battery_5_bar, label: '${state.batteryPercent}% battery'),
                      _Metric(icon: Icons.wifi, label: '${state.signalPercent}% signal'),
                      _Metric(icon: Icons.lan_outlined, label: 'WebRTC LAN'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Director is found automatically on this Wi-Fi network.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                   const SizedBox(height: 10),
                   Row(
                     children: [
                       Expanded(
                         child: TextField(
                           controller: _directorIpController,
                           keyboardType: const TextInputType.numberWithOptions(decimal: true),
                           textInputAction: TextInputAction.done,
                           decoration: const InputDecoration(
                             labelText: 'Manual Director IP (optional)',
                             hintText: 'Use only if auto-discovery cannot find it',
                             prefixIcon: Icon(Icons.router_outlined),
                           ),
                         ),
                       ),
                       const SizedBox(width: 8),
                       IconButton.filledTonal(
                         tooltip: 'Scan Director QR code',
                         icon: const Icon(Icons.qr_code_scanner),
                         onPressed: _isConnecting ? null : _scanQrCode,
                       ),
                     ],
                   ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: state.connected
                          ? _disconnectFromDirector
                          : _connectToDirector,
                      icon: Icon(state.connected ? Icons.stop : Icons.link),
                      label: Text(
                         _isConnecting
                             ? (_stageLabel.isEmpty ? 'CONNECTING...' : _stageLabel.toUpperCase())
                             : state.connected
                                 ? 'STOP SENDING FEED'
                             : 'FIND & CONNECT TO DIRECTOR',
                       ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'The Director controls production. This phone only sends its camera feed.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)),
        child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800)),
      );
}

class _Metric extends StatelessWidget {
  const _Metric({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, size: 16, color: Colors.white54),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.white70)),
        ],
      );
}
