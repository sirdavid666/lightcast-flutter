package com.lightcast.streaming

import android.content.Context

class StreamingService(private val context: Context) {

    fun handleOffer(sdp: String, onAnswer: (String) -> Unit) {
        // TODO: real WebRTC offer/answer exchange goes here.
        onAnswer("")
    }

    fun startStream(url: String, streamKey: String, overlayText: String) {
        // TODO: connect this to RootEncoder (RTMP) or your WebRTC pipeline.
    }

    fun stopStream() {
        // TODO: stop the active stream.
    }
}
