package com.lumen.lumen_reader

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
  private val CHANNEL = "lumen_reader/open_file"
  private val UPDATE_CHANNEL = "lumen_reader/update"
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

    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, UPDATE_CHANNEL)
      .setMethodCallHandler { call, result ->
        when (call.method) {
          "installApk" -> {
            val args = call.arguments as? Map<*, *>
            val path = args?.get("path") as? String
            if (path.isNullOrBlank()) {
              result.error("INVALID_ARGS", "Parâmetro 'path' é obrigatório", null)
              return@setMethodCallHandler
            }

            val ok = installApk(path)
            if (ok) {
              result.success(true)
            } else {
              result.error("INSTALL_FAILED", "Não foi possível abrir o instalador do APK", null)
            }
          }
          else -> result.notImplemented()
        }
      }
  }

  private fun installApk(apkPath: String): Boolean {
    return try {
      val file = File(apkPath)
      if (!file.exists()) return false

      val uri = FileProvider.getUriForFile(
        this,
        applicationContext.packageName + ".fileprovider",
        file
      )

      val intent = Intent(Intent.ACTION_VIEW).apply {
        setDataAndType(uri, "application/vnd.android.package-archive")
        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
      }

      startActivity(intent)
      true
    } catch (e: ActivityNotFoundException) {
      false
    } catch (e: Exception) {
      false
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
