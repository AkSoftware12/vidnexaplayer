package com.vidnexa.videoplayer

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.provider.OpenableColumns
import android.util.Log
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

    /// The intent's declared mimeType (falls back to a ContentResolver lookup).
    /// Dart uses this to tell audio apart from video — "Open with" for a music
    /// file must land in the mini player on Home, not the full-screen player.
    private var openedMimeType: String? = null

    /// Best-effort display name for the notification / mini player title.
    private var openedDisplayName: String? = null

    /// Guards against replaying the same intent after a configuration change.
    private var consumed = false

    /// So [handleIntent] can push straight to Dart. `getVideoPath` alone only
    /// covers a TRUE cold start — Dart asks for it exactly once, from
    /// `MyApp.initState`. Two other cases need the proactive push instead:
    ///  - Warm start: app already foreground/backgrounded with its Activity
    ///    alive — Android delivers the new intent via `onNewIntent`, and
    ///    nothing would otherwise poll for it again.
    ///  - "Zombie" start: the user swiped the app away from Recents. That
    ///    only tears down the Activity/Task — `AudioServiceActivity` (via
    ///    `provideFlutterEngine`) keeps the Flutter engine and Dart isolate
    ///    alive in the background so audio playback can continue. A fresh
    ///    `MainActivity` then goes through `onCreate` (not `onNewIntent`),
    ///    but `MyApp.initState()` never runs again on that already-running
    ///    isolate, so polling alone would silently drop the video here too.
    /// Both are covered by always attempting the push, from both lifecycle
    /// callbacks. If Dart hasn't registered a handler yet (a genuine first
    /// cold boot, where this fires before `main()` has even started), the
    /// call is simply a safe no-op and `getVideoPath` polling covers it
    /// instead — `consumed` is deliberately NOT set here, only by
    /// `getVideoPath` itself, so that fallback always stays available.
    private var channel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent)
    }

    /// Openable content:// uris expose their real filename via
    /// OpenableColumns.DISPLAY_NAME; file:// uris just use the path segment.
    private fun queryDisplayName(uri: Uri): String? {
        if (uri.scheme == "file") return uri.lastPathSegment

        return try {
            contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
                ?.use { cursor ->
                    val idx = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                    if (idx >= 0 && cursor.moveToFirst()) cursor.getString(idx) else null
                }
        } catch (_: Exception) {
            null
        }
    }

    private fun handleIntent(intent: Intent?) {
        Log.d("VidnexaIntent", "handleIntent: action=${intent?.action} data=${intent?.data} type=${intent?.type}")
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
        openedMimeType = intent.type ?: contentResolver.getType(uri)
        openedDisplayName = queryDisplayName(uri)
        consumed = false

        channel?.invokeMethod(
            "newVideoIntent",
            mapOf(
                "uri" to openedVideoUri,
                "mimeType" to openedMimeType,
                "name" to openedDisplayName,
            ),
        )
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .apply {
                setMethodCallHandler { call, result ->
                    when (call.method) {
                        "getVideoPath" -> {
                            // Deliver once; a second call (e.g. after rotation) returns null
                            // so the player is not pushed onto the stack twice.
                            Log.d("VidnexaIntent", "getVideoPath called: consumed=$consumed openedVideoUri=$openedVideoUri")
                            if (consumed || openedVideoUri == null) {
                                result.success(null)
                            } else {
                                consumed = true
                                result.success(
                                    mapOf(
                                        "uri" to openedVideoUri,
                                        "mimeType" to openedMimeType,
                                        "name" to openedDisplayName,
                                    ),
                                )
                            }
                        }
                        else -> result.notImplemented()
                    }
                }
            }
    }
}