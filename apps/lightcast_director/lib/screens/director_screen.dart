import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lightcast_shared/lightcast_shared.dart';
import '../app/theme.dart';
import '../state/director_providers.dart';
import '../services/signaling_server.dart';
import '../widgets/control_panels.dart';

final signalingServerProvider = Provider<SignalingServer>((ref) {
  final server = SignalingServer(
    onCameraStatusChanged: (role, connected) {
      ref.read(productionProvider.notifier).setCameraStatus(role, connected);
    },
  );
   unawaited(server.start().catchError((error, _) {
    debugPrint('[SignalingServer] failed to start: $error');
  }));
  ref.onDispose(() {
    unawaited(server.stop());
  });
  return server;
});

class DirectorScreen extends ConsumerWidget {
  const DirectorScreen({super.key});

  static const panelNames = [
    'Cameras',
    'Lyrics',
    'Scripture',
    'Ticker',
    'Logo',
    'Lower Third',
    'Countdown',
    'PIP',
    'Streaming',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(productionProvider);
    final controller = ref.read(productionProvider.notifier);
    ref.watch(signalingServerProvider);

    return ProviderScope(
      overrides: [
        webrtcTransportProvider.overrideWithValue(null),
      ],
      child: _DirectorScreenContent(state: state, controller: controller),
    );
  }
}

class _DirectorScreenContent extends StatelessWidget {
  const _DirectorScreenContent({required this.state, required this.controller});

  final ProductionState state;
  final ProductionController controller;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: DirectorScreen.panelNames.length,
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 44,
          titleSpacing: 10,
          title: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.waves, color: lightcastBlue, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'LIGHTCAST',
                  style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.4),
                ),
                const SizedBox(width: 8),
                Text(
                  'DIRECTOR',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                ),
              ],
            ),
          ),
          actions: [
            _StatusPill(label: state.liveStatus, live: state.liveStatus == 'LIVE'),
            const SizedBox(width: 8),
            const Icon(Icons.wifi, color: Color(0xFF22C55E), size: 17),
            const SizedBox(width: 10),
          ],
        ),
        body: Column(
          children: [
            const _TopIpBar(),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(10, 8, 5, 8),
                      child: Column(
                        children: [
                          Expanded(
                            child: Center(
                              child: AspectRatio(
                                aspectRatio: 16 / 9,
                                child: _LargeBroadcastScreen(
                                  title: 'PROGRAM',
                                  scene: state.programScene,
                                  lyricsText: state.lyrics.text,
                                  scriptureText: state.scripture.text,
                                  scriptureReference: state.scripture.reference,
                                  tickerText: state.ticker.text,
                                  tickerSpeed: state.ticker.speed,
                                  isProgram: true,
                                ),
                              ),
                            ),
                          ),
                          _StatsBar(),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(5, 8, 10, 8),
                      child: _Controls(
                        onTab: (index) =>
                            controller.setPanel(DirectorScreen.panelNames[index]),
                      ),
                    ),
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

class _TopIpBar extends StatefulWidget {
  const _TopIpBar();
  @override
  State<_TopIpBar> createState() => _TopIpBarState();
}

class _TopIpBarState extends State<_TopIpBar> {
  String _ip = 'finding...';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
        includeLinkLocal: false,
      );
      final addresses = interfaces
          .expand((i) => i.addresses)
          .where((a) => !a.isLoopback)
          .map((a) => a.address)
          .toList();
      final ip = addresses.firstWhere(
        _isPrivate,
        orElse: () => addresses.isEmpty ? 'Not on Wi-Fi' : addresses.first,
      );
      if (mounted) setState(() => _ip = ip);
    } catch (_) {
      if (mounted) setState(() => _ip = 'Unavailable');
    }
  }

  bool _isPrivate(String v) {
    final p = v.split('.').map(int.tryParse).toList();
    if (p.length != 4 || p.any((e) => e == null)) return false;
    return p[0] == 10 || (p[0] == 192 && p[1] == 168) || (p[0] == 172 && p[1]! >= 16 && p[1]! <= 31);
  }

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.fromLTRB(10, 6, 10, 0),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF0D3B66),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF2D7FC1)),
        ),
        child: Row(
          children: [
            const Icon(Icons.router, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Director: $_ip  —  cameras auto-discover on Wi-Fi',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(
              onPressed: _load,
              icon: const Icon(Icons.refresh, color: Colors.white70, size: 16),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
            ),
            IconButton(
              icon: const Icon(Icons.qr_code, color: Colors.white70, size: 18),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: Colors.white,
                    title: const Text('Scan to Connect Camera', textAlign: TextAlign.center),
                    content: SizedBox(
                      width: 250,
                      height: 250,
                      child: Center(
                        child: QrImageView(
                          data: _ip,
                          version: QrVersions.auto,
                          size: 250.0,
                          backgroundColor: Colors.white,
                        ),
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      );
}

class _StatsBar extends StatelessWidget {
  const _StatsBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 3),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF151922),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        children: [
          Expanded(child: _StatItem(icon: Icons.speed, label: 'FPS 30')),
          Expanded(child: _StatItem(icon: Icons.swap_vert, label: 'BITRATE 2.4 Mbps')),
          Expanded(child: _StatItem(icon: Icons.mic, label: 'AUDIO -18 dB')),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 13, color: Colors.white38),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white60, fontSize: 10, letterSpacing: .3),
          ),
        ),
      ],
    );
  }
}

class NativeCameraView extends StatelessWidget {
  const NativeCameraView({required this.role, super.key});

  final String role;

  @override
  Widget build(BuildContext context) => AndroidView(
        viewType: 'lightcast_camera_view',
        creationParams: {'role': role},
        creationParamsCodec: const StandardMessageCodec(),
      );
}

class _LiveCameraLayer extends StatelessWidget {
  const _LiveCameraLayer({required this.role, required this.frame});

  final String role;
  final NormalizedRect frame;

  @override
  Widget build(BuildContext context) => Positioned(
        left: frame.x,
        top: frame.y,
        width: frame.width,
        height: frame.height,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: ColoredBox(
            color: Colors.black,
            child: NativeCameraView(role: role),
          ),
        ),
      );
}

class _LargeBroadcastScreen extends StatefulWidget {
  const _LargeBroadcastScreen({
    required this.title,
    required this.scene,
    required this.lyricsText,
    required this.scriptureText,
    required this.scriptureReference,
    required this.tickerText,
    required this.tickerSpeed,
    required this.isProgram,
  });

  final String title;
  final Scene? scene;
  final String lyricsText;
  final String scriptureText;
  final String scriptureReference;
  final String tickerText;
  final int tickerSpeed;
  final bool isProgram;

  @override
  State<_LargeBroadcastScreen> createState() => _LargeBroadcastScreenState();
}

class _LargeBroadcastScreenState extends State<_LargeBroadcastScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _tickerController;
  late final Animation<double> _tickerAnimation;

  @override
  void initState() {
    super.initState();
    _tickerController = AnimationController(
      duration: _tickerDuration(widget.tickerSpeed),
      vsync: this,
    )..repeat();
    _tickerAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_tickerController);
  }

  Duration _tickerDuration(int speed) =>
      Duration(milliseconds: (960000 / speed.clamp(10, 100)).round());

  @override
  void didUpdateWidget(covariant _LargeBroadcastScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tickerSpeed != widget.tickerSpeed) {
      _tickerController.duration = _tickerDuration(widget.tickerSpeed);
    }
  }

  @override
  void dispose() {
    _tickerController.dispose();
    super.dispose();
  }

  NormalizedRect _normalizedFrame(NormalizedRect frame, BoxConstraints box) =>
      NormalizedRect(
        x: frame.x * box.maxWidth,
        y: frame.y * box.maxHeight,
        width: frame.width * box.maxWidth,
        height: frame.height * box.maxHeight,
      );

  SceneLayer? _layer(LayerKind kind) {
    final scene = widget.scene;
    if (scene == null) return null;
    for (final layer in scene.layers) {
      if (layer.kind == kind) return layer;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = widget.isProgram ? Colors.red : Colors.blue;
    final hasScene = widget.scene != null;
    final pastorLayer = _layer(LayerKind.pastorVideo);
    final crowdLayer = _layer(LayerKind.crowdVideo);
    final hasLiveLayer = (pastorLayer?.visible ?? false) || (crowdLayer?.visible ?? false);
    final lyricsLayer = _layer(LayerKind.lyrics);
    final scriptureLayer = _layer(LayerKind.scripture);
    final tickerLayer = _layer(LayerKind.ticker);
    final showLyrics = lyricsLayer?.visible ?? false;
    final showScripture = scriptureLayer?.visible ?? false;
    final showTicker = tickerLayer?.visible ?? false;
    final lyrics = showLyrics ? widget.lyricsText.trim() : '';
    final scripture = showScripture ? widget.scriptureText.trim() : '';
    final scriptureReference = showScripture ? widget.scriptureReference.trim() : '';
    final tickerText = widget.tickerText.trim().isEmpty
        ? 'WELCOME TO SUNDAY SERVICE'
        : widget.tickerText;

    return Container(
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border.all(color: borderColor, width: 2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          // Scale every overlay element off the actual rendered frame size
          // (reference: a 320-wide 16:9 frame) so nothing ever collides,
          // no matter how small or large the monitor renders.
          final scale = (box.maxWidth / 320).clamp(0.45, 1.6);
          final tickerHeight = showTicker ? 28 * scale : 0.0;
          final scriptureFrame = scriptureLayer == null
              ? null
              : _normalizedFrame(scriptureLayer.frame, box);
          final lyricsFrame = lyricsLayer == null
              ? null
              : _normalizedFrame(lyricsLayer.frame, box);
          final badgeFontSize = (10 * scale).clamp(7.0, 12.0);
          final lyricsFontSize = (17 * scale).clamp(10.0, 19.0);
          final tickerFontSize = (12 * scale).clamp(8.0, 13.0);
          final waitingFontSize = (11 * scale).clamp(8.0, 12.0);

          return Stack(
            fit: StackFit.expand,
            children: [
              if (pastorLayer?.visible ?? false)
                _LiveCameraLayer(role: 'pastor', frame: _normalizedFrame(pastorLayer!.frame, box)),
              if (crowdLayer?.visible ?? false)
                _LiveCameraLayer(role: 'crowd', frame: _normalizedFrame(crowdLayer!.frame, box)),
              Center(
                child: hasScene && hasLiveLayer
                    ? const SizedBox.shrink()
                    : hasScene
                        ? Icon(Icons.videocam, size: 54 * scale, color: Colors.white.withOpacity(.1))
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.videocam_off, size: 30 * scale, color: Colors.white38),
                          SizedBox(height: 6 * scale),
                          Text(
                            'WAITING FOR CAMERA...',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: waitingFontSize,
                              fontWeight: FontWeight.w700,
                              letterSpacing: .8,
                            ),
                          ),
                        ],
                      ),
              ),
              Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.all(8 * scale),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: FractionallySizedBox(
                      widthFactor: .18,
                      heightFactor: .22,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(5),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(.3), blurRadius: 5)],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(5),
                          child: Image.asset(
                            'assets/images/church_logo.png',
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(Icons.church, color: Colors.blue, size: 22),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (hasScene && showScripture && scripture.isNotEmpty && scriptureFrame != null)
                Positioned(
                  left: scriptureFrame.x,
                  top: scriptureFrame.y,
                  width: scriptureFrame.width,
                  height: scriptureFrame.height,
                  child: Container(
                    margin: EdgeInsets.all(6 * scale),
                    padding: EdgeInsets.symmetric(horizontal: 10 * scale, vertical: 6 * scale),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(.72),
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(color: Colors.white.withOpacity(.2)),
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) => FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.center,
                        child: SizedBox(
                          width: constraints.maxWidth,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                scripture,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: (16 * scale).clamp(10.0, 18.0),
                                  fontWeight: FontWeight.bold,
                                  shadows: const [Shadow(color: Colors.black, blurRadius: 4)],
                                ),
                              ),
                              if (scriptureReference.isNotEmpty) ...[
                                SizedBox(height: 3 * scale),
                                Text(
                                  scriptureReference,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: (11 * scale).clamp(8.0, 13.0),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              if (hasScene && lyrics.isNotEmpty && lyricsFrame != null)
                Positioned(
                  left: lyricsFrame.x,
                  top: lyricsFrame.y,
                  width: lyricsFrame.width,
                  height: lyricsFrame.height,
                  child: Container(
                    margin: EdgeInsets.all(6 * scale),
                    padding: EdgeInsets.symmetric(horizontal: 8 * scale, vertical: 6 * scale),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(.7),
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(color: Colors.white.withOpacity(.2)),
                    ),
                    child: Center(
                      child: Text(
                        lyrics,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: lyricsFontSize,
                          fontWeight: FontWeight.bold,
                          shadows: const [Shadow(color: Colors.black, blurRadius: 4)],
                        ),
                      ),
                    ),
                  ),
                ),
              if (showTicker)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: SizedBox(
                    height: tickerHeight,
                    child: ColoredBox(
                      color: Colors.blue,
                      child: Row(
                        children: [
                          Container(
                            width: 54 * scale,
                            height: tickerHeight,
                            alignment: Alignment.center,
                            color: Colors.yellow,
                            child: Text(
                              'NEWS',
                              maxLines: 1,
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: tickerFontSize,
                                fontWeight: FontWeight.w900,
                                letterSpacing: .4,
                              ),
                            ),
                          ),
                          Expanded(
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final messageStyle = TextStyle(
                                  color: Colors.white,
                                  fontSize: tickerFontSize,
                                  fontWeight: FontWeight.w600,
                                );
                                final messagePainter = TextPainter(
                                  text: TextSpan(text: tickerText, style: messageStyle),
                                  textDirection: TextDirection.ltr,
                                )..layout();
                                final messageGap = 28 * scale;
                                final segmentWidth = messagePainter.width + messageGap;

                                return ClipRect(
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    physics: const NeverScrollableScrollPhysics(),
                                    child: AnimatedBuilder(
                                      animation: _tickerAnimation,
                                      builder: (context, child) => Transform.translate(
                                        offset: Offset(
                                          -_tickerAnimation.value * segmentWidth,
                                          0,
                                        ),
                                        child: child,
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          SizedBox(width: 14 * scale),
                                          Text(tickerText, style: messageStyle),
                                          SizedBox(width: messageGap),
                                          Text(tickerText, style: messageStyle),
                                          SizedBox(width: messageGap),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              Positioned(
                top: 8 * scale,
                right: 8 * scale,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8 * scale, vertical: 4 * scale),
                  decoration: BoxDecoration(
                    color: widget.isProgram ? Colors.red : Colors.blue,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    widget.title,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: badgeFontSize,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({required this.onTab});

  final ValueChanged<int> onTab;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: const Color(0xFF151922),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF252C3A)),
      ),
      child: Column(
        children: [
          TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelPadding: const EdgeInsets.symmetric(horizontal: 11),
            labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            onTap: onTab,
            tabs: DirectorScreen.panelNames
                .map((name) => Tab(text: name))
                .toList(),
          ),
          const Expanded(
            child: TabBarView(
              children: [
                CamerasPanel(),
                LyricsPanel(),
                ScripturePanel(),
                TickerPanel(),
                LogoPanel(),
                LowerThirdPanel(),
                CountdownPanel(),
                PipPanel(),
                StreamingPanel(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.live});

  final String label;
  final bool live;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: live ? const Color(0x332EF06B) : const Color(0x332B3545),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        live ? '● ' + label : label,
        style: TextStyle(
          color: live ? const Color(0xFF4ADE80) : Colors.grey.shade400,
          fontWeight: FontWeight.w800,
          fontSize: 10,
          letterSpacing: 1,
        ),
      ),
    );
  }
}
