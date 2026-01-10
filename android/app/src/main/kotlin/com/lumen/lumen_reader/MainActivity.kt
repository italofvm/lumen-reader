package com.lumen.lumen_reader

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.PackageManager
import android.content.ContentResolver
import android.os.Build
import android.net.Uri
import android.provider.Settings
import androidx.core.content.FileProvider
import androidx.documentfile.provider.DocumentFile
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
  private val CHANNEL = "lumen_reader/open_file"
  private val UPDATE_CHANNEL = "lumen_reader/update"
  private val SAF_CHANNEL = "lumen_reader/saf"
  private var pendingFilePath: String? = null
  private var pendingApkPathForInstall: String? = null

  private val REQ_OPEN_TREE = 7001
  private var pendingSafResult: MethodChannel.Result? = null
  private var pendingSafMode: String? = null

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

    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SAF_CHANNEL)
      .setMethodCallHandler { call, result ->
        when (call.method) {
          "pickDirectoryUri" -> {
            if (pendingSafResult != null) {
              result.error("BUSY", "Já existe uma seleção de pasta em andamento", null)
              return@setMethodCallHandler
            }

            pendingSafResult = result
            pendingSafMode = "uri"
            try {
              val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
                addFlags(Intent.FLAG_GRANT_PREFIX_URI_PERMISSION)
              }
              startActivityForResult(intent, REQ_OPEN_TREE)
            } catch (e: Exception) {
              pendingSafResult = null
              pendingSafMode = null
              result.error("SAF_FAILED", "Não foi possível abrir o seletor de pastas", e.toString())
            }
          }
          "pickDirectoryAndListBooks" -> {
            if (pendingSafResult != null) {
              result.error("BUSY", "Já existe uma seleção de pasta em andamento", null)
              return@setMethodCallHandler
            }

            pendingSafResult = result
            pendingSafMode = "list"
            try {
              val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
                addFlags(Intent.FLAG_GRANT_PREFIX_URI_PERMISSION)
              }
              startActivityForResult(intent, REQ_OPEN_TREE)
            } catch (e: Exception) {
              pendingSafResult = null
              pendingSafMode = null
              result.error("SAF_FAILED", "Não foi possível abrir o seletor de pastas", e.toString())
            }
          }
          "listBooksFromDirectoryUri" -> {
            val args = call.arguments as? Map<*, *>
            val uriStr = args?.get("uri") as? String
            if (uriStr.isNullOrBlank()) {
              result.error("INVALID_ARGS", "Parâmetro 'uri' é obrigatório", null)
              return@setMethodCallHandler
            }

            try {
              val treeUri = Uri.parse(uriStr)
              val list = scanTreeAndCopyToCache(contentResolver, treeUri)
              result.success(list)
            } catch (e: Exception) {
              result.error("SCAN_FAILED", "Erro ao ler a pasta configurada", e.toString())
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

      // Android 8+ requires explicit permission to install from unknown sources.
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
        val canInstall = packageManager.canRequestPackageInstalls()
        if (!canInstall) {
          pendingApkPathForInstall = apkPath
          val intent = Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES).apply {
            data = Uri.parse("package:" + packageName)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
          }
          startActivity(intent)
          return true
        }
      }

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

  override fun onResume() {
    super.onResume()
    val pending = pendingApkPathForInstall
    if (pending != null) {
      pendingApkPathForInstall = null
      // Try again after user returns from permission screen.
      try {
        installApk(pending)
      } catch (_: Exception) {
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

  override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
    super.onActivityResult(requestCode, resultCode, data)

    if (requestCode != REQ_OPEN_TREE) return

    val result = pendingSafResult
    val mode = pendingSafMode
    pendingSafResult = null
    pendingSafMode = null
    if (result == null) return

    if (resultCode != Activity.RESULT_OK) {
      result.success(null)
      return
    }

    val treeUri = data?.data
    if (treeUri == null) {
      result.success(if (mode == "uri") null else emptyList<Map<String, String>>())
      return
    }

    try {
      // Persist permission so scanning works even after process death (best-effort).
      val takeFlags = (data.flags and (Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION))
      try {
        contentResolver.takePersistableUriPermission(treeUri, takeFlags)
      } catch (_: SecurityException) {
        // Ignore; some devices/providers don't allow persist.
      }

      if (mode == "uri") {
        result.success(treeUri.toString())
        return
      }

      val list = scanTreeAndCopyToCache(contentResolver, treeUri)
      result.success(list)
    } catch (e: Exception) {
      result.error("SCAN_FAILED", "Erro ao ler a pasta selecionada", e.toString())
    }
  }

  private fun scanTreeAndCopyToCache(
    cr: ContentResolver,
    treeUri: Uri,
  ): List<Map<String, String>> {
    val root = DocumentFile.fromTreeUri(this, treeUri) ?: return emptyList()
    val allowed = setOf("pdf", "epub", "mobi", "fb2", "txt", "azw3")
    val out = mutableListOf<Map<String, String>>()

    fun walk(dir: DocumentFile) {
      val children = dir.listFiles()
      for (child in children) {
        if (child.isDirectory) {
          walk(child)
          continue
        }
        val name = child.name ?: continue
        val ext = name.substringAfterLast('.', "").lowercase()
        if (!allowed.contains(ext)) continue

        val cached = copyDocumentToCache(cr, child.uri, name)
        if (cached != null) {
          out.add(mapOf("path" to cached.absolutePath, "name" to name))
        }
      }
    }

    walk(root)
    return out
  }

  private fun copyDocumentToCache(
    cr: ContentResolver,
    uri: Uri,
    originalName: String,
  ): File? {
    return try {
      val ext = originalName.substringAfterLast('.', "").lowercase()
      val safeBase = originalName
        .substringBeforeLast('.', originalName)
        .replace(Regex("[^a-zA-Z0-9._-]"), "_")
      val outFile = File(cacheDir, "import_${System.currentTimeMillis()}_${safeBase}.${ext}")

      val input = cr.openInputStream(uri) ?: return null
      FileOutputStream(outFile).use { out ->
        input.use { inp ->
          inp.copyTo(out)
        }
      }
      outFile
    } catch (_: Exception) {
      null
    }
  }
}
