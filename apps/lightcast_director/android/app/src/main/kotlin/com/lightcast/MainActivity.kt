package com.lightcast

import android.content.pm.ActivityInfo
import android.os.Bundle
import com.lightcast.streaming.StreamingService
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    companion object {
        private const val CHANNEL = "com.lightcast/streaming"
    }

    private lateinit var streamingService: StreamingService
    private lateinit var methodChannel: MethodChannel

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Force landscape orientation
        requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE
        
        // Initialize streaming service
        streamingService = StreamingService(this)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel.setMethodCallHandler { call, result ->
            handleMethod(call, result)
        }
    }

    private fun handleMethod(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "handleOffer" -> {
                val sdp = call.argument<String>("sdp") ?: ""
                streamingService.handleOffer(sdp) { answer ->
                    result.success(answer)
                }
            }
            "startStream" -> {
                val url = call.argument<String>("url") ?: ""
                val streamKey = call.argument<String>("streamKey") ?: ""
                val overlayText = call.argument<String>("overlayText") ?: ""
                streamingService.startStream(url, streamKey, overlayText)
                result.success(true)
            }
            "stopStream" -> {
                streamingService.stopStream()
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }
}
