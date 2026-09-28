package com.vidnexa.videoplayer

import android.app.ActivityManager
import android.app.Application
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Process
import android.util.Log

/**
 * Application class, added for exactly one job: catch an install that has no
 * native libraries before [MainActivity] tries to build a Flutter engine out of
 * them and dies. See [NativeLibsGuard] for what that install looks like and why
 * it happens.
 *
 * Previously the manifest used Flutter's `${applicationName}` placeholder,
 * which resolves to plain `android.app.Application` under the v2 embedding —
 * verified in the built bundle's manifest before this class replaced it. So
 * this adds behaviour and takes none away.
 */
class VidnexaApplication : Application() {

    private companion object {
        const val TAG = "VidnexaApplication"
    }

    override fun onCreate() {
        super.onCreate()

        // [IncompleteInstallActivity] lives in its own process, and that
        // process constructs this class too. Without this check it would run
        // the guard, fail it, and launch itself again — forever.
        if (!isMainProcess()) return

        if (NativeLibsGuard.isInstallComplete(this)) return

        Log.e(TAG, "Native libraries are missing — showing the repair screen instead of starting")

        startActivity(
            Intent(this, IncompleteInstallActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)
            },
        )

        // Kill this process before the activity that is mid-launch reaches
        // FlutterActivity.onCreate and throws. Android does not auto-restart a
        // process that died during an activity launch, so this stops here
        // rather than looping; the dialog survives because it was handed to
        // the system already and comes up in :installguard.
        Process.killProcess(Process.myPid())
    }

    /**
     * Whether this is the process the app actually runs in.
     *
     * `getProcessName()` is only public API from P; below that the pid has to
     * be matched against the running-process list, which needs no permission
     * for the caller's own process.
     */
    private fun isMainProcess(): Boolean {
        val name = currentProcessName() ?: return true // unknown: behave as before
        return name == packageName
    }

    private fun currentProcessName(): String? {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            return getProcessName()
        }

        return try {
            val am = getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager
            val pid = Process.myPid()
            am?.runningAppProcesses?.firstOrNull { it.pid == pid }?.processName
        } catch (t: Throwable) {
            Log.w(TAG, "Could not determine the process name", t)
            null
        }
    }
}
