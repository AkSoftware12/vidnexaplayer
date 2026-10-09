package com.vidnexa.videoplayer

import android.app.Activity
import android.app.PictureInPictureParams
import android.os.Build
import android.util.Rational
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/// System picture-in-picture for the floating video player.
///
/// The floating player is a Flutter overlay, so it disappears the moment the
/// app leaves the foreground. While Dart says it is showing (`setEnabled`),
/// leaving the app moves the whole activity into Android's PiP window instead,
/// and Dart renders just the video there (`pipChanged`).
///
/// A hand-written bridge rather than a plugin: there is no official Flutter
/// PiP plugin, and entering PiP has to hook this app's own activity
/// (`onUserLeaveHint`), which [MainActivity] forwards here.
class PipController(
    private val activity: Activity,
    messenger: BinaryMessenger,
) {
    private companion object {
        const val CHANNEL = "com.vidnexa.videoplayer/pip"
    }

    private val channel = MethodChannel(messenger, CHANNEL)
    private var enabled = false
    private var aspect = Rational(16, 9)

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "setEnabled" -> {
                    enabled = call.argument<Boolean>("enabled") ?: false
                    val w = call.argument<Int>("width") ?: 16
                    val h = call.argument<Int>("height") ?: 9
                    aspect = clampAspect(w, h)
                    applyParams()
                    result.success(isSupported())
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun isSupported(): Boolean =
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            activity.packageManager.hasSystemFeature(
                android.content.pm.PackageManager.FEATURE_PICTURE_IN_PICTURE,
            )

    /// Android rejects ratios outside 1:2.39 – 2.39:1 with an exception.
    private fun clampAspect(w: Int, h: Int): Rational {
        if (w <= 0 || h <= 0) return Rational(16, 9)
        val r = w.toDouble() / h
        return when {
            r > 2.39 -> Rational(239, 100)
            r < 1 / 2.39 -> Rational(100, 239)
            else -> Rational(w, h)
        }
    }

    private fun buildParams(): PictureInPictureParams? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return null
        val builder = PictureInPictureParams.Builder().setAspectRatio(aspect)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            // Android 12+: enters PiP straight from the home gesture, with the
            // system animation, instead of waiting for onUserLeaveHint.
            builder.setAutoEnterEnabled(enabled)
            builder.setSeamlessResizeEnabled(true)
        }
        return builder.build()
    }

    private fun applyParams() {
        if (!isSupported()) return
        try {
            buildParams()?.let { activity.setPictureInPictureParams(it) }
        } catch (_: Exception) {
            // Some OEM builds throw for PiP on low-RAM devices; stay in-app.
        }
    }

    /// From [MainActivity.onUserLeaveHint]: the user pressed Home / switched
    /// apps. Android 12+ already auto-enters via the params above.
    fun onUserLeaveHint() {
        if (!enabled || !isSupported()) return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) return
        try {
            buildParams()?.let { activity.enterPictureInPictureMode(it) }
        } catch (_: Exception) {
            // Not allowed right now (e.g. a dialog on top); nothing to do.
        }
    }

    /// Set on entering PiP, cleared when the activity resumes. Tells the two
    /// ways out of PiP apart: expanding it resumes the activity, closing it
    /// (its ✕ or a swipe away) stops the activity instead.
    private var wasInPip = false

    fun onPictureInPictureModeChanged(inPip: Boolean) {
        if (inPip) wasInPip = true
        channel.invokeMethod("pipChanged", inPip)
    }

    /// From [MainActivity.onResume]: back in the app, so not a dismissal.
    fun onResume() {
        wasInPip = false
    }

    /// From [MainActivity.onStop]: stopping straight out of PiP means the
    /// user closed the window, so Dart pauses the video.
    fun onStop() {
        if (!wasInPip) return
        wasInPip = false
        channel.invokeMethod("pipDismissed", null)
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
    }
}
