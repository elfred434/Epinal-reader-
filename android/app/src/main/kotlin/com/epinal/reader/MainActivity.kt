package com.epinal.reader

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
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.epinal.reader/native").setMethodCallHandler { call, result ->
            when (call.method) {
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
