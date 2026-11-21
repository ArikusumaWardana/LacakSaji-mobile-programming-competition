package com.example.lacak_saji

import android.content.ClipData
import android.content.Intent
import android.content.pm.PackageManager
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    companion object {
        private const val WHATSAPP_CHANNEL = "com.example.lacak_saji/whatsapp"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            WHATSAPP_CHANNEL
        ).setMethodCallHandler { call, result ->
            if (call.method == "sendPdfToWhatsApp") {
                val filePath = call.argument<String>("filePath").orEmpty()
                val phoneDigits = call.argument<String>("phoneDigits").orEmpty()
                val caption = call.argument<String>("caption").orEmpty()
                result.success(sendPdfDirectlyToWhatsApp(filePath, phoneDigits, caption))
            } else {
                result.notImplemented()
            }
        }
    }

    private fun isPackageInstalled(pkg: String): Boolean {
        return try {
            packageManager.getPackageInfo(pkg, 0)
            true
        } catch (_: PackageManager.NameNotFoundException) {
            false
        }
    }

    private fun sendPdfDirectlyToWhatsApp(
        filePath: String,
        phoneDigits: String,
        caption: String
    ): String {
        val targetPackage = when {
            isPackageInstalled("com.whatsapp") -> "com.whatsapp"
            isPackageInstalled("com.whatsapp.w4b") -> "com.whatsapp.w4b"
            else -> return "not_installed"
        }

        val pdfFile = File(filePath)
        if (!pdfFile.exists()) {
            return "file_missing"
        }

        return try {
            val pdfUri = FileProvider.getUriForFile(
                this,
                "$packageName.klb_fileprovider",
                pdfFile
            )
            val intent = Intent(Intent.ACTION_SEND).apply {
                type = "application/pdf"
                `package` = targetPackage
                putExtra(Intent.EXTRA_STREAM, pdfUri)
                if (caption.isNotBlank()) {
                    putExtra(Intent.EXTRA_TEXT, caption)
                }
                if (phoneDigits.isNotBlank()) {
                    putExtra("jid", "$phoneDigits@s.whatsapp.net")
                }
                clipData = ClipData.newUri(contentResolver, "Berita Acara KLB", pdfUri)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            grantUriPermission(
                targetPackage,
                pdfUri,
                Intent.FLAG_GRANT_READ_URI_PERMISSION
            )
            startActivity(intent)
            "sent_whatsapp"
        } catch (_: Exception) {
            "failed"
        }
    }
}
