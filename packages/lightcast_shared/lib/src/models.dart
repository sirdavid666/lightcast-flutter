enum LayerKind {
  pastorVideo,
  crowdVideo,
  lyrics,
  scripture,
  ticker,
  logo,
  lowerThird,
  countdown,
}

enum CameraLayout {
  pastorOnly,
  crowdOnly,
  pastorInCrowd,
  crowdInPastor,
}

enum TickerDirection { left, right }

enum CountdownMode { fullScreen, corner }

class NormalizedRect {
  const NormalizedRect({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  final double x;
  final double y;
  final double width;
  final double height;

  NormalizedRect copyWith({
    double? x,
    double? y,
    double? width,
    double? height,
  }) =>
      NormalizedRect(
        x: x ?? this.x,
        y: y ?? this.y,
        width: width ?? this.width,
        height: height ?? this.height,
      );
}

class SceneLayer {
  const SceneLayer({
    required this.id,
    required this.kind,
    required this.frame,
    required this.visible,
    required this.zIndex,
    this.payload = const <String, dynamic>{},
  });

  final String id;
  final LayerKind kind;
  final NormalizedRect frame;
  final bool visible;
  final int zIndex;
  final Map<String, dynamic> payload;

  SceneLayer copyWith({
    NormalizedRect? frame,
    bool? visible,
    Map<String, dynamic>? payload,
  }) =>
      SceneLayer(
        id: id,
        kind: kind,
        frame: frame ?? this.frame,
        visible: visible ?? this.visible,
        zIndex: zIndex,
        payload: payload ?? this.payload,
      );
}

class Scene {
  const Scene({
    required this.id,
    required this.name,
    required this.layers,
    this.backgroundColor = '#090B10',
  });

  final String id;
  final String name;
  final List<SceneLayer> layers;
  final String backgroundColor;

  Scene copyWith({String? id, List<SceneLayer>? layers, String? name}) => Scene(
        id: id ?? this.id,
        name: name ?? this.name,
        layers: layers ?? this.layers,
        backgroundColor: backgroundColor,
      );
}

class CameraSource {
  const CameraSource({
    required this.id,
    required this.label,
    required this.role,
    this.status = 'offline',
    this.transport = 'mock',
    this.batteryPercent = -1,
    this.signalPercent = -1,
  });

  final String id;
  final String label;
  final String role;
  final String status;
  final String transport;
  final int batteryPercent;
  final int signalPercent;
}

class LyricsDraft {
  const LyricsDraft({
    this.songTitle = 'Great Is Thy Faithfulness',
    this.section = 'Chorus',
    this.text = 'Great is Thy faithfulness, Lord unto me',
    this.fontSize = 26,
    this.color = '#FFFFFF',
    this.animation = 'Fade',
  });

  final String songTitle;
  final String section;
  final String text;
  final int fontSize;
  final String color;
  final String animation;

  LyricsDraft copyWith({
    String? songTitle,
    String? section,
    String? text,
    int? fontSize,
    String? color,
    String? animation,
  }) =>
      LyricsDraft(
        songTitle: songTitle ?? this.songTitle,
        section: section ?? this.section,
        text: text ?? this.text,
        fontSize: fontSize ?? this.fontSize,
        color: color ?? this.color,
        animation: animation ?? this.animation,
      );
}

class ScriptureDraft {
  const ScriptureDraft({
    this.reference = 'John 3:16',
    this.text =
        'For God so loved the world, that he gave his only begotten Son.',
    this.fontSize = 22,
  });

  final String reference;
  final String text;
  final int fontSize;

  ScriptureDraft copyWith({
    String? reference,
    String? text,
    int? fontSize,
  }) =>
      ScriptureDraft(
        reference: reference ?? this.reference,
        text: text ?? this.text,
        fontSize: fontSize ?? this.fontSize,
      );
}

class TickerDraft {
  const TickerDraft({
    this.text = 'WELCOME TO SUNDAY SERVICE',
    this.speed = 48,
    this.direction = TickerDirection.left,
    this.color = '#FFFFFF',
    this.fontSize = 15,
    this.paused = false,
  });

  final String text;
  final int speed;
  final TickerDirection direction;
  final String color;
  final int fontSize;
  final bool paused;

  TickerDraft copyWith({
    String? text,
    int? speed,
    TickerDirection? direction,
    String? color,
    int? fontSize,
    bool? paused,
  }) =>
      TickerDraft(
        text: text ?? this.text,
        speed: speed ?? this.speed,
        direction: direction ?? this.direction,
        color: color ?? this.color,
        fontSize: fontSize ?? this.fontSize,
        paused: paused ?? this.paused,
      );
}

class LogoDraft {
  const LogoDraft({this.name = 'LIGHTCAST', this.opacity = 92});
  final String name;
  final int opacity;
  LogoDraft copyWith({String? name, int? opacity}) =>
      LogoDraft(name: name ?? this.name, opacity: opacity ?? this.opacity);
}

class LowerThirdDraft {
  const LowerThirdDraft({
    this.name = 'Pastor David',
    this.title = 'Senior Pastor',
  });
  final String name;
  final String title;
  LowerThirdDraft copyWith({String? name, String? title}) =>
      LowerThirdDraft(name: name ?? this.name, title: title ?? this.title);
}

class CountdownDraft {
  const CountdownDraft({
    this.seconds = 600,
    this.mode = CountdownMode.corner,
    this.running = false,
  });
  final int seconds;
  final CountdownMode mode;
  final bool running;
  CountdownDraft copyWith({
    int? seconds,
    CountdownMode? mode,
    bool? running,
  }) =>
      CountdownDraft(
        seconds: seconds ?? this.seconds,
        mode: mode ?? this.mode,
        running: running ?? this.running,
      );
}

class ProductionState {
  const ProductionState({
    required this.previewScene,
    required this.programScene,
    required this.sources,
    this.layout = CameraLayout.pastorOnly,
    this.lyrics = const LyricsDraft(),
    this.scripture = const ScriptureDraft(),
    this.ticker = const TickerDraft(),
    this.logo = const LogoDraft(),
    this.lowerThird = const LowerThirdDraft(),
    this.countdown = const CountdownDraft(),
    this.liveStatus = 'STANDBY',
    this.selectedPanel = 'Cameras',
    this.streamUrl = 'rtmps://live-api-s.facebook.com:443/rtmp/',
    this.streamKey = '',
  });

  final Scene previewScene;
  final Scene programScene;
  final List<CameraSource> sources;
  final CameraLayout layout;
  final LyricsDraft lyrics;
  final ScriptureDraft scripture;
  final TickerDraft ticker;
  final LogoDraft logo;
  final LowerThirdDraft lowerThird;
  final CountdownDraft countdown;
  final String liveStatus;
  final String selectedPanel;
  final String streamUrl;
  final String streamKey;

  ProductionState copyWith({
    Scene? previewScene,
    Scene? programScene,
    List<CameraSource>? sources,
    CameraLayout? layout,
    LyricsDraft? lyrics,
    ScriptureDraft? scripture,
    TickerDraft? ticker,
    LogoDraft? logo,
    LowerThirdDraft? lowerThird,
    CountdownDraft? countdown,
    String? liveStatus,
    String? selectedPanel,
    String? streamUrl,
    String? streamKey,
  }) =>
      ProductionState(
        previewScene: previewScene ?? this.previewScene,
        programScene: programScene ?? this.programScene,
        sources: sources ?? this.sources,
        layout: layout ?? this.layout,
        lyrics: lyrics ?? this.lyrics,
        scripture: scripture ?? this.scripture,
        ticker: ticker ?? this.ticker,
        logo: logo ?? this.logo,
        lowerThird: lowerThird ?? this.lowerThird,
        countdown: countdown ?? this.countdown,
        liveStatus: liveStatus ?? this.liveStatus,
        selectedPanel: selectedPanel ?? this.selectedPanel,
        streamUrl: streamUrl ?? this.streamUrl,
        streamKey: streamKey ?? this.streamKey,
      );
}

Scene initialScene({String id = 'preview', String name = 'Preview'}) => Scene(
      id: id,
      name: name,
      layers: const [
        SceneLayer(
          id: 'pastor-video',
          kind: LayerKind.pastorVideo,
          frame: NormalizedRect(x: 0, y: 0, width: 1, height: 1),
          visible: true,
          zIndex: 0,
        ),
        SceneLayer(
          id: 'crowd-video',
          kind: LayerKind.crowdVideo,
          frame: NormalizedRect(x: .72, y: .68, width: .25, height: .25),
          visible: false,
          zIndex: 1,
        ),
        SceneLayer(
          id: 'lyrics',
          kind: LayerKind.lyrics,
          frame: NormalizedRect(x: .08, y: .72, width: .84, height: .2),
          visible: false,
          zIndex: 2,
        ),
        SceneLayer(
          id: 'scripture',
          kind: LayerKind.scripture,
          frame: NormalizedRect(x: .08, y: .1, width: .84, height: .2),
          visible: false,
          zIndex: 3,
        ),
        SceneLayer(
          id: 'ticker',
          kind: LayerKind.ticker,
          frame: NormalizedRect(x: 0, y: .9, width: 1, height: .1),
          visible: true,
          zIndex: 4,
        ),
        SceneLayer(
          id: 'logo',
          kind: LayerKind.logo,
          frame: NormalizedRect(x: .04, y: .04, width: .18, height: .1),
          visible: true,
          zIndex: 5,
        ),
        SceneLayer(
          id: 'lower-third',
          kind: LayerKind.lowerThird,
          frame: NormalizedRect(x: .06, y: .68, width: .44, height: .16),
          visible: false,
          zIndex: 6,
        ),
        SceneLayer(
          id: 'countdown',
          kind: LayerKind.countdown,
          frame: NormalizedRect(x: .78, y: .05, width: .18, height: .12),
          visible: false,
          zIndex: 7,
        ),
      ],
    );

ProductionState initialProductionState() => ProductionState(
      previewScene: initialScene(),
      programScene: initialScene(id: 'program', name: 'Program'),
      sources: const [
        CameraSource(id: 'pastor', label: 'Pastor Camera', role: 'Pastor'),
        CameraSource(id: 'crowd', label: 'Crowd Camera', role: 'Crowd'),
      ],
    );
