import 'package:flutter_test/flutter_test.dart';
import 'package:lightcast_camera/services/director_discovery.dart';

void main() {
  test('builds the local /24 scan without probing the camera itself', () {
    final candidates = DirectorDiscovery.localNetworkCandidates('10.3.105.205');

    expect(candidates, hasLength(253));
    expect(candidates.first, '10.3.105.1');
    expect(candidates.last, '10.3.105.254');
    expect(candidates, isNot(contains('10.3.105.205')));
  });

  test('ignores malformed local addresses', () {
    expect(DirectorDiscovery.localNetworkCandidates('not-an-ip'), isEmpty);
  });
}