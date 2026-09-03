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
    private val yuvTextures = IntArray(3)
    private var uploadedFrame: I420Frame? = null
    private val textureWidths = IntArray(3)
    private val textureHeights = IntArray(3)

    init {
        val vertices = floatArrayOf(-1f, -1f, 0f, 0f, 0f, 1f, -1f, 0f, 1f, 0f, -1f, 1f, 0f, 0f, 1f, 1f, 1f, 0f, 1f, 1f)
        squareVertex = ByteBuffer.allocateDirect(vertices.size * 4).order(ByteOrder.nativeOrder()).asFloatBuffer().apply { put(vertices); position(0) }
    }

    override fun initGlFilter(context: Context) {
        val vertexShader = "attribute vec4 aPosition; attribute vec4 aTextureCoord; varying vec2 vUv; void main() { gl_Position = aPosition; vUv = aTextureCoord.xy; }"
        val fragmentShader = """
            precision mediump float;
            varying vec2 vUv;
            uniform sampler2D uY; uniform sampler2D uU; uniform sampler2D uV; uniform sampler2D uOverlay;
            void main() {
                vec2 sampleUv = vec2(vUv.x, 1.0 - vUv.y);
                float y = texture2D(uY, sampleUv).r;
                float u = texture2D(uU, sampleUv).r - 0.5;
                float v = texture2D(uV, sampleUv).r - 0.5;
                vec3 rgb = clamp(vec3(y + 1.402 * v, y - 0.344 * u - 0.714 * v, y + 1.772 * u), 0.0, 1.0);
                vec4 overlay = texture2D(uOverlay, vec2(vUv.x, 1.0 - vUv.y));
                gl_FragColor = vec4(mix(rgb, overlay.rgb / max(overlay.a, 0.001), overlay.a), 1.0);
            }
        """.trimIndent()
        
        program = GlUtil.createProgram(vertexShader, fragmentShader)
        positionHandle = GLES20.glGetAttribLocation(program, "aPosition")
        textureCoordHandle = GLES20.glGetAttribLocation(program, "aTextureCoord")
        
        GLES20.glGenTextures(3, yuvTextures, 0)
        for (i in 0..2) {
            GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, yuvTextures[i])
            GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_LINEAR)
            GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_LINEAR)
            GLES20.glTexImage2D(GLES20.GL_TEXTURE_2D, 0, GLES20.GL_LUMINANCE, 1, 1, 0, GLES20.GL_LUMINANCE, GLES20.GL_UNSIGNED_BYTE, ByteBuffer.wrap(byteArrayOf(0)))
        }
        
        val tex = IntArray(1)
        GLES20.glGenTextures(1, tex, 0)
        overlayTexture = tex[0]
    }

    fun updateText(text: String) { overlayText = text }

    override fun drawFilter() {
        val frame = frameHub.latestFrame() ?: return
        if (frame !== uploadedFrame) {
            uploadedFrame = frame
            uploadPlane(yuvTextures[0], frame.y, frame.width, frame.height, 0)
            uploadPlane(yuvTextures[1], frame.u, (frame.width + 1) / 2, (frame.height + 1) / 2, 1)
            uploadPlane(yuvTextures[2], frame.v, (frame.width + 1) / 2, (frame.height + 1) / 2, 2)
        }

        GLES20.glUseProgram(program)
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
        val bitmap = createTextBitmap(overlayText)
        GLUtils.texImage2D(GLES20.GL_TEXTURE_2D, 0, bitmap, 0)
        bitmap.recycle()
        GLES20.glUniform1i(GLES20.glGetUniformLocation(program, "uOverlay"), 3)

        GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)
        GLES20.glDisableVertexAttribArray(positionHandle)
        GLES20.glDisableVertexAttribArray(textureCoordHandle)
    }

    private fun uploadPlane(texture: Int, plane: ByteArray, width: Int, height: Int, index: Int) {
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, texture)
        if (textureWidths[index] != width || textureHeights[index] != height) {
            GLES20.glTexImage2D(GLES20.GL_TEXTURE_2D, 0, GLES20.GL_LUMINANCE, width, height, 0, GLES20.GL_LUMINANCE, GLES20.GL_UNSIGNED_BYTE, ByteBuffer.wrap(plane))
            textureWidths[index] = width; textureHeights[index] = height
        } else {
            GLES20.glTexSubImage2D(GLES20.GL_TEXTURE_2D, 0, 0, 0, width, height, GLES20.GL_LUMINANCE, GLES20.GL_UNSIGNED_BYTE, ByteBuffer.wrap(plane))
        }
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
        GLES20.glDeleteTextures(4, intArrayOf(yuvTextures[0], yuvTextures[1], yuvTextures[2], overlayTexture), 0)
    }
}
