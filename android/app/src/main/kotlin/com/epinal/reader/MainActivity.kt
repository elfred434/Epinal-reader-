package com.epinal.reader

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val exportRequest = 0x4E51
    private var exportResult: MethodChannel.Result? = null
    private var exportSource: File? = null

    private fun startExport(bookId: String?, fileName: String?, result: MethodChannel.Result) {
        if (exportResult != null) {
            result.error("busy", "Un export est déjà en cours", null)
            return
        }
        if (bookId == null || !Regex("^[a-f0-9-]{1,128}$").matches(bookId) || fileName.isNullOrBlank()) {
            result.error("invalid", "Livre invalide", null)
            return
        }
        val source = File(getDir("flutter", MODE_PRIVATE), "books/$bookId.epub")
        if (!source.isFile) {
            result.error("missing", "Livre introuvable", null)
            return
        }
        try {
            exportResult = result
            exportSource = source
            val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                addCategory(Intent.CATEGORY_OPENABLE)
                type = "application/epub+zip"
                putExtra(Intent.EXTRA_TITLE, fileName)
            }
            @Suppress("DEPRECATION")
            startActivityForResult(intent, exportRequest)
        } catch (e: Exception) {
            exportResult = null
            exportSource = null
            result.error("picker", "Impossible d’ouvrir le sélecteur de fichiers", null)
        }
    }

    @Deprecated("Android activity result callback")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode != exportRequest) {
            super.onActivityResult(requestCode, resultCode, data)
            return
        }
        val result = exportResult ?: return
        val source = exportSource
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null || source == null) {
            exportResult = null
            exportSource = null
            result.success(false)
            return
        }
        // Stream privately stored EPUB to the document provider without loading
        // the entire book into a platform-channel message or device memory.
        Thread {
            try {
                source.inputStream().use { input ->
                    val output = contentResolver.openOutputStream(uri, "w")
                        ?: throw java.io.IOException("Destination inaccessible")
                    output.use { input.copyTo(it); it.flush() }
                }
                runOnUiThread {
                    exportResult = null
                    exportSource = null
                    result.success(true)
                }
            } catch (e: Exception) {
                runOnUiThread {
                    exportResult = null
                    exportSource = null
                    result.error("write", "Écriture du fichier impossible", null)
                }
            }
        }.start()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.epinal.reader/native").setMethodCallHandler { call, result ->
            when (call.method) {
                "exportBook" -> startExport(call.argument<String>("bookId"), call.argument<String>("fileName"), result)
                "legacyBooks" -> {
                    val prefs = getSharedPreferences("epinal", MODE_PRIVATE)
                    result.success(mapOf("books" to (prefs.getString("books", "[]") ?: "[]"), "filesDir" to filesDir.absolutePath))
                }
                "installUpdate" -> {
                    try {
                        val apk = File(cacheDir, "updates/Epinal.apk")
                        if (!apk.isFile) { result.error("missing", "APK introuvable", null); return@setMethodCallHandler }
                        val info = packageManager.getPackageArchiveInfo(apk.absolutePath, 0)
                        if (info == null || info.packageName != packageName) { result.error("package", "Identifiant de l’APK incorrect", null); return@setMethodCallHandler }
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && !packageManager.canRequestPackageInstalls()) {
                            startActivity(Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:$packageName")))
                            result.success("permission")
                        } else {
                            val uri = FileProvider.getUriForFile(this, "$packageName.updates", apk)
                            startActivity(Intent(Intent.ACTION_VIEW).setDataAndType(uri, "application/vnd.android.package-archive").addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION))
                            result.success("installer")
                        }
                    } catch (e: Exception) { result.error("install", e.message, null) }
                }
                else -> result.notImplemented()
            }
        }
    }
}
