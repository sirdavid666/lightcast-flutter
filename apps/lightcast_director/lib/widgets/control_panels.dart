import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lightcast_shared/lightcast_shared.dart';
import '../state/director_providers.dart';
import '../services/streaming_service.dart';

class PanelShell extends StatelessWidget {
  const PanelShell({required this.children, super.key});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
        children: children,
      );
}

class CamerasPanel extends ConsumerWidget {
  const CamerasPanel({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(productionProvider);
    final controller = ref.read(productionProvider.notifier);
    return PanelShell(
      children: [
        const _DirectorIpCard(),
        const SizedBox(height: 10),
        const _PanelTitle('CAMERA LAYOUT'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _LayoutButton('Pastor Only', CameraLayout.pastorOnly, state.layout, controller.setLayout),
            _LayoutButton('Crowd Only', CameraLayout.crowdOnly, state.layout, controller.setLayout),
            _LayoutButton('Pastor + Crowd', CameraLayout.pastorInCrowd, state.layout, controller.setLayout),
            _LayoutButton('Crowd + Pastor', CameraLayout.crowdInPastor, state.layout, controller.setLayout),
          ],
        ),
        const SizedBox(height: 14),
        const _PanelTitle('SOURCES'),
        ...state.sources.map(
          (source) => ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              Icons.circle,
              color: source.status == 'connected'
                  ? const Color(0xFF22C55E)
                  : Colors.white24,
              size: 10,
            ),
            title: Text(source.label),
            subtitle: Text(
              source.status == 'connected'
                  ? '${source.transport.toUpperCase()} • ${source.signalPercent}% signal'
                  : 'OFFLINE • Pair camera to connect',
            ),
            trailing: Text(
              source.status == 'connected'
                  ? '${source.batteryPercent}%'
                  : 'OFFLINE',
              style: TextStyle(
                color: source.status == 'connected'
                    ? Colors.white
                    : Colors.white38,
                fontSize: 11,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DirectorIpCard extends StatefulWidget {
  const _DirectorIpCard();
  @override
  State<_DirectorIpCard> createState() => _DirectorIpCardState();
}

class _DirectorIpCardState extends State<_DirectorIpCard> {
  TabController? _tabs;
  String _ip = 'Finding LAN address...';
  bool _busy = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final tabs = DefaultTabController.of(context);
    if (_tabs == tabs) return;
    _tabs?.removeListener(_onTabChanged);
    _tabs = tabs..addListener(_onTabChanged);
    if (tabs.index == 0) _loadIp();
  }

  void _onTabChanged() {
    if (_tabs?.index == 0) _loadIp();
  }

  Future<void> _loadIp() async {
    if (_busy) return;
    _busy = true;
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
        includeLinkLocal: false,
      );
      final addresses = interfaces
          .expand((interface) => interface.addresses)
          .where((address) => !address.isLoopback)
          .map((address) => address.address)
          .toList();
      final ip = addresses.firstWhere(_isPrivateIpv4,
          orElse: () => addresses.isEmpty ? 'No LAN IPv4 found' : addresses.first);
      if (mounted) setState(() => _ip = ip);
    } catch (_) {
      if (mounted) setState(() => _ip = 'Unavailable');
    } finally {
      _busy = false;
    }
  }

  bool _isPrivateIpv4(String value) {
    final parts = value.split('.').map(int.tryParse).toList();
    if (parts.length != 4 || parts.any((part) => part == null)) return false;
    final first = parts[0]!;
    final second = parts[1]!;
    return first == 10 ||
        (first == 192 && second == 168) ||
        (first == 172 && second >= 16 && second <= 31);
  }

  @override
  void dispose() {
    _tabs?.removeListener(_onTabChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: const Color(0xFF0D3B66),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF2D7FC1)),
        ),
        child: Row(
          children: [
            const Icon(Icons.router, color: Colors.white, size: 20),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Director IP: ' + _ip,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  const Text('Enter this address on each camera phone to connect.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.white70, fontSize: 11)),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Refresh IP address',
              onPressed: _loadIp,
              icon: const Icon(Icons.refresh, color: Colors.white70, size: 18),
            ),
          ],
        ),
      );
}

class LyricsPanel extends ConsumerStatefulWidget {
  const LyricsPanel({super.key});

  @override
  ConsumerState<LyricsPanel> createState() => _LyricsPanelState();
}

class _LyricsPanelState extends ConsumerState<LyricsPanel> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: ref.read(productionProvider).lyrics.text);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(productionProvider);
    final controller = ref.read(productionProvider.notifier);
    
    if (_controller.text != state.lyrics.text) {
      _controller.text = state.lyrics.text;
    }
    
    return PanelShell(
      children: [
        const _PanelTitle('CURRENT SONG'),
        DropdownButtonFormField<String>(
          value: state.lyrics.section,
          items: const ['Verse', 'Chorus', 'Bridge']
              .map((value) => DropdownMenuItem(value: value, child: Text(value)))
              .toList(),
          onChanged: controller.setLyricsSection,
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: _controller,
          maxLines: 2,
          decoration: const InputDecoration(labelText: 'Lyrics text'),
          onChanged: controller.setLyricsText,
        ),
        const SizedBox(height: 10),
        _ToggleAction(
          label: 'Show lyrics in Preview',
          value: state.previewScene.layers.firstWhere((l) => l.kind == LayerKind.lyrics).visible,
          onChanged: (_) => controller.toggleLayer(LayerKind.lyrics),
        ),
      ],
    );
  }
}

class ScripturePanel extends ConsumerWidget {
  const ScripturePanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(productionProvider);
    final controller = ref.read(productionProvider.notifier);
    return PanelShell(
      children: [
        const _PanelTitle('SCRIPTURE SEARCH'),
        TextFormField(
          initialValue: state.scripture.reference,
          decoration: const InputDecoration(
            hintText: 'Search reference',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 10),
        TextFormField(
          initialValue: state.scripture.text,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Displayed text'),
          onChanged: controller.setScriptureText,
        ),
        const SizedBox(height: 10),
        _ToggleAction(
          label: 'Show scripture in Preview',
          value: state.previewScene.layers.firstWhere((l) => l.kind == LayerKind.scripture).visible,
          onChanged: (_) => controller.toggleLayer(LayerKind.scripture),
        ),
      ],
    );
  }
}

class TickerPanel extends ConsumerStatefulWidget {
  const TickerPanel({super.key});

  @override
  ConsumerState<TickerPanel> createState() => _TickerPanelState();
}

class _TickerPanelState extends ConsumerState<TickerPanel> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: ref.read(productionProvider).ticker.text);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(productionProvider);
    final controller = ref.read(productionProvider.notifier);
    
    if (_controller.text != state.ticker.text) {
      _controller.text = state.ticker.text;
    }
    
    return PanelShell(
      children: [
        const _PanelTitle('TICKER DRAFT'),
        TextFormField(
          controller: _controller,
          maxLines: 2,
          decoration: const InputDecoration(labelText: 'Text (not live yet)'),
          onChanged: controller.setTickerText,
        ),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: controller.updateTicker,
          icon: const Icon(Icons.publish, size: 16),
          label: const Text('UPDATE TICKER'),
        ),
        _ToggleAction(
          label: 'Show ticker in Preview',
          value: state.previewScene.layers.firstWhere((l) => l.kind == LayerKind.ticker).visible,
          onChanged: (_) => controller.toggleLayer(LayerKind.ticker),
        ),
        Text('Speed  ${state.ticker.speed}', style: Theme.of(context).textTheme.bodySmall),
        Slider(
          value: state.ticker.speed.toDouble(),
          min: 10,
          max: 100,
          divisions: 18,
          label: state.ticker.speed.toString(),
          onChanged: controller.setTickerSpeed,
        ),
      ],
    );
  }
}

class LogoPanel extends ConsumerWidget {
  const LogoPanel({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(productionProvider);
    final controller = ref.read(productionProvider.notifier);
    return PanelShell(
      children: [
        const _PanelTitle('CHURCH LOGO'),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const CircleAvatar(child: Icon(Icons.image_outlined)),
          title: Text(state.logo.name),
          subtitle: Text('Opacity ${state.logo.opacity}%'),
          trailing: IconButton(onPressed: () {}, icon: const Icon(Icons.upload_file)),
        ),
        _ToggleAction(
          label: 'Show logo in Preview',
          value: state.previewScene.layers.firstWhere((l) => l.kind == LayerKind.logo).visible,
          onChanged: (_) => controller.toggleLayer(LayerKind.logo),
        ),
      ],
    );
  }
}

class LowerThirdPanel extends ConsumerWidget {
  const LowerThirdPanel({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(productionProvider);
    final controller = ref.read(productionProvider.notifier);
    return PanelShell(
      children: [
        const _PanelTitle('SPEAKER TITLE'),
        TextFormField(
          initialValue: state.lowerThird.name,
          decoration: const InputDecoration(labelText: 'Name'),
          onChanged: (value) => controller.setLowerThird(name: value),
        ),
        const SizedBox(height: 8),
        TextFormField(
          initialValue: state.lowerThird.title,
          decoration: const InputDecoration(labelText: 'Subtitle'),
          onChanged: (value) => controller.setLowerThird(title: value),
        ),
        const SizedBox(height: 8),
        _ToggleAction(
          label: 'Show lower third in Preview',
          value: state.previewScene.layers.firstWhere((l) => l.kind == LayerKind.lowerThird).visible,
          onChanged: (_) => controller.toggleLayer(LayerKind.lowerThird),
        ),
      ],
    );
  }
}

class CountdownPanel extends ConsumerWidget {
  const CountdownPanel({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(productionProvider);
    final controller = ref.read(productionProvider.notifier);
    return PanelShell(
      children: [
        const _PanelTitle('COUNTDOWN'),
        Text('${state.countdown.seconds ~/ 60}:${(state.countdown.seconds % 60).toString().padLeft(2, '0')}',
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton(onPressed: () => controller.setCountdownSeconds(600), child: const Text('10:00')),
            OutlinedButton(onPressed: () => controller.setCountdownSeconds(300), child: const Text('05:00')),
            OutlinedButton(onPressed: controller.toggleCountdownMode, child: Text(state.countdown.mode.name)),
          ],
        ),
        _ToggleAction(
          label: 'Show countdown in Preview',
          value: state.previewScene.layers.firstWhere((l) => l.kind == LayerKind.countdown).visible,
          onChanged: (_) => controller.toggleLayer(LayerKind.countdown),
        ),
      ],
    );
  }
}

class PipPanel extends ConsumerWidget {
  const PipPanel({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(productionProvider.notifier);
    return PanelShell(
      children: [
        const _PanelTitle('PIP POSITION'),
        Row(
          children: [
            IconButton(onPressed: () => controller.movePip(dx: -.04), icon: const Icon(Icons.arrow_back)),
            IconButton(onPressed: () => controller.movePip(dy: -.04), icon: const Icon(Icons.arrow_upward)),
            IconButton(onPressed: () => controller.movePip(dy: .04), icon: const Icon(Icons.arrow_downward)),
            IconButton(onPressed: () => controller.movePip(dx: .04), icon: const Icon(Icons.arrow_forward)),
          ],
        ),
        Row(
          children: [
            OutlinedButton(onPressed: () => controller.movePip(scale: .9), child: const Text('Shrink')),
            const SizedBox(width: 8),
            OutlinedButton(onPressed: () => controller.movePip(scale: 1.1), child: const Text('Grow')),
          ],
        ),
        const SizedBox(height: 8),
        const Text('Drag handles and crop modes are reserved for the native video layer.'),
      ],
    );
  }
}

class StreamingPanel extends ConsumerWidget {
  const StreamingPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(productionProvider);
    final controller = ref.read(productionProvider.notifier);

    return PanelShell(
      children: [
        const _PanelTitle('FACEBOOK LIVE'),
        TextFormField(
          initialValue: state.streamUrl,
          decoration: const InputDecoration(
            labelText: 'Facebook RTMPS URL',
            prefixIcon: Icon(Icons.link),
          ),
          onChanged: controller.setStreamUrl,
        ),
        const SizedBox(height: 10),
        TextFormField(
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Facebook stream key',
            prefixIcon: Icon(Icons.key_outlined),
          ),
          onChanged: controller.setStreamKey,
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: state.liveStatus == 'LIVE' ? Colors.grey : const Color(0xFFB4232F),
            minimumSize: const Size(double.infinity, 50),
          ),
          onPressed: state.liveStatus == 'LIVE'
              ? () async {
                  await StreamingService.stopStream();
                  controller.toggleLive();
                }
              : () async {
                  if (state.streamUrl.trim().isEmpty || state.streamKey.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Enter an RTMPS URL and Stream Key')),
                    );
                    return;
                  }
                  final logoData = await rootBundle.load('assets/images/church_logo.png');
                  final logoBytes = logoData.buffer.asUint8List(
                    logoData.offsetInBytes,
                    logoData.lengthInBytes,
                  );
                  final success = await StreamingService.startStream(
                    url: state.streamUrl.trim(),
                    streamKey: state.streamKey,
                    overlayText: state.lyrics.text,
                    lyrics: state.lyrics.text,
                    ticker: state.ticker.text,
                    logoBytes: logoBytes,
                    layout: state.layout.name,
                  );
                  if (success) controller.toggleLive();
                },
          icon: Icon(state.liveStatus == 'LIVE' ? Icons.stop : Icons.wifi_tethering),
          label: Text(state.liveStatus == 'LIVE' ? 'STOP LIVE' : 'GO LIVE'),
        ),
        const SizedBox(height: 12),
        const Text(
          'Direct Native I420 Composition Engine Active.\nNo screen recording. Pure H.264/AAC stream.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _PanelTitle extends StatelessWidget {
  const _PanelTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1)),
      );
}

class _LayoutButton extends StatelessWidget {
  const _LayoutButton(this.label, this.layout, this.selected, this.onTap);
  final String label;
  final CameraLayout layout;
  final CameraLayout selected;
  final void Function(CameraLayout) onTap;
  @override
  Widget build(BuildContext context) => ChoiceChip(
        label: Text(label),
        selected: layout == selected,
        onSelected: (_) => onTap(layout),
      );
}

class _ToggleAction extends StatelessWidget {
  const _ToggleAction({required this.label, required this.value, required this.onChanged});
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) => SwitchListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        title: Text(label),
        value: value,
        onChanged: onChanged,
      );
}
