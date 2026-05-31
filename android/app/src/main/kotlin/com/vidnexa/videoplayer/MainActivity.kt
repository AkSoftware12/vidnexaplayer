package com.vidnexa.videoplayer

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.webkit.MimeTypeMap
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {

    private val CHANNEL = "open_video_channel"
    private var openedVideoPath: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        if (intent?.action == Intent.ACTION_VIEW) {
            val uri = intent.data
            openedVideoPath = uri?.let { copyUriToCache(it) }
        }
    }

    private fun copyUriToCache(uri: Uri): String? {
        return try {
            val inputStream = contentResolver.openInputStream(uri) ?: return null
            val ext = getExtension(uri)
            val outFile = File(cacheDir, "open_with_${System.currentTimeMillis()}.$ext")

            FileOutputStream(outFile).use { output ->
                inputStream.copyTo(output)
            }

            inputStream.close()
            outFile.absolutePath
        } catch (e: Exception) {
            null
        }
    }

    private fun getExtension(uri: Uri): String {
        return try {
            val mime = contentResolver.getType(uri)
            MimeTypeMap.getSingleton().getExtensionFromMimeType(mime) ?: "mp4"
        } catch (e: Exception) {
            "mp4"
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getVideoPath" -> result.success(openedVideoPath)
                    else -> result.notImplemented()
                }
            }
    }
}