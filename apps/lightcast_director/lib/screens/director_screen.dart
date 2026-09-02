import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lightcast_shared/lightcast_shared.dart';
import '../app/theme.dart';
import '../state/director_providers.dart';
import '../widgets/control_panels.dart';
import '../widgets/monitor_card.dart';

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

    return DefaultTabController(
      length: panelNames.length,
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              const Icon(
                Icons.waves,
                color: lightcastBlue,
              ),
              const SizedBox(width: 10),
              const Text(
                'LIGHTCAST',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.6,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'DIRECTOR',
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          actions: [
            _StatusPill(
              label: state.liveStatus,
              live: state.liveStatus == 'LIVE',
            ),
            const SizedBox(width: 12),
            const Icon(
              Icons.wifi,
              color: Color(0xFF22C55E),
              size: 18,
            ),
            const SizedBox(width: 18),
          ],
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 700;

            final monitors = _Monitors(
              state: state,
              onTake: controller.take,
            );

            final controls = _Controls(
              onTab: (index) {
                controller.setPanel(panelNames[index]);
              },
            );

            return Padding(
              padding: const EdgeInsets.all(14),
              child: wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: monitors,
                        ),
                        const SizedBox(width: 14),
                        SizedBox(
                          width: 360,
                          child: controls,
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        SizedBox(
                          height: 430,
                          child: monitors,
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 330,
                          child: controls,
                        ),
                      ],
                    ),
            );
          },
        ),
      ),
    );
  }
}

class _Monitors extends StatelessWidget {
  const _Monitors({
    required this.state,
    required this.onTake,
  });

  final ProductionState state;
  final VoidCallback onTake;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: MonitorCard(
                  title: 'Preview',
                  scene: state.previewScene,
                  isProgram: false,
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 82,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.arrow_forward,
                        color: Colors.white30,
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 76,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: lightcastBlue,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: onTake,
                          child: const Text(
                            'TAKE',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: MonitorCard(
                  title: 'Program',
                  scene: state.programScene,
                  isProgram: true,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF151922),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.info_outline,
                size: 16,
                color: Colors.white38,
              ),
              const SizedBox(width: 8),
              Text(
                'Edits are staged in Preview. TAKE publishes the complete scene.',
                style: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.onTab,
  });

  final ValueChanged<int> onTab;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF151922),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF252C3A),
        ),
      ),
      child: Column(
        children: [
          TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelPadding: const EdgeInsets.symmetric(
              horizontal: 12,
            ),
            onTap: onTab,
            tabs: DirectorScreen.panelNames
                .map(
                  (name) => Tab(text: name),
                )
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
  const _StatusPill({
    required this.label,
    required this.live,
  });

  final String label;
  final bool live;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: live
            ? const Color(0x332EF06B)
            : const Color(0x332B3545),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        live ? '● $label' : label,
        style: TextStyle(
          color: live
              ? const Color(0xFF4ADE80)
              : Colors.grey.shade400,
          fontWeight: FontWeight.w800,
          fontSize: 10,
          letterSpacing: 1,
        ),
      ),
    );
  }
}
