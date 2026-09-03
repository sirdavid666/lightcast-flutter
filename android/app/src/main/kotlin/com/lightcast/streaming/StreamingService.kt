package com.lightcast.streaming

import android.content.Context
import com.pedro.common.ConnectChecker
import com.pedro.encoder.input.sources.audio.MicrophoneSource
import com.pedro.encoder.input.sources.video.NoVideoSource
import com.pedro.library.rtmp.RtmpStream
import org.webrtc.*

class StreamingService(private val context: Context) {
    private var stream: RtmpStream? = null
    private var filter: CompositionFilterRender? = null
    private var peerConnection: PeerConnection? = null
    private val frameHub = WebRtcFrameHub()

    fun handleOffer(sdp: String, onAnswer: (String) -> Unit) {
        val rtcConfig = PeerConnection.RTCConfiguration(arrayListOf(PeerConnection.IceServer.builder("stun:stun.l.google.com:19302").createIceServer()))
        peerConnection = createPeerConnection(rtcConfig, object : PeerConnection.Observer {
            override fun onIceCandidate(p0: IceCandidate?) {}
            override fun onIceCandidatesRemoved(p0: Array<out IceCandidate>?) {}
            override fun onIceConnectionChange(p0: PeerConnection.IceConnectionState?) {}
            override fun onIceGatheringChange(p0: PeerConnection.IceGatheringState?) {}
            override fun onSignalingChange(p0: PeerConnection.SignalingState?) {}
            override fun onAddStream(p0: MediaStream?) {}
            override fun onRemoveStream(p0: MediaStream?) {}
            override fun onDataChannel(p0: DataChannel?) {}
            override fun onRenegotiationNeeded() {}
            override fun onAddTrack(p0: RtpReceiver?, p1: Array<out MediaStream>?) {
                val track = p0?.track()
                if (track is VideoTrack) {
                    track.addSink(frameHub)
                }
            }
        })

        peerConnection?.setRemoteDescription(object : SdpObserver {
            override fun onCreateSuccess(p0: SessionDescription?) {}
            override fun onSetSuccess() {
                peerConnection?.createAnswer(object : SdpObserver {
                    override fun onCreateSuccess(desc: SessionDescription?) {
                        desc?.let {
                            peerConnection?.setLocalDescription(object : SdpObserver {
                                override fun onCreateSuccess(p0: SessionDescription?) {}
                                override fun onSetSuccess() { onAnswer(it.description) }
                                override fun onCreateFailure(p0: String?) {}
                                override fun onSetFailure(p0: String?) {}
                            }, it)
                        }
                    }
                    override fun onSetSuccess() {}
                    override fun onCreateFailure(p0: String?) {}
                    override fun onSetFailure(p0: String?) {}
                }, SessionDescription(SessionDescription.Type.ANSWER, ""))
            }
            override fun onCreateFailure(p0: String?) {}
            override fun onSetFailure(p0: String?) {}
        }, SessionDescription(SessionDescription.Type.OFFER, sdp))
    }

    fun startStream(baseUrl: String, streamKey: String, overlayText: String) {
        val endpoint = "${baseUrl.trimEnd('/')}/$streamKey"
        val publisher = RtmpStream(context = context, connectChecker = object : ConnectChecker {
            override fun onConnectionStarted(url: String) {}
            override fun onConnectionSuccess() {}
            override fun onConnectionFailed(reason: String) {}
            override fun onDisconnect() {}
            override fun onAuthError() {}
            override fun onAuthSuccess() {}
        }, videoSource = NoVideoSource(), audioSource = MicrophoneSource())

        publisher.prepareVideo(width = 1280, height = 720, bitrate = 2500000, fps = 30, iFrameInterval = 2, rotation = 0)
        publisher.prepareAudio(sampleRate = 44100, isStereo = true, bitrate = 128000, echoCanceler = true, noiseSuppressor = true)

        filter = CompositionFilterRender(frameHub, overlayText)
        publisher.glInterface.setFilter(0, filter)
        publisher.startStream(endpoint)
        stream = publisher
    }

    fun stopStream() {
        stream?.stopStream()
        stream?.release()
        stream = null
        peerConnection?.dispose()
        peerConnection = null
        frameHub.clear()
    }
}
