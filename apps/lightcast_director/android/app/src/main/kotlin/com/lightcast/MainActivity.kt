package com.lightcast

import android.content.pm.ActivityInfo
import android.os.Bundle
import com.lightcast.streaming.StreamingService
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import com.lightcast.CameraPlatformViewFactory

class MainActivity: FlutterActivity() {
    companion object {
        private const val CHANNEL = "com.lightcast/streaming"
    }

    private lateinit var methodChannel: MethodChannel

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Force landscape orientation
        requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE
        
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        flutterEngine.platformViewsController.registry.registerViewFactory(
            "lightcast_camera_view",
            CameraPlatformViewFactory()
        )

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel.setMethodCallHandler { call, result ->
            handleMethod(call, result)
        }
    }

    private fun handleMethod(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "handleOffer" -> {
                val role = call.argument<String>("role") ?: "pastor"
                val sdp = call.argument<String>("sdp") ?: ""
                StreamingService.requestOffer(
                    this,
                    role,
                    sdp,
                    callback = { answer ->
                        runOnUiThread { result.success(answer) }
                    },
                    onError = { error ->
                        runOnUiThread {
                            result.error("WEBRTC_OFFER_FAILED", error, null)
                        }
                    }
                )
            }
            "addIceCandidate" -> {
                StreamingService.addIceCandidate(
                    this,
                    call.argument<String>("role") ?: "pastor",
                    call.argument<String>("sdp") ?: "",
                    call.argument<String>("mid"),
                    call.argument<Int>("lineIndex") ?: 0
                )
                result.success(true)
            }
            "startStream" -> {
                val url = call.argument<String>("url") ?: ""
                val streamKey = call.argument<String>("streamKey") ?: ""
                val lyrics = call.argument<String>("lyrics") ?: call.argument<String>("overlayText") ?: ""
                val scripture = call.argument<String>("scripture") ?: ""
                val scriptureReference = call.argument<String>("scriptureReference") ?: ""
                val lowerThirdName = call.argument<String>("lowerThirdName") ?: ""
                val lowerThirdTitle = call.argument<String>("lowerThirdTitle") ?: ""
                val ticker = call.argument<String>("ticker") ?: ""
                val logoBytes = call.argument<ByteArray>("logoBytes")
                StreamingService.startStreaming(
                    this,
                    url,
                    streamKey,
                    lyrics,
                    scripture,
                    scriptureReference,
                    lowerThirdName,
                    lowerThirdTitle,
                    ticker,
                    logoBytes,
                    call.argument<Boolean>("showLyrics") ?: false,
                    call.argument<Boolean>("showScripture") ?: false,
                    call.argument<Boolean>("showLowerThird") ?: false,
                    call.argument<Boolean>("showTicker") ?: true,
                    call.argument<String>("layout") ?: "pastorOnly"
                )
                result.success(true)
            }
            "updateScene" -> {
                StreamingService.updateScene(
                    this,
                    call.argument<String>("lyrics") ?: "",
                    call.argument<String>("scripture") ?: "",
                    call.argument<String>("scriptureReference") ?: "",
                    call.argument<String>("lowerThirdName") ?: "",
                    call.argument<String>("lowerThirdTitle") ?: "",
                    call.argument<String>("ticker") ?: "",
                    call.argument<ByteArray>("logoBytes"),
                    call.argument<Boolean>("showLyrics") ?: false,
                    call.argument<Boolean>("showScripture") ?: false,
                    call.argument<Boolean>("showLowerThird") ?: false,
                    call.argument<Boolean>("showTicker") ?: true,
                    call.argument<String>("layout")
                )
                result.success(true)
            }
            "stopStream" -> {
                StreamingService.stopStreaming(this)
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }
}
