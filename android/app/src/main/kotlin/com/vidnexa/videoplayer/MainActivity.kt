package com.vidnexa.videoplayer

import android.content.Intent
import android.os.Bundle
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/// Extends [AudioServiceActivity] (not FlutterActivity) so that audio_service's
/// media session keeps working while this activity is the real launcher entry
/// point — that is what makes the "getVideoPath" MethodChannel reachable.
class MainActivity : AudioServiceActivity() {

    private companion object {
        const val CHANNEL = "open_video_channel"
    }

    /// Uri of the media the app was opened with, as a plain string.
    /// We hand the raw `content://` / `file://` uri to Dart — media_kit can open
    /// content uris directly, so there is no need to copy gigabytes into cache.
    private var openedVideoUri: String? = null

    /// Guards against replaying the same intent after a configuration change.
    private var consumed = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        if (intent?.action != Intent.ACTION_VIEW) return
        val uri = intent.data ?: return

        // Persist read access so the uri stays valid after the sending app dies.
        try {
            contentResolver.takePersistableUriPermission(
                uri,
                Intent.FLAG_GRANT_READ_URI_PERMISSION,
            )
        } catch (_: SecurityException) {
            // Not a persistable grant (plain file:// or one-shot share) — fine.
        }

        openedVideoUri = uri.toString()
        consumed = false
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getVideoPath" -> {
                        // Deliver once; a second call (e.g. after rotation) returns null
                        // so the player is not pushed onto the stack twice.
                        if (consumed) {
                            result.success(null)
                        } else {
                            consumed = true
                            result.success(openedVideoUri)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}