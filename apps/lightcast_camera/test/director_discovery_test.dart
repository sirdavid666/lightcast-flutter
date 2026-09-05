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
    expect(DirectorDiscovery.localNetworkCandidates('10.3.105'), isEmpty);
    expect(DirectorDiscovery.localNetworkCandidates('10.3.105.256'), isEmpty);
    expect(DirectorDiscovery.localNetworkCandidates('10.3.105.-1'), isEmpty);
  });

  test('rejects IPv4 network and broadcast addresses as local hosts', () {
    expect(DirectorDiscovery.localNetworkCandidates('10.3.105.0'), isEmpty);
    expect(DirectorDiscovery.localNetworkCandidates('10.3.105.255'), isEmpty);
  });
}