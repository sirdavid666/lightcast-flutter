import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lightcast_shared/lightcast_shared.dart';
import '../app/theme.dart';
import '../state/director_providers.dart';
import '../widgets/control_panels.dart';

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
            Expanded(
              flex: 8,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 5),
                child: Row(
                  children: [
                    Expanded(
                      child: _LargeBroadcastScreen(
                        title: 'PREVIEW',
                        scene: state.previewScene,
                        lyricsText: state.lyrics.text,
                        tickerText: state.ticker.text,
                        isProgram: false,
                      ),
                    ),
                    SizedBox(width: 90, child: _TakeColumn(onTake: controller.take)),
                    Expanded(
                      child: _LargeBroadcastScreen(
                        title: 'PROGRAM',
                        scene: state.programScene,
                        lyricsText: state.lyrics.text,
                        tickerText: state.ticker.text,
                        isProgram: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _StatsBar(),
            Flexible(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 2, 10, 8),
                child: _Controls(
                  onTab: (index) =>
                      controller.setPanel(DirectorScreen.panelNames[index]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TakeColumn extends StatelessWidget {
  const _TakeColumn({required this.onTake});

  final VoidCallback onTake;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 7),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.arrow_forward, color: Colors.white30, size: 22),
          const SizedBox(height: 6),
          Expanded(
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: lightcastBlue,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: onTake,
              child: const FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'TAKE',
                  style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.1, fontSize: 15),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
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

class _LargeBroadcastScreen extends StatefulWidget {
  const _LargeBroadcastScreen({
    required this.title,
    required this.scene,
    required this.lyricsText,
    required this.tickerText,
    required this.isProgram,
  });

  final String title;
  final Scene? scene;
  final String lyricsText;
  final String tickerText;
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
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();
    _tickerAnimation = Tween<double>(begin: 1.0, end: -1.0).animate(_tickerController);
  }

  @override
  void dispose() {
    _tickerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = widget.isProgram ? Colors.red : Colors.blue;
    final hasScene = widget.scene != null;
    final lyrics = widget.lyricsText.trim();
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
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: hasScene
                ? Icon(Icons.videocam, size: 54, color: Colors.white.withOpacity(.1))
                : const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.videocam_off, size: 30, color: Colors.white38),
                      SizedBox(height: 6),
                      Text(
                        'WAITING FOR CAMERA...',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: .8,
                        ),
                      ),
                    ],
                  ),
          ),
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(8),
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
          if (hasScene && lyrics.isNotEmpty)
            Positioned(
              left: 12,
              right: 12,
              bottom: 37,
              child: Container(
                constraints: const BoxConstraints(maxHeight: 66),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(.7),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: Colors.white.withOpacity(.2)),
                ),
                child: Text(
                  lyrics,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                  ),
                ),
              ),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SizedBox(
              height: 28,
              child: ColoredBox(
                color: Colors.blue,
                child: LayoutBuilder(
                  builder: (context, constraints) => ClipRect(
                    child: AnimatedBuilder(
                      animation: _tickerAnimation,
                      builder: (context, child) => Transform.translate(
                        offset: Offset(_tickerAnimation.value * constraints.maxWidth, 0),
                        child: child,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(width: 14),
                          Text(
                            tickerText,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 28),
                          const Text(
                            '• NEWS •',
                            style: TextStyle(
                              color: Colors.yellow,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 28),
                          Text(
                            tickerText,
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: widget.isProgram ? Colors.red : Colors.blue,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                widget.title,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
              ),
            ),
          ),
        ],
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
