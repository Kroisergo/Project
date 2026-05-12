package com.example.encryvault

import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.pdf.PdfRenderer
import android.os.ParcelFileDescriptor
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import kotlin.math.roundToInt

class MainActivity : FlutterActivity() {
  private val screenProtectionChannel = "encryvault/screen_protection"
  private val pdfPreviewChannel = "encryvault/pdf_preview"

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, screenProtectionChannel)
      .setMethodCallHandler { call, result ->
        when (call.method) {
          "enableProtection" -> {
            runOnUiThread {
              window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
            }
            result.success(null)
          }

          "disableProtection" -> {
            runOnUiThread {
              window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
            }
            result.success(null)
          }

          else -> result.notImplemented()
        }
      }

    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, pdfPreviewChannel)
      .setMethodCallHandler { call, result ->
        when (call.method) {
          "renderPdf" -> {
            val bytes = call.argument<ByteArray>("bytes")
            val filePath = call.argument<String>("filePath")
            val deleteAfterRender = call.argument<Boolean>("deleteAfterRender") ?: false
            val maxPages = call.argument<Int>("maxPages") ?: 12
            val targetWidth = call.argument<Int>("targetWidth") ?: 1200
            if ((bytes == null || bytes.isEmpty()) && filePath.isNullOrBlank()) {
              result.error("invalid_pdf", "PDF vazio.", null)
              return@setMethodCallHandler
            }
            Thread {
              try {
                val pages = if (!filePath.isNullOrBlank()) {
                  renderPdfFile(File(filePath), maxPages, targetWidth)
                } else {
                  renderPdfBytes(bytes!!, maxPages, targetWidth)
                }
                runOnUiThread { result.success(pages) }
              } catch (error: Throwable) {
                runOnUiThread {
                  result.error(
                    "pdf_preview_failed",
                    error.message ?: "Não foi possível pré-visualizar o PDF.",
                    null,
                  )
                }
              } finally {
                if (deleteAfterRender && !filePath.isNullOrBlank()) {
                  File(filePath).delete()
                }
              }
            }.start()
          }

          else -> result.notImplemented()
        }
      }
  }

  private fun renderPdfBytes(
    bytes: ByteArray,
    maxPages: Int,
    targetWidth: Int,
  ): List<ByteArray> {
    val temp = File.createTempFile("encryvault-preview-", ".pdf", cacheDir)
    try {
      temp.writeBytes(bytes)
      return renderPdfFile(temp, maxPages, targetWidth)
    } finally {
      temp.delete()
    }
  }

  private fun renderPdfFile(
    file: File,
    maxPages: Int,
    targetWidth: Int,
  ): List<ByteArray> {
    val descriptor = ParcelFileDescriptor.open(
      file,
      ParcelFileDescriptor.MODE_READ_ONLY,
    )
    try {
      val renderer = PdfRenderer(descriptor)
      try {
        val pageCount = minOf(renderer.pageCount, maxPages.coerceIn(1, 24))
        val output = ArrayList<ByteArray>(pageCount)
        for (index in 0 until pageCount) {
          val page = renderer.openPage(index)
          try {
            val width = targetWidth.coerceIn(320, 1800)
            val height = ((width.toFloat() / page.width) * page.height)
              .roundToInt()
              .coerceAtLeast(1)
            val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
            try {
              bitmap.eraseColor(Color.WHITE)
              page.render(bitmap, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
              val stream = ByteArrayOutputStream()
              bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
              output.add(stream.toByteArray())
            } finally {
              bitmap.recycle()
            }
          } finally {
            page.close()
          }
        }
        return output
      } finally {
        renderer.close()
      }
    } finally {
      descriptor.close()
    }
  }
}
