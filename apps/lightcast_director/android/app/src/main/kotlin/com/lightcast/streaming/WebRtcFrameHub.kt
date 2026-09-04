package com.lightcast.streaming

import org.webrtc.AudioTrack
import org.webrtc.AudioTrackSink
import org.webrtc.VideoFrame
import org.webrtc.VideoSink
import org.webrtc.VideoTrack
import java.nio.ByteBuffer
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicLong
import java.util.concurrent.atomic.AtomicReference

/**
 * Copies WebRTC frames out of the lifetime-managed WebRTC buffers.
 *
 * RootEncoder renders on its own GL thread, so retaining a VideoFrame.Buffer
 * here would be unsafe. The hub keeps only the newest tightly-packed I420
 * frame per camera role and lets the compositor decide when to upload it.
 */
data class I420Frame(
  val width: Int,
  val height: Int,
  val y: ByteArray,
  val u: ByteArray,
  val v: ByteArray,
  val sequence: Long
)

class WebRtcFrameHub {

  private val sequence = AtomicLong(0)
  private val latest = ConcurrentHashMap<String, AtomicReference<I420Frame?>>()

  fun videoSink(role: String): VideoSink = VideoSink { frame ->
    publish(role, frame)
  }

  fun audioSink(
    role: String,
    onAudio: (String, ByteBuffer, Int, Int, Int, Int, Long) -> Unit
  ): AudioTrackSink =
    AudioTrackSink { audioData, bitsPerSample, sampleRate, numberOfChannels, numberOfFrames, timestamp ->
      onAudio(
        role,
        audioData,
        bitsPerSample,
        sampleRate,
        numberOfChannels,
        numberOfFrames,
        timestamp
      )
    }

  fun attachVideo(role: String, track: VideoTrack) {
    track.addSink(videoSink(role))
  }

  fun attachAudio(
    role: String,
    track: AudioTrack,
    onAudio: (String, ByteBuffer, Int, Int, Int, Int, Long) -> Unit
  ) {
    track.addSink(audioSink(role, onAudio))
  }

  fun latestFrame(role: String): I420Frame? = latest[role]?.get()

  fun clear(role: String? = null) {
    if (role == null) {
      latest.clear()
    } else {
      latest.remove(role)?.set(null)
    }
  }

  private fun publish(role: String, frame: VideoFrame) {
    val i420 = frame.buffer.toI420() ?: return
    try {
      val width = i420.width
      val height = i420.height
      val chromaWidth = (width + 1) / 2
      val chromaHeight = (height + 1) / 2
      latest.getOrPut(role) { AtomicReference(null) }.set(
        I420Frame(
          width = width,
          height = height,
          y = copyPlane(i420.dataY, i420.strideY, width, height),
          u = copyPlane(i420.dataU, i420.strideU, chromaWidth, chromaHeight),
          v = copyPlane(i420.dataV, i420.strideV, chromaWidth, chromaHeight),
          sequence = sequence.incrementAndGet()
        )
      )
    } finally {
      i420.release()
    }
  }

  private fun copyPlane(buffer: ByteBuffer, stride: Int, width: Int, height: Int): ByteArray {
    val output = ByteArray(width * height)
    val source = buffer.duplicate()
    val start = source.position()
    for (row in 0 until height) {
      source.position(start + row * stride)
      source.get(output, row * width, width)
    }
    return output
  }
}