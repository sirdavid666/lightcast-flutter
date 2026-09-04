import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
          title: Row(
            children: [
              const Icon(Icons.waves, color: lightcastBlue),
              const SizedBox(width: 10),
              const Text('LIGHTCAST', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.6)),
              const SizedBox(width: 10),
              Text('DIRECTOR', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
            ],
          ),
          actions: [
            _StatusPill(label: state.liveStatus, live: state.liveStatus == 'LIVE'),
            const SizedBox(width: 12),
            const Icon(Icons.wifi, color: Color(0xFF22C55E), size: 18),
            const SizedBox(width: 18),
          ],
        ),
        body: Column(
          children: [
            // LARGE PREVIEW & PROGRAM SCREENS
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
                child: Row(
                  children: [
                    // PREVIEW SCREEN (Left - Large)
                    Expanded(
                      child: _LargeBroadcastScreen(
                        title: 'PREVIEW',
                        scene: state.previewScene,
                        isProgram: false,
                        onTake: controller.take,
                      ),
                    ),
                    
                    // TAKE BUTTON (Center)
                    Container(
                      width: 80,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.arrow_forward, color: Colors.white30, size: 32),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 100,
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: lightcastBlue,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: controller.take,
                              child: const Text('TAKE', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2, fontSize: 16)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // PROGRAM SCREEN (Right - Large)
                    Expanded(
                      child: _LargeBroadcastScreen(
                        title: 'PROGRAM',
                        scene: state.programScene,
                        isProgram: true,
                        onTake: () {},
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // INFO BAR
            Container(
              margin: const EdgeInsets.fromLTRB(14, 0, 14, 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(color: const Color(0xFF151922), borderRadius: BorderRadius.circular(10)),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 16, color: Colors.white38),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Edits are staged in Preview. TAKE publishes the complete scene.', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey.shade400, fontSize: 12))),
                ],
              ),
            ),
            
            // CONTROL PANELS (Tabs)
            SizedBox(
              height: 320,
              child: _Controls(onTab: (index) => controller.setPanel(DirectorScreen.panelNames[index])),
            ),
          ],
        ),
      ),
    );
  }
}

// NEW: Large Broadcast Screen with Logo, Ticker, and Lyrics
class _LargeBroadcastScreen extends StatefulWidget {
  final String title;
  final dynamic scene;  // ✅ USE dynamic instead
  final bool isProgram;
  final VoidCallback onTake;

  const _LargeBroadcastScreen({
    required this.title,
    required this.scene,
    required this.isProgram,
    required this.onTake,
  });

  @override
  State<_LargeBroadcastScreen> createState() => _LargeBroadcastScreenState();
}

class _LargeBroadcastScreenState extends State<_LargeBroadcastScreen> with SingleTickerProviderStateMixin {
  late AnimationController _tickerController;
  late Animation<double> _tickerAnimation;

  @override
  void initState() {
    super.initState();
    // Scrolling ticker animation
    _tickerController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    );
    _tickerAnimation = Tween<double>(begin: 1.0, end: -0.5).animate(_tickerController);
    _tickerController.repeat();
  }

  @override
  void dispose() {
    _tickerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = widget.isProgram ? Colors.red : Colors.blue;
    final lyrics = widget.scene.lyrics?.text ?? '';
    final tickerText = widget.scene.ticker?.text ?? 'WELCOME TO SUNDAY SERVICE';

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: borderColor, width: 3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background (Black)
          Container(color: Colors.black),

          // Center Icon (Placeholder for video)
          Center(
            child: Icon(Icons.videocam, size: 100, color: Colors.white.withOpacity(0.1)),
          ),

          // Church Logo (Top Left)
          Positioned(
            top: 16,
            left: 16,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 8)],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  'assets/images/church_logo.png',
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(Icons.church, color: Colors.blue, size: 40);
                  },
                ),
              ),
            ),
          ),

          // Lyrics Overlay (Center-Bottom, Large Text)
          if (lyrics.isNotEmpty)
            Positioned(
              bottom: 80,
              left: 24,
              right: 24,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: Text(
                  lyrics,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    shadows: [Shadow(color: Colors.black, blurRadius: 6)],
                  ),
                ),
              ),
            ),

          // Scrolling Ticker (Bottom)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 50,
              color: Colors.blue[900],
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedBuilder(
                    animation: _tickerAnimation,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(_tickerAnimation.value * MediaQuery.of(context).size.width, 0),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(width: 20),
                            Text(
                              tickerText,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 40),
                            Text(
                              '• NEWS • ',
                              style: TextStyle(color: Colors.yellow[300], fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 20),
                            Text(
                              tickerText,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 40),
                            Text(
                              tickerText,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // Title Badge (Top Right)
          Positioned(
            top: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: widget.isProgram ? Colors.red : Colors.blue,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                widget.title,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
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
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(color: const Color(0xFF151922), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF252C3A))),
        child: Column(
          children: [
            TabBar(isScrollable: true, tabAlignment: TabAlignment.start, labelPadding: const EdgeInsets.symmetric(horizontal: 12), onTap: onTab, tabs: DirectorScreen.panelNames.map((name) => Tab(text: name)).toList()),
            const Expanded(child: TabBarView(children: [CamerasPanel(), LyricsPanel(), ScripturePanel(), TickerPanel(), LogoPanel(), LowerThirdPanel(), CountdownPanel(), PipPanel(), StreamingPanel()])),
          ],
        ),
      );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.live});
  final String label;
  final bool live;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: live ? const Color(0x332EF06B) : const Color(0x332B3545), borderRadius: BorderRadius.circular(5)),
        child: Text(live ? '● $label' : label, style: TextStyle(color: live ? const Color(0xFF4ADE80) : Colors.grey.shade400, fontWeight: FontWeight.w800, fontSize: 10, letterSpacing: 1)),
      );
}
