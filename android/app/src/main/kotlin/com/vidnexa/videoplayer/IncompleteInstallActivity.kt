package com.vidnexa.videoplayer

import android.app.Activity
import android.app.AlertDialog
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Bundle

/**
 * The screen shown instead of a crash when the install has no native libraries.
 *
 * A plain [Activity], not a `FlutterActivity`: the whole point is that the
 * Flutter engine cannot start on this device, so anything that needs one is
 * unavailable. Everything here is framework UI and hardcoded resources.
 *
 * Runs in its own process (`:installguard`, set in the manifest) so that
 * [VidnexaApplication] can kill the main process — which is mid-launch and
 * about to crash — without taking this dialog down with it.
 */
class IncompleteInstallActivity : Activity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        AlertDialog.Builder(this)
            .setTitle(R.string.incomplete_install_title)
            .setMessage(R.string.incomplete_install_body)
            // Not cancellable, and back is consumed below: there is nothing
            // behind this dialog to go back to — the app cannot run.
            .setCancelable(false)
            .setPositiveButton(R.string.incomplete_install_open_play) { _, _ ->
                openPlayStoreListing()
                finish()
            }
            .setNegativeButton(R.string.incomplete_install_close) { _, _ -> finish() }
            .show()
    }

    override fun onBackPressed() {
        finish()
    }

    private fun openPlayStoreListing() {
        // market:// opens the Play app directly; the https:// form is the
        // fallback for a device with no Play app (which is itself a likely way
        // to end up with a sideloaded base apk in the first place).
        val market = Intent(Intent.ACTION_VIEW, Uri.parse("market://details?id=$packageName"))
        try {
            startActivity(market)
            return
        } catch (_: ActivityNotFoundException) {
            // Fall through to the browser.
        }

        try {
            startActivity(
                Intent(
                    Intent.ACTION_VIEW,
                    Uri.parse("https://play.google.com/store/apps/details?id=$packageName"),
                ),
            )
        } catch (_: ActivityNotFoundException) {
            // No browser either. Nothing further to offer.
        }
    }
}
