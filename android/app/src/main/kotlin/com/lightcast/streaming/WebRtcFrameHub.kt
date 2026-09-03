package com.lightcast.streaming

import org.webrtc.VideoFrame
import org.webrtc.VideoSink
import java.nio.ByteBuffer
import java.util.concurrent.atomic.AtomicLong
import java.util.concurrent.atomic.AtomicReference

data class I420Frame(val width: Int, val height: Int, val y: ByteArray, val u: ByteArray, val v: ByteArray, val sequence: Long)

class WebRtcFrameHub : VideoSink {
    private val sequence = AtomicLong(0)
    private val latest = AtomicReference<I420Frame?>(null)

    override fun onFrame(frame: VideoFrame) {
        val i420 = frame.buffer.toI420()
        try {
            val w = i420.width; val h = i420.height
            val y = copyPlane(i420.dataY, i420.strideY, w, h)
            val cw = (w + 1) / 2; val ch = (h + 1) / 2
            val u = copyPlane(i420.dataU, i420.strideU, cw, ch)
            val v = copyPlane(i420.dataV, i420.strideV, cw, ch)
            latest.set(I420Frame(w, h, y, u, v, sequence.incrementAndGet()))
        } finally { i420.release() }
    }
    fun latestFrame(): I420Frame? = latest.get()
    fun clear() { latest.set(null) }

    private fun copyPlane(buffer: ByteBuffer, stride: Int, width: Int, height: Int): ByteArray {
        val output = ByteArray(width * height)
        val source = buffer.duplicate()
        val basePosition = source.position()
        for (row in 0 until height) {
            source.position(basePosition + row * stride)
            source.get(output, row * width, width)
        }
        return output
    }
}
