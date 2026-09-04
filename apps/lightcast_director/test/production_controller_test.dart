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

  test('ticker edits update Program immediately', () {
    final controller = ProductionController();
    controller.setTickerText('WELCOME TO LIGHTCAST');

    final programTicker = controller.state.programScene.layers
        .firstWhere((layer) => layer.id == 'ticker')
        .payload['text'];

    expect(programTicker, 'WELCOME TO LIGHTCAST');
  });
}
