package com.lumen.lumen_reader

import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
  private val CHANNEL = "lumen_reader/open_file"
  private var pendingFilePath: String? = null

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)

    handleIntent(intent)

    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
      .setMethodCallHandler { call, result ->
        when (call.method) {
          "getInitialFile" -> {
            result.success(pendingFilePath)
            pendingFilePath = null
          }
          else -> result.notImplemented()
        }
      }
  }

  override fun onNewIntent(intent: Intent) {
    super.onNewIntent(intent)
    setIntent(intent)
    handleIntent(intent)

    val engine = flutterEngine
    if (engine != null && pendingFilePath != null) {
      MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
        .invokeMethod("onFileOpen", pendingFilePath)
      pendingFilePath = null
    }
  }

  private fun handleIntent(intent: Intent?) {
    if (intent == null) return
    if (Intent.ACTION_VIEW != intent.action) return

    val uri: Uri? = intent.data
    if (uri == null) return

    val resolved = resolveUriToReadablePath(uri)
    if (resolved != null) {
      pendingFilePath = resolved
    }
  }

  private fun resolveUriToReadablePath(uri: Uri): String? {
    return try {
      if (uri.scheme == "file") {
        return uri.path
      }

      val cr = applicationContext.contentResolver
      val input = cr.openInputStream(uri) ?: return null

      val name = (uri.lastPathSegment ?: "document")
      val ext = when {
        name.lowercase().endsWith(".pdf") -> ".pdf"
        name.lowercase().endsWith(".epub") -> ".epub"
        else -> {
          val type = cr.getType(uri) ?: ""
          when (type.lowercase()) {
            "application/pdf" -> ".pdf"
            "application/epub+zip" -> ".epub"
            else -> ""
          }
        }
      }

      val outFile = File(cacheDir, "open_${System.currentTimeMillis()}$ext")
      FileOutputStream(outFile).use { out ->
        input.use { inp ->
          inp.copyTo(out)
        }
      }

      outFile.absolutePath
    } catch (e: Exception) {
      null
    }
  }
}
