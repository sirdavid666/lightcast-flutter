import 'package:flutter_test/flutter_test.dart';
import 'package:lightcast_director/state/director_providers.dart';
import 'package:lightcast_shared/lightcast_shared.dart';

void main() {
  test('layout changes publish directly to Program', () {
    final controller = ProductionController();
    controller.setLayout(CameraLayout.pastorInCrowd);

    final programPastor = controller.state.programScene.layers
        .firstWhere((layer) => layer.id == 'pastor-video');

    expect(programPastor.frame.x, .72);
  });

  test('overlay toggles update the Program scene', () {
    final controller = ProductionController();

    controller.toggleLayer(LayerKind.ticker);
    expect(
      controller.state.programScene.layers
          .firstWhere((layer) => layer.kind == LayerKind.ticker)
          .visible,
      isFalse,
    );

    controller.toggleLayer(LayerKind.lyrics);
    expect(
      controller.state.programScene.layers
          .firstWhere((layer) => layer.kind == LayerKind.lyrics)
          .visible,
      isTrue,
    );
  });

  test('scripture reference and text update together', () {
    final controller = ProductionController();
    controller.setScriptureReference('Psalm 23:1');
    controller.setScriptureText('The Lord is my shepherd.');

    expect(controller.state.scripture.reference, 'Psalm 23:1');
    expect(controller.state.scripture.text, 'The Lord is my shepherd.');
    expect(
      controller.state.programScene.layers
          .firstWhere((layer) => layer.kind == LayerKind.scripture)
          .payload['text'],
      'The Lord is my shepherd.',
    );
  });

  test('ticker edits update Program immediately', () {
    final controller = ProductionController();
    controller.setTickerText('WELCOME TO LIGHTCAST');

    final programTicker = controller.state.programScene.layers
        .firstWhere((layer) => layer.id == 'ticker')
        .payload['text'];

    expect(programTicker, 'WELCOME TO LIGHTCAST');
  });
}
