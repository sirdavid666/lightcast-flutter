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

    var scene = state.programScene;
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

    state = state.copyWith(layout: layout, programScene: scene);
    _syncNativeScene();
  }

  void toggleLayer(LayerKind kind) {
    final index = state.programScene.layers.indexWhere((l) => l.kind == kind);
    if (index == -1) return;
    final layer = state.programScene.layers[index];
    final next = [...state.programScene.layers];
    next[index] = layer.copyWith(visible: !layer.visible);
    state = state.copyWith(programScene: state.programScene.copyWith(layers: next));
    _syncNativeScene();
  }

  void setLyricsText(String text) {
    final lyrics = state.lyrics.copyWith(text: text);
    final scene = _updateLayer(
      state.programScene,
      'lyrics',
      (layer) => layer.copyWith(payload: {'text': text, 'size': lyrics.fontSize}),
    );
    state = state.copyWith(lyrics: lyrics, programScene: scene);
    _syncNativeScene();
  }

  void setScriptureReference(String reference) {
    state = state.copyWith(
      scripture: state.scripture.copyWith(reference: reference),
    );
    _syncNativeScene();
  }

  void setScriptureText(String text) {
    final scripture = state.scripture.copyWith(text: text);
    final scene = _updateLayer(
      state.programScene,
      'scripture',
      (layer) => layer.copyWith(
        payload: {'text': text, 'reference': scripture.reference},
      ),
    );
    state = state.copyWith(scripture: scripture, programScene: scene);
    _syncNativeScene();
  }

  void setTickerText(String text) {
    final ticker = state.ticker.copyWith(text: text);
    final scene = _updateLayer(
      state.programScene,
      'ticker',
      (layer) => layer.copyWith(payload: {'text': text}),
    );
    state = state.copyWith(ticker: ticker, programScene: scene);
    _syncNativeScene();
  }

  void setLowerThird({String? name, String? title}) {
    final lower = state.lowerThird.copyWith(name: name, title: title);
    final scene = _updateLayer(
      state.programScene,
      'lower-third',
      (layer) => layer.copyWith(
        payload: {'name': lower.name, 'title': lower.title},
      ),
    );
    state = state.copyWith(lowerThird: lower, programScene: scene);
  }

  bool _isProgramLayerVisible(LayerKind kind) => state.programScene.layers
      .firstWhere((layer) => layer.kind == kind)
      .visible;

  void _syncNativeScene() {
    if (state.liveStatus != 'LIVE') return;
    unawaited(NativeStreamingService.updateScene(
      lyrics: state.lyrics.text,
      scripture: state.scripture.text,
      scriptureReference: state.scripture.reference,
      ticker: state.ticker.text,
      showLyrics: _isProgramLayerVisible(LayerKind.lyrics),
      showScripture: _isProgramLayerVisible(LayerKind.scripture),
      showTicker: _isProgramLayerVisible(LayerKind.ticker),
      layout: state.layout.name,
    ));
  }

  void setStreamUrl(String url) => state = state.copyWith(streamUrl: url);

  void setStreamKey(String key) => state = state.copyWith(streamKey: key);

  void setLyricsSection(String? section) {
    if (section == null) return;
    state = state.copyWith(lyrics: state.lyrics.copyWith(section: section));
  }

  void setTickerSpeed(double value) {
    state = state.copyWith(ticker: state.ticker.copyWith(speed: value.round()));
  }

  void setCameraStatus(String role, bool connected) {
    final id = role == 'pastor' ? 'pastor' : 'crowd';
    final sources = state.sources.map((source) {
      if (source.id != id) return source;
      return source.copyWith(
        status: connected ? 'connected' : 'offline',
        transport: connected ? 'webrtc' : 'none',
      );
    }).toList();
    state = state.copyWith(sources: sources);
  }

  void updateTicker() {
    final program = _updateLayer(
      state.programScene,
      'ticker',
      (layer) => layer.copyWith(
        visible: true,
        payload: {'text': state.ticker.text},
      ),
    );
    state = state.copyWith(programScene: program);
    _syncNativeScene();
  }

  void toggleLive() => state = state.copyWith(
        liveStatus: state.liveStatus == 'LIVE' ? 'STANDBY' : 'LIVE',
      );

  void setCountdownSeconds(int seconds) {
    final countdown = state.countdown.copyWith(seconds: seconds);
    final scene = _updateLayer(
      state.programScene,
      'countdown',
      (layer) => layer.copyWith(
        visible: true,
        payload: {'seconds': seconds},
      ),
    );
    state = state.copyWith(countdown: countdown, programScene: scene);
  }

  void toggleCountdownMode() {
    final mode = state.countdown.mode == CountdownMode.corner
        ? CountdownMode.fullScreen
        : CountdownMode.corner;
    state = state.copyWith(countdown: state.countdown.copyWith(mode: mode));
  }

  void movePip({double dx = 0, double dy = 0, double scale = 1}) {
    final scene = _updateLayer(
      state.programScene,
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
    state = state.copyWith(programScene: scene);
  }
}
