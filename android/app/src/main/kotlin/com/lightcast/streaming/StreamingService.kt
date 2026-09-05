package com.lightcast.streaming

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.pedro.common.ConnectChecker
import com.pedro.encoder.input.sources.audio.MicrophoneSource
import com.pedro.encoder.input.sources.video.NoVideoSource
import com.pedro.library.rtmp.RtmpStream
import io.flutter.plugin.common.MethodChannel
import org.webrtc.*
import java.util.concurrent.ConcurrentHashMap

object StreamingService {
    private const val TAG = "LightCastStreaming"
    private val mainHandler = Handler(Looper.getMainLooper())

    private var channel: MethodChannel? = null
    private var factory: PeerConnectionFactory? = null
    private val peerConnections = ConcurrentHashMap<String, PeerConnection>()
    private val frameHub = WebRtcFrameHub()

    private var stream: RtmpStream? = null
    private var filter: CompositionFilterRender? = null

    fun attachChannel(methodChannel: MethodChannel) {
        channel = methodChannel
    }

    private fun ensureFactory(context: Context) {
        if (factory != null) return
        val options = PeerConnectionFactory.InitializationOptions.builder(context)
            .setEnableInternalTracer(true)
            .createInitializationOptions()
        PeerConnectionFactory.initialize(options)
        factory = PeerConnectionFactory.builder().createPeerConnectionFactory()
        Log.d(TAG, "PeerConnectionFactory initialized")
    }

    fun requestOffer(
        context: Context,
        role: String,
        sdp: String,
        callback: (String?) -> Unit,
        onError: (String) -> Unit,
    ) {
        ensureFactory(context)
        val rtcConfig = PeerConnection.RTCConfiguration(
            arrayListOf(PeerConnection.IceServer.builder("stun:stun.l.google.com:19302").createIceServer())
        ).apply { sdpSemantics = PeerConnection.SdpSemantics.UNIFIED_PLAN }

        val pc = factory!!.createPeerConnection(rtcConfig, object : PeerConnection.Observer {
            override fun onIceCandidate(candidate: IceCandidate?) {
                candidate ?: return
                Log.d(TAG, "[$role] local ICE candidate generated")
                mainHandler.post {
                    channel?.invokeMethod(
                        "onIceCandidate",
                        mapOf(
                            "role" to role,
                            "sdp" to candidate.sdp,
                            "mid" to candidate.sdpMid,
                            "lineIndex" to candidate.sdpMLineIndex,
                        )
                    )
                }
            }
            override fun onIceCandidatesRemoved(p0: Array<out IceCandidate>?) {}
            override fun onIceConnectionChange(state: PeerConnection.IceConnectionState?) {
                Log.d(TAG, "[$role] ICE state: $state")
                if (state == PeerConnection.IceConnectionState.FAILED) {
                    Log.e(TAG, "[$role] ICE FAILED")
                }
            }
            override fun onIceGatheringChange(p0: PeerConnection.IceGatheringState?) {}
            override fun onSignalingChange(p0: PeerConnection.SignalingState?) {}
            override fun onAddStream(p0: MediaStream?) {}
            override fun onRemoveStream(p0: MediaStream?) {}
            override fun onDataChannel(p0: DataChannel?) {}
            override fun onRenegotiationNeeded() {}
            override fun onAddTrack(receiver: RtpReceiver?, streams: Array<out MediaStream>?) {
                val track = receiver?.track()
                if (track is VideoTrack) {
                    Log.d(TAG, "[$role] remote video track attached")
                    track.addSink(frameHub.sinkFor(role))
                }
            }
        })

        if (pc == null) {
            onError("createPeerConnection returned null")
            return
        }
        peerConnections[role] = pc

        pc.setRemoteDescription(object : SdpObserver {
            override fun onCreateSuccess(p0: SessionDescription?) {}
            override fun onSetSuccess() {
                pc.createAnswer(object : SdpObserver {
                    override fun onCreateSuccess(desc: SessionDescription?) {
                        desc ?: run { onError("createAnswer returned null description"); return }
                        pc.setLocalDescription(object : SdpObserver {
                            override fun onCreateSuccess(p0: SessionDescription?) {}
                            override fun onSetSuccess() { callback(desc.description) }
                            override fun onCreateFailure(p0: String?) {}
                            override fun onSetFailure(p0: String?) {
                                onError("setLocalDescription failed: $p0")
                            }
                        }, desc)
                    }
                    override fun onSetSuccess() {}
                    override fun onCreateFailure(p0: String?) {
                        onError("createAnswer failed: $p0")
                    }
                    override fun onSetFailure(p0: String?) {}
                }, MediaConstraints())
            }
            override fun onCreateFailure(p0: String?) {}
            override fun onSetFailure(p0: String?) {
                onError("setRemoteDescription failed: $p0")
            }
        }, SessionDescription(SessionDescription.Type.OFFER, sdp))
    }

    fun addIceCandidate(context: Context, role: String, sdp: String, mid: String?, lineIndex: Int) {
        val pc = peerConnections[role]
        if (pc == null) {
            Log.e(TAG, "[$role] addIceCandidate: no peer connection yet")
            return
        }
        pc.addIceCandidate(IceCandidate(mid, lineIndex, sdp))
    }

    fun startStreaming(
        context: Context,
        url: String,
        streamKey: String,
        lyrics: String,
        scripture: String,
        scriptureReference: String,
        lowerThirdName: String,
        lowerThirdTitle: String,
        ticker: String,
        logoBytes: ByteArray?,
        showLyrics: Boolean,
        showScripture: Boolean,
        showLowerThird: Boolean,
        showTicker: Boolean,
        layout: String,
    ) {
        val endpoint = "${url.trimEnd('/')}/$streamKey"
        val publisher = RtmpStream(context = context, connectChecker = object : ConnectChecker {
            override fun onConnectionStarted(url: String) {}
            override fun onConnectionSuccess() {}
            override fun onConnectionFailed(reason: String) { Log.e(TAG, "RTMP connection failed: $reason") }
            override fun onDisconnect() {}
            override fun onAuthError() {}
            override fun onAuthSuccess() {}
        }, videoSource = NoVideoSource(), audioSource = MicrophoneSource())

        publisher.prepareVideo(width = 1280, height = 720, bitrate = 2500000, fps = 30, iFrameInterval = 2, rotation = 0)
        publisher.prepareAudio(sampleRate = 44100, isStereo = true, bitrate = 128000, echoCanceler = true, noiseSuppressor = true)

        filter = CompositionFilterRender(frameHub, lyrics)
        filter?.updateLayout(layout)
        publisher.glInterface.setFilter(0, filter)
        publisher.startStream(endpoint)
        stream = publisher
    }

    fun updateScene(
        context: Context,
        lyrics: String,
        scripture: String,
        scriptureReference: String,
        lowerThirdName: String,
        lowerThirdTitle: String,
        ticker: String,
        logoBytes: ByteArray?,
        showLyrics: Boolean,
        showScripture: Boolean,
        showLowerThird: Boolean,
        showTicker: Boolean,
        layout: String?,
    ) {
        filter?.updateText(lyrics)
        if (layout != null) filter?.updateLayout(layout)
    }

    fun stopStreaming(context: Context) {
        stream?.stopStream()
        stream?.release()
        stream = null
        peerConnections.values.forEach { it.close() }
        peerConnections.clear()
        frameHub.clear()
    }
}
