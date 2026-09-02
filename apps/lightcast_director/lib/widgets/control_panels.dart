import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lightcast_shared/lightcast_shared.dart';
import '../state/director_providers.dart';

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

class LyricsPanel extends ConsumerWidget {
  const LyricsPanel({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(productionProvider);
    final controller = ref.read(productionProvider.notifier);
    return PanelShell(
      children: [
        const _PanelTitle('CURRENT SONG'),
        DropdownButtonFormField<String>(
          value: state.lyrics.section,
          items: const ['Verse', 'Chorus', 'Bridge']
              .map((value) => DropdownMenuItem(value: value, child: Text(value)))
              .toList(),
          onChanged: (value) {},
        ),
        const SizedBox(height: 10),
        TextFormField(
          initialValue: state.lyrics.text,
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
          onChanged: (_) {},
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

class TickerPanel extends ConsumerWidget {
  const TickerPanel({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(productionProvider);
    final controller = ref.read(productionProvider.notifier);
    return PanelShell(
      children: [
        const _PanelTitle('TICKER DRAFT'),
        TextFormField(
          initialValue: state.ticker.text,
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
        Slider(value: state.ticker.speed.toDouble(), min: 10, max: 100, onChanged: (_) {}),
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
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Facebook stream key',
            prefixIcon: Icon(Icons.key_outlined),
          ),
          onChanged: controller.setStreamKey,
        ),
        const SizedBox(height: 10),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFFB4232F)),
          onPressed: controller.toggleLive,
          icon: Icon(state.liveStatus == 'LIVE' ? Icons.stop : Icons.wifi_tethering),
          label: Text(state.liveStatus == 'LIVE' ? 'STOP LIVE' : 'GO LIVE'),
        ),
        const SizedBox(height: 8),
        const Text('RTMPS engine is isolated behind BroadcastEngine and must be connected for production output.'),
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
