import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:lightcast_shared/lightcast_shared.dart';
import '../services/native_streaming_service.dart';

// Provider to access the WebRTC transport from main.dart
final webrtcTransportProvider = Provider<RTCVideoRenderer?>((ref) => null);

final productionProvider =
    StateNotifierProvider<ProductionController, ProductionState>(
  (ref) => ProductionController(),
);

class ProductionController extends StateNotifier<ProductionState> {
  ProductionController() : super(initialProductionState());

  Scene _updateLayer(
    Scene scene,
    String id,
    SceneLayer Function(SceneLayer layer) update,
  ) {
    final layers = scene.layers
        .map((layer) => layer.id == id ? update(layer) : layer)
        .toList();
    return scene.copyWith(layers: layers);
  }

  void setPanel(String panel) => state = state.copyWith(selectedPanel: panel);

  void setLayout(CameraLayout layout) {
    final pastor = layout != CameraLayout.crowdOnly;
    final crowd = layout != CameraLayout.pastorOnly;

    final pastorFrame = layout == CameraLayout.crowdInPastor
        ? const NormalizedRect(x: .72, y: .68, width: .25, height: .25)
        : const NormalizedRect(x: 0, y: 0, width: 1, height: 1);

    final crowdFrame = layout == CameraLayout.pastorInCrowd
        ? const NormalizedRect(x: .72, y: .68, width: .25, height: .25)
        : const NormalizedRect(x: 0, y: 0, width: 1, height: 1);

    var scene = state.previewScene;
    scene = _updateLayer(
      scene,
      'pastor-video',
      (layer) => layer.copyWith(frame: pastorFrame, visible: pastor),
    );
    scene = _updateLayer(
      scene,
      'crowd-video',
      (layer) => layer.copyWith(frame: crowdFrame, visible: crowd),
    );

    state = state.copyWith(layout: layout, previewScene: scene);
    _syncNativeScene();
  }

  void toggleLayer(LayerKind kind) {
    final index = state.previewScene.layers.indexWhere((l) => l.kind == kind);
    if (index == -1) return;
    final layer = state.previewScene.layers[index];
    final next = [...state.previewScene.layers];
    next[index] = layer.copyWith(visible: !layer.visible);
    state = state.copyWith(previewScene: state.previewScene.copyWith(layers: next));
  }

  void setLyricsText(String text) {
    final lyrics = state.lyrics.copyWith(text: text);
    final scene = _updateLayer(
      state.previewScene,
      'lyrics',
      (layer) => layer.copyWith(payload: {'text': text, 'size': lyrics.fontSize}),
    );
    state = state.copyWith(lyrics: lyrics, previewScene: scene);
    _syncNativeScene();
  }

  void setScriptureText(String text) {
    final scripture = state.scripture.copyWith(text: text);
    final scene = _updateLayer(
      state.previewScene,
      'scripture',
      (layer) => layer.copyWith(
        payload: {'text': text, 'reference': scripture.reference},
      ),
    );
    state = state.copyWith(scripture: scripture, previewScene: scene);
  }

  void setTickerText(String text) {
    final ticker = state.ticker.copyWith(text: text);
    final scene = _updateLayer(
      state.previewScene,
      'ticker',
      (layer) => layer.copyWith(payload: {'text': text}),
    );
    state = state.copyWith(ticker: ticker, previewScene: scene);
    _syncNativeScene();
  }

  void setLowerThird({String? name, String? title}) {
    final lower = state.lowerThird.copyWith(name: name, title: title);
    final scene = _updateLayer(
      state.previewScene,
      'lower-third',
      (layer) => layer.copyWith(
        payload: {'name': lower.name, 'title': lower.title},
      ),
    );
    state = state.copyWith(lowerThird: lower, previewScene: scene);
  }

  void _syncNativeScene() {
    if (state.liveStatus != 'LIVE') return;
    unawaited(NativeStreamingService.updateScene(
      lyrics: state.lyrics.text,
      ticker: state.ticker.text,
      layout: state.layout.name,
    ));
  }

  void setStreamUrl(String url) => state = state.copyWith(streamUrl: url);

  void setStreamKey(String key) => state = state.copyWith(streamKey: key);

  void updateTicker() {
    final tickerLayer = state.previewScene.layers
        .firstWhere((layer) => layer.id == 'ticker');
    final program = _updateLayer(
      state.programScene,
      'ticker',
      (layer) => layer.copyWith(
        visible: tickerLayer.visible,
        payload: Map<String, dynamic>.from(tickerLayer.payload),
      ),
    );
    final preview = _updateLayer(
      state.previewScene,
      'ticker',
      (layer) => layer.copyWith(visible: true),
    );
    state = state.copyWith(programScene: program, previewScene: preview);
  }

  void take() => state = state.copyWith(
        programScene: state.previewScene.copyWith(
          id: 'program',
          name: 'Program',
        ),
      );

  void toggleLive() => state = state.copyWith(
        liveStatus: state.liveStatus == 'LIVE' ? 'STANDBY' : 'LIVE',
      );

  void setCountdownSeconds(int seconds) {
    final countdown = state.countdown.copyWith(seconds: seconds);
    final scene = _updateLayer(
      state.previewScene,
      'countdown',
      (layer) => layer.copyWith(
        visible: true,
        payload: {'seconds': seconds},
      ),
    );
    state = state.copyWith(countdown: countdown, previewScene: scene);
  }

  void toggleCountdownMode() {
    final mode = state.countdown.mode == CountdownMode.corner
        ? CountdownMode.fullScreen
        : CountdownMode.corner;
    state = state.copyWith(countdown: state.countdown.copyWith(mode: mode));
  }

  void movePip({double dx = 0, double dy = 0, double scale = 1}) {
    final scene = _updateLayer(
      state.previewScene,
      'crowd-video',
      (layer) => layer.copyWith(
        frame: layer.frame.copyWith(
          x: (layer.frame.x + dx).clamp(0.0, .8),
          y: (layer.frame.y + dy).clamp(0.0, .8),
          width: (layer.frame.width * scale).clamp(.12, .8),
          height: (layer.frame.height * scale).clamp(.12, .8),
        ),
      ),
    );
    state = state.copyWith(previewScene: scene);
  }
}
