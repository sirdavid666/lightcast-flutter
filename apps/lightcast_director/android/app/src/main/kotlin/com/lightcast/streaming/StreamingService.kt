package com.lightcast.streaming

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.BitmapFactory
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import com.lightcast.MainActivity
import com.pedro.common.ConnectChecker
import com.pedro.encoder.input.sources.video.NoVideoSource
import com.pedro.library.rtmp.RtmpStream
import org.webrtc.AudioTrack
import org.webrtc.DefaultVideoDecoderFactory
import org.webrtc.DefaultVideoEncoderFactory
import org.webrtc.EglBase
import org.webrtc.IceCandidate
import org.webrtc.MediaStream
import org.webrtc.MediaConstraints
import org.webrtc.PeerConnection
import org.webrtc.PeerConnectionFactory
import org.webrtc.RtpReceiver
import org.webrtc.SdpObserver
import org.webrtc.SessionDescription
import org.webrtc.VideoTrack
import java.util.concurrent.ConcurrentHashMap

/**
 * Foreground owner of the complete native program output.
 *
 * Flutter only sends commands and scene data to this service. The service's
 * RTMPS publisher never uses a Flutter view or a Flutter texture.
 */
class StreamingService : Service() {

  companion object {
    private const val TAG = "LightCastStreaming"
    private const val CHANNEL_ID = "lightcast_streaming"
    private const val NOTIFICATION_ID = 401

    private const val ACTION_START = "com.lightcast.streaming.START"
    private const val ACTION_STOP = "com.lightcast.streaming.STOP"
    private const val ACTION_OFFER = "com.lightcast.streaming.OFFER"
    private const val ACTION_CANDIDATE = "com.lightcast.streaming.CANDIDATE"
    private const val ACTION_SCENE = "com.lightcast.streaming.SCENE"

    private const val EXTRA_ROLE = "role"
    private const val EXTRA_SDP = "sdp"
    private const val EXTRA_URL = "url"
    private const val EXTRA_STREAM_KEY = "streamKey"
    private const val EXTRA_LYRICS = "lyrics"
    private const val EXTRA_TICKER = "ticker"
    private const val EXTRA_LOGO = "logo"
    private const val EXTRA_LAYOUT = "layout"
    private const val EXTRA_MID = "mid"
    private const val EXTRA_LINE_INDEX = "lineIndex"

    private var service: StreamingService? = null
    private val answerCallbacks = ConcurrentHashMap<String, (String) -> Unit>()

    fun requestOffer(context: Context, role: String, sdp: String, callback: (String) -> Unit) {
      answerCallbacks[role] = callback
      dispatch(
        context,
        Intent(context, StreamingService::class.java)
          .setAction(ACTION_OFFER)
          .putExtra(EXTRA_ROLE, role)
          .putExtra(EXTRA_SDP, sdp)
      )
    }

    fun addIceCandidate(
      context: Context,
      role: String,
      sdp: String,
      mid: String?,
      lineIndex: Int
    ) {
      dispatch(
        context,
        Intent(context, StreamingService::class.java)
          .setAction(ACTION_CANDIDATE)
          .putExtra(EXTRA_ROLE, role)
          .putExtra(EXTRA_SDP, sdp)
          .putExtra(EXTRA_MID, mid)
          .putExtra(EXTRA_LINE_INDEX, lineIndex)
      )
    }

    fun startStreaming(
      context: Context,
      url: String,
      streamKey: String,
      lyrics: String,
      ticker: String,
      logo: ByteArray?,
      layout: String = "pastorOnly"
    ) {
      dispatch(
        context,
        Intent(context, StreamingService::class.java)
          .setAction(ACTION_START)
          .putExtra(EXTRA_URL, url)
          .putExtra(EXTRA_STREAM_KEY, streamKey)
          .putExtra(EXTRA_LYRICS, lyrics)
          .putExtra(EXTRA_TICKER, ticker)
          .putExtra(EXTRA_LOGO, logo)
          .putExtra(EXTRA_LAYOUT, layout)
      )
    }

    fun updateScene(
      context: Context,
      lyrics: String,
      ticker: String,
      logo: ByteArray?,
      layout: String? = null
    ) {
      val sceneIntent = Intent(context, StreamingService::class.java)
        .setAction(ACTION_SCENE)
        .putExtra(EXTRA_LYRICS, lyrics)
        .putExtra(EXTRA_TICKER, ticker)
        .putExtra(EXTRA_LOGO, logo)
      layout?.let { sceneIntent.putExtra(EXTRA_LAYOUT, it) }
      dispatch(context, sceneIntent)
    }

    fun stopStreaming(context: Context) {
      dispatch(context, Intent(context, StreamingService::class.java).setAction(ACTION_STOP))
    }

    private fun dispatch(context: Context, intent: Intent) {
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
        context.startForegroundService(intent)
      } else {
        context.startService(intent)
      }
    }
  }

  private lateinit var eglBase: EglBase
  private lateinit var peerFactory: PeerConnectionFactory
  private lateinit var frameHub: WebRtcFrameHub
  private lateinit var audioMixer: AudioMixer
  private val peers = ConcurrentHashMap<String, PeerConnection>()
  private val attachedVideoTracks = ConcurrentHashMap.newKeySet<String>()
  private val attachedAudioTracks = ConcurrentHashMap.newKeySet<String>()
  private var publisher: RtmpStream? = null
  private var compositor: OpenGLCompositor? = null
  private var startedForeground = false

  override fun onCreate() {
    super.onCreate()
    service = this
    createNotificationChannel()
    startForeground(NOTIFICATION_ID, notification("Preparing native program output"))
    startedForeground = true

    PeerConnectionFactory.initialize(
      PeerConnectionFactory.InitializationOptions.builder(applicationContext)
        .setEnableInternalTracer(false)
        .createInitializationOptions()
    )
    eglBase = EglBase.create()
    peerFactory = PeerConnectionFactory.builder()
      .setVideoEncoderFactory(DefaultVideoEncoderFactory(eglBase.eglBaseContext, true, true))
      .setVideoDecoderFactory(DefaultVideoDecoderFactory(eglBase.eglBaseContext))
      .createPeerConnectionFactory()
    frameHub = WebRtcFrameHub()
    audioMixer = AudioMixer()
  }

  override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
    when (intent?.action) {
      ACTION_START -> startPublisher(
        intent.getStringExtra(EXTRA_URL).orEmpty(),
        intent.getStringExtra(EXTRA_STREAM_KEY).orEmpty(),
        intent.getStringExtra(EXTRA_LYRICS).orEmpty(),
        intent.getStringExtra(EXTRA_TICKER).orEmpty(),
        intent.getByteArrayExtra(EXTRA_LOGO),
        intent.getStringExtra(EXTRA_LAYOUT).orEmpty()
      )
      ACTION_OFFER -> handleOfferInternal(
        intent.getStringExtra(EXTRA_ROLE).orEmpty(),
        intent.getStringExtra(EXTRA_SDP).orEmpty()
      )
      ACTION_CANDIDATE -> addCandidateInternal(
        intent.getStringExtra(EXTRA_ROLE).orEmpty(),
        intent.getStringExtra(EXTRA_SDP).orEmpty(),
        intent.getStringExtra(EXTRA_MID),
        intent.getIntExtra(EXTRA_LINE_INDEX, 0)
      )
      ACTION_SCENE -> updateSceneInternal(
        intent.getStringExtra(EXTRA_LYRICS).orEmpty(),
        intent.getStringExtra(EXTRA_TICKER).orEmpty(),
        intent.getByteArrayExtra(EXTRA_LOGO),
        intent.getStringExtra(EXTRA_LAYOUT)
      )
      ACTION_STOP -> {
        stopPublisher()
        stopSelf()
      }
    }
    return START_STICKY
  }

  override fun onBind(intent: Intent?): IBinder? = null

  override fun onDestroy() {
    stopPublisher()
    peers.values.forEach { it.dispose() }
    peers.clear()
    if (::peerFactory.isInitialized) peerFactory.dispose()
    if (::eglBase.isInitialized) eglBase.release()
    service = null
    super.onDestroy()
  }

  private fun startPublisher(
    baseUrl: String,
    streamKey: String,
    lyrics: String,
    ticker: String,
    logoBytes: ByteArray?,
    layout: String
  ) {
    if (baseUrl.isBlank() || streamKey.isBlank()) {
      Log.e(TAG, "Cannot start RTMPS without URL and stream key")
      return
    }
    stopPublisher()

    val overlayLogo = logoBytes?.let { BitmapFactory.decodeByteArray(it, 0, it.size) }
    val endpoint = "${baseUrl.trimEnd('/')}/$streamKey"
    val output = RtmpStream(
      context = this,
      connectChecker = object : ConnectChecker {
        override fun onConnectionStarted(url: String) = updateNotification("Connecting to Facebook")
        override fun onConnectionSuccess() = updateNotification("LIVE on Facebook")
        override fun onConnectionFailed(reason: String) {
          Log.e(TAG, "RTMPS connection failed: $reason")
          updateNotification("Facebook connection failed")
        }
        override fun onDisconnect() = updateNotification("Stream disconnected")
        override fun onAuthError() = updateNotification("Facebook authentication error")
        override fun onAuthSuccess() = updateNotification("Facebook authenticated")
      },
      videoSource = NoVideoSource(),
      audioSource = audioMixer
    )

    output.prepareVideo(
      width = 1280,
      height = 720,
      bitrate = 2_500_000,
      fps = 30,
      iFrameInterval = 2,
      rotation = 0
    )
    output.prepareAudio(
      sampleRate = 48_000,
      isStereo = true,
      bitrate = 128_000,
      echoCanceler = false,
      noiseSuppressor = false
    )

    val activeCompositor = OpenGLCompositor(frameHub, lyrics, ticker).also {
      it.updateScene(lyrics, ticker, overlayLogo, layout = layout)
    }
    compositor = activeCompositor
    output.getGlInterface().setFilter(activeCompositor)
    output.startStream(endpoint)
    publisher = output
  }

  private fun stopPublisher() {
    publisher?.stopStream()
    publisher?.release()
    publisher = null
    compositor?.release()
    compositor = null
    if (::audioMixer.isInitialized) audioMixer.stop()
    updateNotification("Native engine idle")
  }

  private fun updateSceneInternal(lyrics: String, ticker: String, logoBytes: ByteArray?, layout: String?) {
    if (!::frameHub.isInitialized) return
    val bitmap = logoBytes?.let { BitmapFactory.decodeByteArray(it, 0, it.size) }
    if (bitmap != null) {
      compositor?.updateScene(lyrics, ticker, bitmap, layout = layout)
    } else {
      compositor?.updateScene(lyrics, ticker, layout = layout)
    }
  }

  private fun handleOfferInternal(role: String, sdp: String) {
    if (role.isBlank() || sdp.isBlank()) return
    peers.remove(role)?.dispose()

    val configuration = PeerConnection.RTCConfiguration(
      listOf(
        PeerConnection.IceServer.builder("stun:stun.l.google.com:19302").createIceServer()
      )
    )
    val peer = peerFactory.createPeerConnection(
      configuration,
      peerObserver(role)
    ) ?: return
    peers[role] = peer

    peer.setRemoteDescription(
      SimpleSdpObserver(
        onSetSuccessCallback = {
          peer.createAnswer(
            SimpleSdpObserver(
              onCreateSuccess = { answer ->
                peer.setLocalDescription(
                  SimpleSdpObserver(
                    onSetSuccessCallback = { waitForIceAndAnswer(role) },
                    onFailure = { error -> Log.e(TAG, "Local SDP failed for $role: $error") }
                  ),
                  answer
                )
              },
              onFailure = { error -> Log.e(TAG, "Answer failed for $role: $error") }
            ),
            MediaConstraints()
          )
        },
        onFailure = { error -> Log.e(TAG, "Remote SDP failed for $role: $error") }
      ),
      SessionDescription(SessionDescription.Type.OFFER, sdp)
    )
  }

  private fun waitForIceAndAnswer(role: String) {
    val peer = peers[role] ?: return
    if (peer.iceGatheringState() == PeerConnection.IceGatheringState.COMPLETE) {
      sendAnswer(role)
    } else {
      Handler(Looper.getMainLooper()).postDelayed({ sendAnswer(role) }, 1_500L)
    }
  }

  private fun sendAnswer(role: String) {
    val answer = peers[role]?.localDescription?.description ?: return
    answerCallbacks.remove(role)?.invoke(answer)
  }

  private fun addCandidateInternal(role: String, sdp: String, mid: String?, lineIndex: Int) {
    peers[role]?.addIceCandidate(IceCandidate(mid, lineIndex, sdp))
  }

  private fun peerObserver(role: String) = object : PeerConnection.Observer {
    override fun onIceCandidate(candidate: IceCandidate?) {
      // The camera's signaling path may still use trickle ICE. The current
      // director server sends complete offers, so no native-to-Dart callback
      // is needed yet; this hook is intentionally kept for future signaling.
    }

    override fun onIceCandidatesRemoved(candidates: Array<out IceCandidate>?) = Unit
    override fun onIceCandidateError(event: org.webrtc.IceCandidateErrorEvent?) = Unit
    override fun onSelectedCandidatePairChanged(event: org.webrtc.CandidatePairChangeEvent?) = Unit
    override fun onSignalingChange(state: PeerConnection.SignalingState?) = Unit
    override fun onIceConnectionChange(state: PeerConnection.IceConnectionState?) = Unit
    override fun onStandardizedIceConnectionChange(state: PeerConnection.IceConnectionState?) = Unit
    override fun onIceConnectionReceivingChange(receiving: Boolean) = Unit
    override fun onIceGatheringChange(state: PeerConnection.IceGatheringState?) {
      if (state == PeerConnection.IceGatheringState.COMPLETE) sendAnswer(role)
    }
    override fun onConnectionChange(state: PeerConnection.PeerConnectionState?) = Unit
    override fun onAddStream(stream: MediaStream?) {
      stream?.videoTracks?.forEach { attachVideo(role, it) }
      stream?.audioTracks?.forEach { attachAudio(role, it) }
    }
    override fun onRemoveStream(stream: MediaStream?) = Unit
    override fun onDataChannel(channel: org.webrtc.DataChannel?) = Unit
    override fun onRenegotiationNeeded() = Unit
    override fun onTrack(transceiver: org.webrtc.RtpTransceiver?) {
      val receiver = transceiver?.receiver
      when (val track = receiver?.track()) {
        is VideoTrack -> attachVideo(role, track)
        is AudioTrack -> attachAudio(role, track)
      }
    }
    override fun onAddTrack(receiver: RtpReceiver?, mediaStreams: Array<out MediaStream>?) {
      when (val track = receiver?.track()) {
        is VideoTrack -> attachVideo(role, track)
        is AudioTrack -> attachAudio(role, track)
      }
    }
    override fun onRemoveTrack(receiver: RtpReceiver?) = Unit
  }

  private fun attachVideo(role: String, track: VideoTrack) {
    val key = "$role:${track.id()}"
    if (attachedVideoTracks.add(key)) frameHub.attachVideo(role, track)
  }

  private fun attachAudio(role: String, track: AudioTrack) {
    val key = "$role:${track.id()}"
    if (attachedAudioTracks.add(key)) {
      frameHub.attachAudio(role, track) { streamRole, data, bits, rate, channels, frames, _ ->
        audioMixer.pushPcm(streamRole, data, bits, rate, channels, frames)
      }
    }
  }

  private fun createNotificationChannel() {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
      getSystemService(NotificationManager::class.java).createNotificationChannel(
        NotificationChannel(
          CHANNEL_ID,
          "LightCast streaming",
          NotificationManager.IMPORTANCE_LOW
        )
      )
    }
  }

  private fun notification(text: String): Notification {
    val launchIntent = Intent(this, MainActivity::class.java)
    val pendingIntent = PendingIntent.getActivity(
      this,
      0,
      launchIntent,
      PendingIntent.FLAG_UPDATE_CURRENT or
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
    )
    return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
      Notification.Builder(this, CHANNEL_ID)
        .setContentTitle("LightCast")
        .setContentText(text)
        .setSmallIcon(android.R.drawable.presence_video_online)
        .setContentIntent(pendingIntent)
        .setOngoing(true)
        .build()
    } else {
      @Suppress("DEPRECATION")
      Notification.Builder(this)
        .setContentTitle("LightCast")
        .setContentText(text)
        .setSmallIcon(android.R.drawable.presence_video_online)
        .setContentIntent(pendingIntent)
        .setOngoing(true)
        .build()
    }
  }

  private fun updateNotification(text: String) {
    if (!startedForeground) return
    getSystemService(NotificationManager::class.java).notify(NOTIFICATION_ID, notification(text))
  }

  private class SimpleSdpObserver(
    private val onSetSuccessCallback: () -> Unit = {},
    private val onCreateSuccess: (SessionDescription) -> Unit = {},
    private val onFailure: (String) -> Unit = {}
  ) : SdpObserver {
    override fun onCreateSuccess(description: SessionDescription?) {
      description?.let(onCreateSuccess)
    }
    override fun onSetSuccess(): Unit = onSetSuccessCallback()
    override fun onCreateFailure(error: String?) = onFailure(error.orEmpty())
    override fun onSetFailure(error: String?) = onFailure(error.orEmpty())
  }
}