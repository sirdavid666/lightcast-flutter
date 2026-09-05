import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

/// Finds a LightCast Director on the current Wi-Fi network.
///
/// The Director exposes a small HTTP health endpoint on the same port used by
/// the WebSocket signaling server. Discovery first tries the last successful
/// address, then probes the local /24 network in bounded batches. A /24 is the
/// only subnet size available from Dart's portable NetworkInterface API and is
/// the normal configuration for phone and venue Wi-Fi networks.
class DirectorDiscovery {
  DirectorDiscovery({
    this.port = defaultPort,
    HttpClient Function()? httpClientFactory,
  }) : _httpClientFactory = httpClientFactory ?? HttpClient.new;

  static const int defaultPort = 8080;
  static const String healthPath = '/lightcast/health';
  static const String _cachedHostKey = 'lightcast.director.host';
  static const int _batchSize = 24;
  static const Duration _probeTimeout = Duration(milliseconds: 450);

  final int port;
  final HttpClient Function() _httpClientFactory;

  /// Returns a reachable Director host, or null when no Director is visible.
  Future<String?> discover() async {
    final candidates = <String>[];
    final cached = await cachedHost();
    if (cached != null) candidates.add(cached);

    for (final localAddress in await _localIpv4Addresses()) {
      for (final candidate in localNetworkCandidates(localAddress)) {
        if (!candidates.contains(candidate)) candidates.add(candidate);
      }
    }

    for (var offset = 0; offset < candidates.length; offset += _batchSize) {
      final end = offset + _batchSize > candidates.length
          ? candidates.length
          : offset + _batchSize;
      final batch = candidates.sublist(offset, end);
      final results = await Future.wait(
        batch.map((host) async => (host, await _isDirector(host))),
      );
      for (final result in results) {
        if (result.$2) {
          await rememberHost(result.$1);
          return result.$1;
        }
      }
    }
    return null;
  }

  Future<String?> cachedHost() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final value = preferences.getString(_cachedHostKey)?.trim();
      return value == null || value.isEmpty ? null : value;
    } catch (_) {
      // Discovery still works when the platform preference store is
      // unavailable (for example, before Flutter bindings are initialized).
      return null;
    }
  }

  Future<void> rememberHost(String host) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_cachedHostKey, host);
    } catch (_) {
      // A cache miss is harmless; the next connection can scan again.
    }
  }

  /// Generates the hosts in the /24 containing [localAddress].
  ///
  /// Kept pure so the address calculation can be regression-tested without a
  /// device or a network connection.
  static List<String> localNetworkCandidates(String localAddress) {
    final octets = localAddress.split('.').map(int.tryParse).toList();
    if (octets.length != 4 || octets.any((octet) => octet == null)) {
      return const <String>[];
    }
    final prefix = '${octets[0]}.${octets[1]}.${octets[2]}';
    final localHost = octets[3]!;
    return <String>[
      for (var host = 1; host < 255; host++)
        if (host != localHost) '$prefix.$host',
    ];
  }

  Future<List<String>> _localIpv4Addresses() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
        includeLinkLocal: false,
      );
      return interfaces
          .expand((interface) => interface.addresses)
          .map((address) => address.address)
          .where(_isPrivateIpv4)
          .toSet()
          .toList();
    } catch (_) {
      return const <String>[];
    }
  }

  Future<bool> _isDirector(String host) async {
    final client = _httpClientFactory()
      ..connectionTimeout = _probeTimeout
      ..idleTimeout = _probeTimeout;
    try {
      final request = await client
          .getUrl(Uri(scheme: 'http', host: host, port: port, path: healthPath))
          .timeout(_probeTimeout);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response = await request.close().timeout(_probeTimeout);
      if (response.statusCode != HttpStatus.ok) return false;
      final body = await response.transform(utf8.decoder).join().timeout(_probeTimeout);
      final payload = jsonDecode(body);
      return payload is Map && payload['service'] == 'lightcast-director';
    } catch (_) {
      return false;
    } finally {
      client.close(force: true);
    }
  }

  static bool _isPrivateIpv4(String value) {
    final octets = value.split('.').map(int.tryParse).toList();
    if (octets.length != 4 || octets.any((octet) => octet == null)) return false;
    final first = octets[0]!;
    final second = octets[1]!;
    return first == 10 ||
        (first == 192 && second == 168) ||
        (first == 172 && second >= 16 && second <= 31);
  }
}