import 'package:flutter/services.dart';

class StreamingService {
  static const MethodChannel _channel = MethodChannel('com.lightcast/streaming');

  static Future<String?> handleOffer(String sdp) async {
    try {
      final result = await _channel.invokeMethod<String>('handleOffer', {'sdp': sdp});
      return result;
    } catch (e) {
      print('WebRTC Offer Error: $e');
      return null;
    }
  }

  static Future<bool> startStream({
    required String url,
    required String streamKey,
    required String overlayText,
  }) async {
    try {
      await _channel.invokeMethod('startStream', {
        'url': url,
        'streamKey': streamKey,
        'overlayText': overlayText,
      });
      return true;
    } catch (e) {
      print('Streaming error: $e');
      return false;
    }
  }

  static Future<void> stopStream() async {
    await _channel.invokeMethod('stopStream');
  }
}
