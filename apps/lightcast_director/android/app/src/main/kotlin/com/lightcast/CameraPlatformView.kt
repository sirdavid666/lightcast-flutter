package com.lightcast

import android.content.Context
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import com.lightcast.streaming.StreamingService
import org.webrtc.EglBase
import org.webrtc.RendererCommon
import org.webrtc.SurfaceViewRenderer

class CameraPlatformViewFactory : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val role = (args as? Map<*, *>)?.get("role") as? String ?: "pastor"
        return CameraPlatformView(context, role)
    }
}

private class CameraPlatformView(
    context: Context,
    private val role: String,
) : PlatformView {
    private val eglBase = EglBase.create()
    private val renderer = SurfaceViewRenderer(context)

    init {
        renderer.init(eglBase.eglBaseContext, null)
        renderer.setEnableHardwareScaler(true)
        renderer.setScalingType(RendererCommon.ScalingType.SCALE_ASPECT_FILL)
        renderer.setMirror(false)
        StreamingService.registerVideoRenderer(role, renderer)
    }

    override fun getView() = renderer

    override fun dispose() {
        StreamingService.unregisterVideoRenderer(role, renderer)
        renderer.release()
        eglBase.release()
    }
}
