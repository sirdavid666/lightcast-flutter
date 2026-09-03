package com.lightcast

import android.Manifest
import android.content.pm.PackageManager
import androidx.core.content.ContextCompat
import com.lightcast.streaming.StreamingService
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object { private const val CHANNEL = "com.lightcast/streaming" }
    private lateinit var streamingService: StreamingService

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        streamingService = StreamingService(applicationContext)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "handleOffer" -> {
                        val sdp = call.argument<String>("sdp") ?: throw IllegalArgumentException("Missing sdp")
                        streamingService.handleOffer(sdp) { answerSdp ->
                            result.success(answerSdp)
                        }
                    }
                    "startStream" -> {
                        if (ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
                            result.error("PERMISSION_DENIED", "Microphone permission required", null)
                            return@setMethodCallHandler
                        }
                        val url = call.argument<String>("url") ?: throw IllegalArgumentException("Missing url")
                        val streamKey = call.argument<String>("streamKey") ?: throw IllegalArgumentException("Missing streamKey")
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
            } catch (error: Throwable) { 
                result.error("STREAMING_ERROR", error.message, null) 
            }
        }
    }
    
    override fun onDestroy() { 
        if (::streamingService.isInitialized) streamingService.stopStream()
        super.onDestroy() 
    }
}
