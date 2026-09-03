import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:lightcast_shared/lightcast_shared.dart';
import '../app/theme.dart';
import '../state/director_providers.dart';

class MonitorCard extends ConsumerWidget {
  const MonitorCard({
    required this.title,
    required this.scene,
    required this.isProgram,
    super.key,
  });

  final String title;
  final Scene scene;
  final bool isProgram;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final webrtcRenderer = ref.watch(webrtcTransportProvider);
    
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF11151D),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isProgram ? const Color(0xFF7F2028) : const Color(0xFF263247),
          width: 1.5,
        ),
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isProgram ? const Color(0xFFEF4444) : lightcastBlue,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                isProgram ? 'LIVE OUTPUT' : 'STAGED',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isProgram ? const Color(0xFFEF4444) : Colors.grey.shade600,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SceneRenderer(
                scene: scene,
                webrtcRenderer: webrtcRenderer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SceneRenderer extends StatelessWidget {
  const SceneRenderer({
    required this.scene,
    required this.webrtcRenderer,
    super.key,
  });

  final Scene scene;
  final RTCVideoRenderer? webrtcRenderer;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final sorted = [...scene.layers]
            ..sort((a, b) => a.zIndex.compareTo(b.zIndex));
          return Container(
            color: hexColor(scene.backgroundColor),
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: sorted.where((layer) => layer.visible).map((layer) {
                final frame = layer.frame;
                return Positioned(
                  left: constraints.maxWidth * frame.x,
                  top: constraints.maxHeight * frame.y,
                  width: constraints.maxWidth * frame.width,
                  height: constraints.maxHeight * layer.frame.height,
                  child: _LayerView(
                    layer: layer,
                    webrtcRenderer: webrtcRenderer,
                  ),
                );
              }).toList(),
            ),
          );
        },
      );
}

class _LayerView extends ConsumerWidget {
  const _LayerView({
    required this.layer,
    required this.webrtcRenderer,
  });

  final SceneLayer layer;
  final RTCVideoRenderer? webrtcRenderer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    switch (layer.kind) {
      case LayerKind.pastorVideo:
        return _RealVideoFeed(
          label: 'PASTOR CAMERA',
          color: const Color(0xFF18304F),
          renderer: webrtcRenderer,
        );
      case LayerKind.crowdVideo:
        return _RealVideoFeed(
          label: 'CROWD CAMERA',
          color: const Color(0xFF49301C),
          renderer: webrtcRenderer,
        );
      case LayerKind.ticker:
        return _TickerOverlay(text: layer.payload['text'] as String?);
      case LayerKind.logo:
        return const Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: EdgeInsets.all(8),
            child: Text(
              'LIGHTCAST',
              style: TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              ),
            ),
          ),
        );
      case LayerKind.lyrics:
        return _TextOverlay(
          text: layer.payload['text'] as String? ?? 'Lyrics preview',
          color: Colors.white,
        );
      case LayerKind.scripture:
        return _TextOverlay(
          text: layer.payload['text'] as String? ?? 'Scripture preview',
          color: const Color(0xFFE0E7FF),
        );
      case LayerKind.lowerThird:
        final name = layer.payload['name'] as String? ?? 'Pastor David';
        final title = layer.payload['title'] as String? ?? 'Senior Pastor';
        return Align(
          alignment: Alignment.bottomLeft,
          child: Container(
            color: const Color(0xDD111827),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(
              '$name  •  $title',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        );
      case LayerKind.countdown:
        final seconds = layer.payload['seconds'] as int? ?? 600;
        return Center(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Text(
                '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        );
    }
  }
}

class _RealVideoFeed extends StatelessWidget {
  const _RealVideoFeed({
    required this.label,
    required this.color,
    required this.renderer,
  });

  final String label;
  final Color color;
  final RTCVideoRenderer? renderer;

  @override
  Widget build(BuildContext context) {
    // If we have a real WebRTC stream, show it
    if (renderer != null && renderer!.srcObject != null) {
      return RTCVideoView(
        renderer!,
        objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
      );
    }
    
    // Otherwise show the mock feed
    return _MockFeed(label: label, color: color);
  }
}

class _MockFeed extends StatelessWidget {
  const _MockFeed({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, color.withOpacity(.45), Colors.black87],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.videocam_outlined,
                color: Colors.white54,
                size: 34,
              ),
              const SizedBox(height: 6),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 3),
              const FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'WAITING FOR CAMERA...',
                  maxLines: 1,
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 9,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

class _TextOverlay extends StatelessWidget {
  const _TextOverlay({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          color: Colors.black54,
          padding: const EdgeInsets.all(10),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      );
}

class _TickerOverlay extends StatelessWidget {
  const _TickerOverlay({this.text});

  final String? text;

  @override
  Widget build(BuildContext context) => Container(
        color: const Color(0xEE1D4ED8),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text(
          text?.isNotEmpty == true ? text! : 'WELCOME TO SUNDAY SERVICE',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
        ),
      );
}
