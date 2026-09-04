package com.lightcast.streaming

import com.pedro.encoder.Frame
import com.pedro.encoder.input.audio.GetMicrophoneData
import com.pedro.encoder.input.sources.audio.AudioSource
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.ArrayDeque
import java.util.concurrent.Executors
import java.util.concurrent.ScheduledExecutorService
import java.util.concurrent.TimeUnit
import kotlin.math.abs
import kotlin.math.floor
import kotlin.math.roundToInt

/**
 * RootEncoder audio source fed by the decoded WebRTC AudioTrack sinks.
 *
 * WebRTC normally delivers remote audio at 48 kHz. Keeping RootEncoder at
 * 48 kHz avoids an unnecessary quality loss and keeps both camera mics in
 * sync. The mixer also accepts other sample rates and linearly resamples
 * them before they enter the role buffers.
 */
class AudioMixer(
  private val outputSampleRate: Int = 48_000,
  private val channels: Int = 2
) : AudioSource() {

  private val lock = Any()
  private val inputs = linkedMapOf(
    "pastor" to ArrayDeque<Short>(),
    "crowd" to ArrayDeque<Short>()
  )
  private var callback: GetMicrophoneData? = null
  private var worker: ScheduledExecutorService? = null

  override fun create(
    sampleRate: Int,
    isStereo: Boolean,
    echoCanceler: Boolean,
    noiseSuppressor: Boolean
  ): Boolean = true

  override fun start(getMicrophoneData: GetMicrophoneData) {
    callback = getMicrophoneData
    worker?.shutdownNow()
    worker = Executors.newSingleThreadScheduledExecutor { runnable ->
      Thread(runnable, "LightCast-AudioMixer").apply { isDaemon = true }
    }
    worker?.scheduleAtFixedRate(
      { emit20MsFrame() },
      0L,
      20L,
      TimeUnit.MILLISECONDS
    )
  }

  override fun stop() {
    worker?.shutdownNow()
    worker = null
    callback = null
    synchronized(lock) {
      inputs.values.forEach { it.clear() }
    }
  }

  override fun isRunning(): Boolean = worker?.isShutdown == false

  override fun release() {
    stop()
  }

  fun pushPcm(
    role: String,
    data: ByteBuffer,
    bitsPerSample: Int,
    sampleRate: Int,
    inputChannels: Int,
    numberOfFrames: Int
  ) {
    if (bitsPerSample != 16 || inputChannels <= 0 || sampleRate <= 0) return
    val target = inputs[role] ?: return
    val source = data.duplicate().order(ByteOrder.LITTLE_ENDIAN)
    val availableFrames = minOf(numberOfFrames, source.remaining() / (2 * inputChannels))
    if (availableFrames <= 0) return

    val mono = ShortArray(availableFrames)
    for (frame in 0 until availableFrames) {
      var sum = 0
      repeat(inputChannels) {
        sum += source.short.toInt()
      }
      mono[frame] = (sum / inputChannels).coerceIn(Short.MIN_VALUE.toInt(), Short.MAX_VALUE.toInt()).toShort()
    }

    val outputFrames = if (sampleRate == outputSampleRate) {
      mono.size
    } else {
      (mono.size.toDouble() * outputSampleRate / sampleRate).roundToInt()
    }

    synchronized(lock) {
      for (index in 0 until outputFrames) {
        val sourcePosition = index.toDouble() * sampleRate / outputSampleRate
        val leftIndex = floor(sourcePosition).toInt().coerceIn(0, mono.lastIndex)
        val rightIndex = (leftIndex + 1).coerceAtMost(mono.lastIndex)
        val fraction = sourcePosition - floor(sourcePosition)
        val value = (mono[leftIndex] * (1.0 - fraction) + mono[rightIndex] * fraction).roundToInt()
        target.addLast(value.coerceIn(Short.MIN_VALUE.toInt(), Short.MAX_VALUE.toInt()).toShort())
      }

      // A disconnected camera must not cause unbounded memory growth.
      val maxSamples = outputSampleRate * 2
      while (target.size > maxSamples) target.removeFirst()
    }
  }

  private fun emit20MsFrame() {
    val frames = outputSampleRate / 50
    val output = ByteArray(frames * channels * 2)
    val buffer = ByteBuffer.wrap(output).order(ByteOrder.LITTLE_ENDIAN)

    synchronized(lock) {
      repeat(frames) {
        val pastor = if (inputs["pastor"]!!.isEmpty()) 0 else inputs["pastor"]!!.removeFirst().toInt()
        val crowd = if (inputs["crowd"]!!.isEmpty()) 0 else inputs["crowd"]!!.removeFirst().toInt()
        val mixed = (pastor * 0.62f + crowd * 0.62f).roundToInt().coerceIn(-32768, 32767).toShort()
        repeat(channels) { buffer.putShort(mixed) }
      }
    }

    callback?.inputPCMData(
      Frame(
        output,
        0,
        output.size,
        System.nanoTime() / 1_000L
      )
    )
  }
}