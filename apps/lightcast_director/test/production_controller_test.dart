import 'package:flutter_test/flutter_test.dart';
import 'package:lightcast_director/state/director_providers.dart';
import 'package:lightcast_shared/lightcast_shared.dart';

void main() {
  test('TAKE publishes the complete Preview scene', () {
    final controller = ProductionController();
    controller.setLayout(CameraLayout.pastorInCrowd);

    final previewPastor = controller.state.previewScene.layers
        .firstWhere((layer) => layer.id == 'pastor-video');
    final programPastorBefore = controller.state.programScene.layers
        .firstWhere((layer) => layer.id == 'pastor-video');

    expect(programPastorBefore.frame.x, 0);
    expect(previewPastor.frame.x, .72);

    controller.take();

    final programPastorAfter = controller.state.programScene.layers
        .firstWhere((layer) => layer.id == 'pastor-video');
    expect(programPastorAfter.frame.x, .72);
  });

  test('ticker edits remain private until UPDATE TICKER', () {
    final controller = ProductionController();
    controller.setTickerText('WELCOME TO LIGHTCAST');

    final programTickerBefore = controller.state.programScene.layers
        .firstWhere((layer) => layer.id == 'ticker')
        .payload['text'];
    expect(programTickerBefore, isNull);

    controller.updateTicker();

    final programTickerAfter = controller.state.programScene.layers
        .firstWhere((layer) => layer.id == 'ticker')
        .payload['text'];
    expect(programTickerAfter, 'WELCOME TO LIGHTCAST');
  });
}
