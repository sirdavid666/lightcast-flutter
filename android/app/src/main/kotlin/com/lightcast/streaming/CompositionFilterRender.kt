package com.lightcast.streaming

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.opengl.GLES20
import android.opengl.GLUtils
import com.pedro.encoder.input.gl.render.filters.BaseFilterRender
import com.pedro.encoder.utils.gl.GlUtil
import java.nio.ByteBuffer
import java.nio.ByteOrder

class CompositionFilterRender(
    private val frameHub: WebRtcFrameHub,
    private var overlayText: String
) : BaseFilterRender() {

    private var program = 0
    private var positionHandle = 0
    private var textureCoordHandle = 0
    private var overlayTexture = 0

    private val mainYuvTextures = IntArray(3)
    private val pipYuvTextures = IntArray(3)
    private var uploadedMainFrame: I420Frame? = null
    private var uploadedPipFrame: I420Frame? = null
    private val mainTextureSize = IntArray(2)
    private val pipTextureSize = IntArray(2)

    @Volatile private var mainRole: String = "pastor"
    @Volatile private var pipRole: String? = null

    @Volatile private var pipX = 0.62f
    @Volatile private var pipY = 0.62f
    @Volatile private var pipW = 0.32f
    @Volatile private var pipH = 0.32f

    init {
        val vertices = floatArrayOf(-1f, -1f, 0f, 0f, 0f, 1f, -1f, 0f, 1f, 0f, -1f, 1f, 0f, 0f, 1f, 1f, 1f, 0f, 1f, 1f)
        squareVertex = ByteBuffer.allocateDirect(vertices.size * 4).order(ByteOrder.nativeOrder()).asFloatBuffer().apply { put(vertices); position(0) }
    }

    fun updateLayout(layout: String) {
        when (layout) {
            "pastorOnly" -> { mainRole = "pastor"; pipRole = null }
            "crowdOnly" -> { mainRole = "crowd"; pipRole = null }
            "pastorInCrowd" -> { mainRole = "crowd"; pipRole = "pastor" }
            "crowdInPastor" -> { mainRole = "pastor"; pipRole = "crowd" }
            else -> { }
        }
    }

    fun updatePipRect(x: Float, y: Float, w: Float, h: Float) {
        pipX = x.coerceIn(0f, 1f)
        pipY = y.coerceIn(0f, 1f)
        pipW = w.coerceIn(0.05f, 1f)
        pipH = h.coerceIn(0.05f, 1f)
    }

    fun updateText(text: String) { overlayText = text }

    override fun initGlFilter(context: Context) {
        val vertexShader = "attribute vec4 aPosition; attribute vec4 aTextureCoord; varying vec2 vUv; void main() { gl_Position = aPosition; vUv = aTextureCoord.xy; }"
        val fragmentShader = """
            precision mediump float;
            varying vec2 vUv;
            uniform sampler2D uY; uniform sampler2D uU; uniform sampler2D uV; uniform sampler2D uOverlay;
            uniform float uOverlayEnabled;
            void main() {
                vec2 sampleUv = vec2(vUv.x, 1.0 - vUv.y);
                float y = texture2D(uY, sampleUv).r;
                float u = texture2D(uU, sampleUv).r - 0.5;
                float v = texture2D(uV, sampleUv).r - 0.5;
                vec3 rgb = clamp(vec3(y + 1.402 * v, y - 0.344 * u - 0.714 * v, y + 1.772 * u), 0.0, 1.0);
                vec4 overlay = texture2D(uOverlay, vec2(vUv.x, 1.0 - vUv.y));
                float overlayMix = overlay.a * uOverlayEnabled;
                gl_FragColor = vec4(mix(rgb, overlay.rgb / max(overlay.a, 0.001), overlayMix), 1.0);
            }
        """.trimIndent()

        program = GlUtil.createProgram(vertexShader, fragmentShader)
        positionHandle = GLES20.glGetAttribLocation(program, "aPosition")
        textureCoordHandle = GLES20.glGetAttribLocation(program, "aTextureCoord")

        GLES20.glGenTextures(3, mainYuvTextures, 0)
        GLES20.glGenTextures(3, pipYuvTextures, 0)
        for (tex in mainYuvTextures + pipYuvTextures) {
            GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, tex)
            GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_LINEAR)
            GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_LINEAR)
            GLES20.glTexImage2D(GLES20.GL_TEXTURE_2D, 0, GLES20.GL_LUMINANCE, 1, 1, 0, GLES20.GL_LUMINANCE, GLES20.GL_UNSIGNED_BYTE, ByteBuffer.wrap(byteArrayOf(0)))
        }

        val tex = IntArray(1)
        GLES20.glGenTextures(1, tex, 0)
        overlayTexture = tex[0]
    }

    override fun drawFilter() {
        val viewport = IntArray(4)
        GLES20.glGetIntegerv(GLES20.GL_VIEWPORT, viewport, 0)
        val fullX = viewport[0]; val fullY = viewport[1]
        val fullW = viewport[2]; val fullH = viewport[3]

        GLES20.glUseProgram(program)

        GLES20.glViewport(fullX, fullY, fullW, fullH)
        val mainFrame = frameHub.frameFor(mainRole)
        if (mainFrame == null) {
            clearBlack(fullX, fullY, fullW, fullH)
        } else {
            if (mainFrame !== uploadedMainFrame) {
                uploadedMainFrame = mainFrame
                uploadPlane(mainYuvTextures[0], mainFrame.y, mainFrame.width, mainFrame.height, 0, mainTextureSize)
                uploadPlane(mainYuvTextures[1], mainFrame.u, (mainFrame.width + 1) / 2, (mainFrame.height + 1) / 2, 1, mainTextureSize)
                uploadPlane(mainYuvTextures[2], mainFrame.v, (mainFrame.width + 1) / 2, (mainFrame.height + 1) / 2, 2, mainTextureSize)
            }
            drawQuad(mainYuvTextures, overlayEnabled = true)
        }

        val activePipRole = pipRole
        if (activePipRole != null) {
            val pipPxX = fullX + (pipX * fullW).toInt()
            val pipPxY = fullY + ((1f - pipY - pipH) * fullH).toInt()
            val pipPxW = (pipW * fullW).toInt().coerceAtLeast(1)
            val pipPxH = (pipH * fullH).toInt().coerceAtLeast(1)

            GLES20.glViewport(pipPxX, pipPxY, pipPxW, pipPxH)
            val pipFrame = frameHub.frameFor(activePipRole)
            if (pipFrame == null) {
                clearBlack(pipPxX, pipPxY, pipPxW, pipPxH)
            } else {
                if (pipFrame !== uploadedPipFrame) {
                    uploadedPipFrame = pipFrame
                    uploadPlane(pipYuvTextures[0], pipFrame.y, pipFrame.width, pipFrame.height, 0, pipTextureSize)
                    uploadPlane(pipYuvTextures[1], pipFrame.u, (pipFrame.width + 1) / 2, (pipFrame.height + 1) / 2, 1, pipTextureSize)
                    uploadPlane(pipYuvTextures[2], pipFrame.v, (pipFrame.width + 1) / 2, (pipFrame.height + 1) / 2, 2, pipTextureSize)
                }
                drawQuad(pipYuvTextures, overlayEnabled = false)
            }
        }

        GLES20.glViewport(fullX, fullY, fullW, fullH)
    }

    private fun drawQuad(yuvTextures: IntArray, overlayEnabled: Boolean) {
        squareVertex.position(0)
        GLES20.glVertexAttribPointer(positionHandle, 3, GLES20.GL_FLOAT, false, 20, squareVertex)
        GLES20.glEnableVertexAttribArray(positionHandle)
        squareVertex.position(3)
        GLES20.glVertexAttribPointer(textureCoordHandle, 2, GLES20.GL_FLOAT, false, 20, squareVertex)
        GLES20.glEnableVertexAttribArray(textureCoordHandle)

        for (i in 0..2) {
            GLES20.glActiveTexture(GLES20.GL_TEXTURE0 + i)
            GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, yuvTextures[i])
            GLES20.glUniform1i(GLES20.glGetUniformLocation(program, "uY") + i, i)
        }

        GLES20.glActiveTexture(GLES20.GL_TEXTURE3)
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, overlayTexture)
        if (overlayEnabled) {
            val bitmap = createTextBitmap(overlayText)
            GLUtils.texImage2D(GLES20.GL_TEXTURE_2D, 0, bitmap, 0)
            bitmap.recycle()
        }
        GLES20.glUniform1i(GLES20.glGetUniformLocation(program, "uOverlay"), 3)
        GLES20.glUniform1f(GLES20.glGetUniformLocation(program, "uOverlayEnabled"), if (overlayEnabled) 1f else 0f)

        GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)
        GLES20.glDisableVertexAttribArray(positionHandle)
        GLES20.glDisableVertexAttribArray(textureCoordHandle)
    }

    private fun clearBlack(x: Int, y: Int, w: Int, h: Int) {
        GLES20.glEnable(GLES20.GL_SCISSOR_TEST)
        GLES20.glScissor(x, y, w, h)
        GLES20.glClearColor(0f, 0f, 0f, 1f)
        GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT)
        GLES20.glDisable(GLES20.GL_SCISSOR_TEST)
    }

    private fun uploadPlane(texture: Int, plane: ByteArray, width: Int, height: Int, index: Int, sizeCache: IntArray) {
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, texture)
        GLES20.glTexImage2D(GLES20.GL_TEXTURE_2D, 0, GLES20.GL_LUMINANCE, width, height, 0, GLES20.GL_LUMINANCE, GLES20.GL_UNSIGNED_BYTE, ByteBuffer.wrap(plane))
    }

    private fun createTextBitmap(text: String): Bitmap {
        if (text.isBlank()) return Bitmap.createBitmap(1, 1, Bitmap.Config.ARGB_8888)
        val bitmap = Bitmap.createBitmap(1280, 200, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        canvas.drawRect(0f, 100f, 1280f, 200f, Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.argb(180, 0, 0, 0) })
        canvas.drawText(text, 640f, 160f, Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.WHITE; textSize = 60f; textAlign = Paint.Align.CENTER })
        return bitmap
    }

    override fun release() {
        if (program != 0) { GLES20.glDeleteProgram(program); program = 0 }
        GLES20.glDeleteTextures(3, mainYuvTextures, 0)
        GLES20.glDeleteTextures(3, pipYuvTextures, 0)
        GLES20.glDeleteTextures(1, intArrayOf(overlayTexture), 0)
    }
}
