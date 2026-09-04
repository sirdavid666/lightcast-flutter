import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Thin control plane for the native Android program output.
///
/// No Flutter widget, texture, or Flutter view is passed to RootEncoder.
/// These calls only configure the native WebRTC -> compositor -> RTMPS graph.
class NativeStreamingService {
  static const MethodChannel _channel = MethodChannel('com.lightcast/streaming');

  static Future<String?> handleOffer({
    required String role,
    required String sdp,
  }) async {
    try {
      return await _channel.invokeMethod<String>('handleOffer', {
        'role': role,
        'sdp': sdp,
      });
    } catch (error) {
      debugPrint('Native WebRTC offer error ($role): $error');
      return null;
    }
  }

  static Future<bool> addIceCandidate({
    required String role,
    required String sdp,
    String? mid,
    required int lineIndex,
  }) async {
    try {
      await _channel.invokeMethod('addIceCandidate', {
        'role': role,
        'sdp': sdp,
        'mid': mid,
        'lineIndex': lineIndex,
      });
      return true;
    } catch (error) {
      debugPrint('Native WebRTC candidate error ($role): $error');
      return false;
    }
  }

  static Future<bool> startStream({
    required String url,
    required String streamKey,
    String overlayText = '',
    String lyrics = '',
    String scripture = '',
    String scriptureReference = '',
    String lowerThirdName = '',
    String lowerThirdTitle = '',
    String ticker = '',
    Uint8List? logoBytes,
    bool showLyrics = false,
    bool showScripture = false,
    bool showLowerThird = false,
    bool showTicker = true,
    String layout = 'pastorOnly',
  }) async {
    try {
      await _channel.invokeMethod('startStream', {
        'url': url,
        'streamKey': streamKey,
        'lyrics': lyrics.isNotEmpty ? lyrics : overlayText,
        'scripture': scripture,
        'scriptureReference': scriptureReference,
        'lowerThirdName': lowerThirdName,
        'lowerThirdTitle': lowerThirdTitle,
        'ticker': ticker,
        'logoBytes': logoBytes,
        'showLyrics': showLyrics,
        'showScripture': showScripture,
        'showLowerThird': showLowerThird,
        'showTicker': showTicker,
        'layout': layout,
      });
      return true;
    } catch (error) {
      debugPrint('Native streaming start error: $error');
      return false;
    }
  }

  static Future<bool> updateScene({
    String lyrics = '',
    String scripture = '',
    String scriptureReference = '',
    String lowerThirdName = '',
    String lowerThirdTitle = '',
    String ticker = '',
    Uint8List? logoBytes,
    bool showLyrics = false,
    bool showScripture = false,
    bool showLowerThird = false,
    bool showTicker = true,
    String? layout,
  }) async {
    try {
      await _channel.invokeMethod('updateScene', {
        'lyrics': lyrics,
        'scripture': scripture,
        'scriptureReference': scriptureReference,
        'lowerThirdName': lowerThirdName,
        'lowerThirdTitle': lowerThirdTitle,
        'ticker': ticker,
        'logoBytes': logoBytes,
        'showLyrics': showLyrics,
        'showScripture': showScripture,
        'showLowerThird': showLowerThird,
        'showTicker': showTicker,
        'layout': layout,
      });
      return true;
    } catch (error) {
      debugPrint('Native scene update error: $error');
      return false;
    }
  }

  static Future<void> stopStream() async {
    try {
      await _channel.invokeMethod('stopStream');
    } catch (error) {
      debugPrint('Native streaming stop error: $error');
    }
  }
}

/// Backwards-compatible name used by the director controls.
class StreamingService {
  static Future<String?> handleOffer(String sdp, {String role = 'pastor'}) =>
      NativeStreamingService.handleOffer(role: role, sdp: sdp);

  static Future<bool> addIceCandidate({
    required String role,
    required String sdp,
    String? mid,
    required int lineIndex,
  }) =>
      NativeStreamingService.addIceCandidate(
        role: role,
        sdp: sdp,
        mid: mid,
        lineIndex: lineIndex,
      );

  static Future<bool> startStream({
    required String url,
    required String streamKey,
    required String overlayText,
    String lyrics = '',
    String scripture = '',
    String scriptureReference = '',
    String lowerThirdName = '',
    String lowerThirdTitle = '',
    String ticker = '',
    Uint8List? logoBytes,
    bool showLyrics = false,
    bool showScripture = false,
    bool showLowerThird = false,
    bool showTicker = true,
    String layout = 'pastorOnly',
  }) =>
      NativeStreamingService.startStream(
        url: url,
        streamKey: streamKey,
        overlayText: overlayText,
        lyrics: lyrics,
        scripture: scripture,
        scriptureReference: scriptureReference,
        lowerThirdName: lowerThirdName,
        lowerThirdTitle: lowerThirdTitle,
        ticker: ticker,
        logoBytes: logoBytes,
        showLyrics: showLyrics,
        showScripture: showScripture,
        showLowerThird: showLowerThird,
        showTicker: showTicker,
        layout: layout,
      );

  static Future<bool> updateScene({
    String lyrics = '',
    String scripture = '',
    String scriptureReference = '',
    String lowerThirdName = '',
    String lowerThirdTitle = '',
    String ticker = '',
    Uint8List? logoBytes,
    bool showLyrics = false,
    bool showScripture = false,
    bool showLowerThird = false,
    bool showTicker = true,
    String? layout,
  }) =>
      NativeStreamingService.updateScene(
        lyrics: lyrics,
        scripture: scripture,
        scriptureReference: scriptureReference,
        lowerThirdName: lowerThirdName,
        lowerThirdTitle: lowerThirdTitle,
        ticker: ticker,
        logoBytes: logoBytes,
        showLyrics: showLyrics,
        showScripture: showScripture,
        showLowerThird: showLowerThird,
        showTicker: showTicker,
        layout: layout,
      );

  static Future<void> stopStream() => NativeStreamingService.stopStream();
}