package com.lightcast.streaming

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.opengl.GLES20
import android.opengl.GLUtils
import com.pedro.encoder.input.gl.render.filters.BaseFilterRender
import com.pedro.encoder.utils.gl.GlUtil
import java.nio.ByteBuffer
import java.nio.ByteOrder

/**
 * The program output. It never receives a Flutter surface; RootEncoder
 * consumes this filter's FBO, which keeps director controls out of RTMPS.
 */
class OpenGLCompositor(
  private val frameHub: WebRtcFrameHub,
  private var lyricsText: String = "",
  private var tickerText: String = ""
) : BaseFilterRender() {

  companion object {
    private const val OUTPUT_WIDTH = 1280
    private const val OUTPUT_HEIGHT = 720
  }

  private val vertices = floatArrayOf(
    -1f, -1f, 0f, 0f, 0f,
     1f, -1f, 0f, 1f, 0f,
    -1f,  1f, 0f, 0f, 1f,
     1f,  1f, 0f, 1f, 1f
  )
  private val vertexBuffer = ByteBuffer
    .allocateDirect(vertices.size * 4)
    .order(ByteOrder.nativeOrder())
    .asFloatBuffer()
    .apply {
      put(vertices)
      position(0)
    }

  private val pastorTextures = IntArray(3)
  private val crowdTextures = IntArray(3)
  private val overlayTexture = IntArray(1)
  private val textureWidths = IntArray(6)
  private val textureHeights = IntArray(6)

  private var scriptureText = ""
  private var scriptureReference = ""
  private var showLyrics = true
  private var showScripture = false
  private var showTicker = true

  private var program = 0
  private var positionHandle = 0
  private var textureCoordHandle = 0
  private var pastorRectHandle = 0
  private var crowdRectHandle = 0
  private var hasPastorHandle = 0
  private var hasCrowdHandle = 0
  private var pastorYHandle = 0
  private var pastorUHandle = 0
  private var pastorVHandle = 0
  private var crowdYHandle = 0
  private var crowdUHandle = 0
  private var crowdVHandle = 0
  private var overlayHandle = 0
  private var overlayDirty = true
  private var logo: Bitmap? = null
  private var uploadedPastor: I420Frame? = null
  private var uploadedCrowd: I420Frame? = null

  // Rectangles use Flutter's normalized top-left coordinates.
  private var pastorRect = RectF(0f, 0f, 1f, 1f)
  private var crowdRect = RectF(0.72f, 0.68f, 0.97f, 0.97f)
  private var pastorVisible = true
  private var crowdVisible = false

  override fun initGlFilter(context: Context) {
    val vertexShader = """
      attribute vec4 aPosition;
      attribute vec4 aTextureCoord;
      varying vec2 vUv;
      void main() {
        gl_Position = aPosition;
        vUv = aTextureCoord.xy;
      }
    """.trimIndent()

    val fragmentShader = """
      precision mediump float;
      varying vec2 vUv;
      uniform sampler2D uPastorY;
      uniform sampler2D uPastorU;
      uniform sampler2D uPastorV;
      uniform sampler2D uCrowdY;
      uniform sampler2D uCrowdU;
      uniform sampler2D uCrowdV;
      uniform sampler2D uOverlay;
      uniform vec4 uPastorRect;
      uniform vec4 uCrowdRect;
      uniform float uHasPastor;
      uniform float uHasCrowd;

      vec3 yuvToRgb(sampler2D yTexture, sampler2D uTexture, sampler2D vTexture, vec2 uv) {
        vec2 sampleUv = vec2(uv.x, 1.0 - uv.y);
        float y = texture2D(yTexture, sampleUv).r;
        float u = texture2D(uTexture, sampleUv).r - 0.5;
        float v = texture2D(vTexture, sampleUv).r - 0.5;
        return clamp(vec3(
          y + 1.402 * v,
          y - 0.344136 * u - 0.714136 * v,
          y + 1.772 * u
        ), 0.0, 1.0);
      }

      bool inside(vec2 point, vec4 rect) {
        return point.x >= rect.x && point.y >= rect.y &&
          point.x <= rect.x + rect.z && point.y <= rect.y + rect.w;
      }

      void main() {
        vec3 rgb = vec3(0.035, 0.04, 0.055);

        if (uHasPastor > 0.5 && inside(vUv, uPastorRect)) {
          vec2 localUv = (vUv - uPastorRect.xy) / uPastorRect.zw;
          rgb = yuvToRgb(uPastorY, uPastorU, uPastorV, localUv);
        }

        if (uHasCrowd > 0.5 && inside(vUv, uCrowdRect)) {
          vec2 localUv = (vUv - uCrowdRect.xy) / uCrowdRect.zw;
          rgb = yuvToRgb(uCrowdY, uCrowdU, uCrowdV, localUv);
        }

        vec4 overlay = texture2D(uOverlay, vec2(vUv.x, 1.0 - vUv.y));
        gl_FragColor = vec4(mix(rgb, overlay.rgb, overlay.a), 1.0);
      }
    """.trimIndent()

    program = GlUtil.createProgram(vertexShader, fragmentShader)
    positionHandle = GLES20.glGetAttribLocation(program, "aPosition")
    textureCoordHandle = GLES20.glGetAttribLocation(program, "aTextureCoord")
    pastorRectHandle = GLES20.glGetUniformLocation(program, "uPastorRect")
    crowdRectHandle = GLES20.glGetUniformLocation(program, "uCrowdRect")
    hasPastorHandle = GLES20.glGetUniformLocation(program, "uHasPastor")
    hasCrowdHandle = GLES20.glGetUniformLocation(program, "uHasCrowd")
    pastorYHandle = GLES20.glGetUniformLocation(program, "uPastorY")
    pastorUHandle = GLES20.glGetUniformLocation(program, "uPastorU")
    pastorVHandle = GLES20.glGetUniformLocation(program, "uPastorV")
    crowdYHandle = GLES20.glGetUniformLocation(program, "uCrowdY")
    crowdUHandle = GLES20.glGetUniformLocation(program, "uCrowdU")
    crowdVHandle = GLES20.glGetUniformLocation(program, "uCrowdV")
    overlayHandle = GLES20.glGetUniformLocation(program, "uOverlay")

    createLumaTextures(pastorTextures)
    createLumaTextures(crowdTextures)
    GlUtil.createTextures(1, overlayTexture, 0)
    GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, overlayTexture[0])
    GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_LINEAR)
    GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_LINEAR)
    GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_S, GLES20.GL_CLAMP_TO_EDGE)
    GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_T, GLES20.GL_CLAMP_TO_EDGE)
  }

  fun updateScene(
    lyrics: String,
    ticker: String,
    logoBitmap: Bitmap? = logo,
    pastorFrame: RectF = pastorRect,
    crowdFrame: RectF = crowdRect,
    layout: String? = null,
    scripture: String = "",
    scriptureReference: String = "",
    showLyrics: Boolean = true,
    showScripture: Boolean = false,
    showTicker: Boolean = true
  ) {
    lyricsText = lyrics
    scriptureText = scripture
    this.scriptureReference = scriptureReference
    this.showLyrics = showLyrics
    this.showScripture = showScripture
    this.showTicker = showTicker
    tickerText = ticker
    logo = logoBitmap
    pastorRect = pastorFrame
    crowdRect = crowdFrame
    layout?.let(::updateLayout)
    overlayDirty = true
  }


  fun updateLayout(layout: String) {
    val full = RectF(0f, 0f, 1f, 1f)
    val pip = RectF(0.72f, 0.68f, 0.97f, 0.97f)
    when (layout) {
      "pastorOnly" -> {
        pastorVisible = true
        crowdVisible = false
        pastorRect = full
        crowdRect = pip
      }
      "crowdOnly" -> {
        pastorVisible = false
        crowdVisible = true
        pastorRect = pip
        crowdRect = full
      }
      "pastorInCrowd" -> {
        pastorVisible = true
        crowdVisible = true
        pastorRect = full
        crowdRect = pip
      }
      "crowdInPastor" -> {
        pastorVisible = true
        crowdVisible = true
        pastorRect = pip
        crowdRect = full
      }
    }
    overlayDirty = true
  }

  override fun drawFilter() {
    if (showTicker && tickerText.isNotBlank()) overlayDirty = true
    val pastor = frameHub.latestFrame("pastor")
    val crowd = frameHub.latestFrame("crowd")
    if (pastor !== uploadedPastor) {
      pastor?.let { uploadFrame(it, pastorTextures, 0) }
      uploadedPastor = pastor
    }
    if (crowd !== uploadedCrowd) {
      crowd?.let { uploadFrame(it, crowdTextures, 3) }
      uploadedCrowd = crowd
    }
    if (overlayDirty) uploadOverlay()

    GLES20.glUseProgram(program)
    vertexBuffer.position(0)
    GLES20.glVertexAttribPointer(positionHandle, 3, GLES20.GL_FLOAT, false, 20, vertexBuffer)
    GLES20.glEnableVertexAttribArray(positionHandle)
    vertexBuffer.position(3)
    GLES20.glVertexAttribPointer(textureCoordHandle, 2, GLES20.GL_FLOAT, false, 20, vertexBuffer)
    GLES20.glEnableVertexAttribArray(textureCoordHandle)

    bindTextureArray(pastorTextures, 0, pastorYHandle, pastorUHandle, pastorVHandle)
    bindTextureArray(crowdTextures, 3, crowdYHandle, crowdUHandle, crowdVHandle)
    GLES20.glActiveTexture(GLES20.GL_TEXTURE6)
    GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, overlayTexture[0])
    GLES20.glUniform1i(overlayHandle, 6)

    GLES20.glUniform4f(
      pastorRectHandle,
      pastorRect.left,
      1f - pastorRect.bottom,
      pastorRect.width(),
      pastorRect.height()
    )
    GLES20.glUniform4f(
      crowdRectHandle,
      crowdRect.left,
      1f - crowdRect.bottom,
      crowdRect.width(),
      crowdRect.height()
    )
    GLES20.glUniform1f(hasPastorHandle, if (pastor != null && pastorVisible) 1f else 0f)
    GLES20.glUniform1f(hasCrowdHandle, if (crowd != null && crowdVisible) 1f else 0f)
    GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)
  }

  override fun disableResources() {
    GlUtil.disableResources(textureCoordHandle, positionHandle)
  }

  override fun release() {
    if (program != 0) {
      GLES20.glDeleteProgram(program)
      program = 0
    }
    GLES20.glDeleteTextures(3, pastorTextures, 0)
    GLES20.glDeleteTextures(3, crowdTextures, 0)
    GLES20.glDeleteTextures(1, overlayTexture, 0)
    logo?.recycle()
    logo = null
  }

  private fun createLumaTextures(textures: IntArray) {
    GlUtil.createTextures(3, textures, 0)
    textures.forEach {
      GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, it)
      GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_LINEAR)
      GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_LINEAR)
      GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_S, GLES20.GL_CLAMP_TO_EDGE)
      GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_T, GLES20.GL_CLAMP_TO_EDGE)
    }
  }

  private fun uploadFrame(frame: I420Frame, textures: IntArray, textureIndex: Int) {
    uploadPlane(textures[0], frame.y, frame.width, frame.height, textureIndex)
    uploadPlane(
      textures[1],
      frame.u,
      (frame.width + 1) / 2,
      (frame.height + 1) / 2,
      textureIndex + 1
    )
    uploadPlane(
      textures[2],
      frame.v,
      (frame.width + 1) / 2,
      (frame.height + 1) / 2,
      textureIndex + 2
    )
  }

  private fun uploadPlane(texture: Int, plane: ByteArray, width: Int, height: Int, index: Int) {
    GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, texture)
    GLES20.glPixelStorei(GLES20.GL_UNPACK_ALIGNMENT, 1)
    val bytes = ByteBuffer.wrap(plane)
    if (textureWidths[index] != width || textureHeights[index] != height) {
      GLES20.glTexImage2D(
        GLES20.GL_TEXTURE_2D,
        0,
        GLES20.GL_LUMINANCE,
        width,
        height,
        0,
        GLES20.GL_LUMINANCE,
        GLES20.GL_UNSIGNED_BYTE,
        bytes
      )
      textureWidths[index] = width
      textureHeights[index] = height
    } else {
      GLES20.glTexSubImage2D(
        GLES20.GL_TEXTURE_2D,
        0,
        0,
        0,
        width,
        height,
        GLES20.GL_LUMINANCE,
        GLES20.GL_UNSIGNED_BYTE,
        bytes
      )
    }
  }

  private fun bindTextureArray(
    textures: IntArray,
    firstUnit: Int,
    yHandle: Int,
    uHandle: Int,
    vHandle: Int
  ) {
    GLES20.glActiveTexture(GLES20.GL_TEXTURE0 + firstUnit)
    GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, textures[0])
    GLES20.glUniform1i(yHandle, firstUnit)
    GLES20.glActiveTexture(GLES20.GL_TEXTURE0 + firstUnit + 1)
    GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, textures[1])
    GLES20.glUniform1i(uHandle, firstUnit + 1)
    GLES20.glActiveTexture(GLES20.GL_TEXTURE0 + firstUnit + 2)
    GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, textures[2])
    GLES20.glUniform1i(vHandle, firstUnit + 2)
  }

  private fun uploadOverlay() {
    val bitmap = Bitmap.createBitmap(OUTPUT_WIDTH, OUTPUT_HEIGHT, Bitmap.Config.ARGB_8888)
    val canvas = Canvas(bitmap)
    val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
      isSubpixelText = true
      typeface = android.graphics.Typeface.create("sans", android.graphics.Typeface.BOLD)
    }

    if (showScripture && scriptureText.isNotBlank()) {
      paint.color = Color.argb(215, 0, 0, 0)
      canvas.drawRoundRect(RectF(90f, 40f, 1190f, 185f), 18f, 18f, paint)
      paint.color = Color.WHITE
      paint.textSize = 34f
      paint.textAlign = Paint.Align.CENTER
      canvas.drawText(scriptureText.take(90), OUTPUT_WIDTH / 2f, 112f, paint)
      if (scriptureReference.isNotBlank()) {
        paint.color = Color.argb(225, 220, 230, 220)
        paint.textSize = 22f
        canvas.drawText(scriptureReference.take(60), OUTPUT_WIDTH / 2f, 155f, paint)
      }
    }

    if (showLyrics && lyricsText.isNotBlank()) {
      paint.color = Color.argb(235, 35, 145, 58)
      canvas.drawRect(0f, 525f, OUTPUT_WIDTH.toFloat(), 625f, paint)
      paint.color = Color.WHITE
      paint.textSize = 44f
      paint.textAlign = Paint.Align.CENTER
      canvas.drawText(lyricsText.take(72), OUTPUT_WIDTH / 2f, 588f, paint)
    }

    if (showTicker && tickerText.isNotBlank()) {
      paint.color = Color.argb(230, 13, 20, 34)
      canvas.drawRect(0f, 660f, OUTPUT_WIDTH.toFloat(), OUTPUT_HEIGHT.toFloat(), paint)
      paint.color = Color.WHITE
      paint.textSize = 28f
      paint.textAlign = Paint.Align.LEFT
      val cycle = paint.measureText(tickerText.take(140)) + 80f
      val offset = ((System.nanoTime() / 1_000_000_000.0 * 120.0) % cycle.toDouble()).toFloat()
      val x = OUTPUT_WIDTH - offset
      canvas.drawText(tickerText.take(140), x, 700f, paint)
      canvas.drawText(tickerText.take(140), x + cycle, 700f, paint)
    }

    logo?.let { source ->
      val maxWidth = 180f
      val maxHeight = 100f
      val scale = minOf(maxWidth / source.width, maxHeight / source.height)
      val width = source.width * scale
      val height = source.height * scale
      canvas.drawBitmap(
        source,
        null,
        RectF(28f, 24f, 28f + width, 24f + height),
        paint
      )
    }

    GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, overlayTexture[0])
    GLES20.glPixelStorei(GLES20.GL_UNPACK_ALIGNMENT, 4)
    GLUtils.texImage2D(GLES20.GL_TEXTURE_2D, 0, bitmap, 0)
    bitmap.recycle()
    overlayDirty = false
  }
}