package com.vidnexa.videoplayer

import android.content.Context
import android.content.pm.ApplicationInfo
import android.util.Log
import java.util.zip.ZipFile

/**
 * Answers one question at startup: does this installation actually carry the
 * Flutter engine?
 *
 * ## The crash this exists for
 *
 * ```
 * java.lang.RuntimeException: Could not find 'libflutter.so'.
 *   Looked for: [arm64-v8a, armeabi-v7a, armeabi], but only found: []
 *   at com.getkeepsafe.relinker.ApkLibraryInstaller.installLibrary
 *   at io.flutter.embedding.engine.FlutterJNI.loadLibrary
 *   at ...MainActivity.onCreate
 * ```
 *
 * "only found: []" is the important half. ReLinker walks the installed apk
 * files looking for `lib/<abi>/` directories and found **none at all** — not a
 * wrong ABI, not a corrupt library, simply no native libraries anywhere in the
 * install.
 *
 * That is not something the build can cause, and it was verified not to be:
 * both `app-release.apk` and `app-release.aab` carry
 * `lib/{arm64-v8a,armeabi-v7a,x86_64}/libflutter.so`. It is what a **partial
 * install** looks like. The app ships as an Android App Bundle, so Play splits
 * the native libraries into a per-ABI `split_config.*.apk`; an install that has
 * the base apk and not that split has no engine and cannot start. The usual
 * ways to end up there are a base apk pulled off an apk-sharing site, a copy
 * passed between phones, or a Play install that ran out of space partway.
 *
 * `android:isSplitRequired`, which makes Android refuse a base-only install, is
 * only honoured from API 29 — and the reports come from Android 8.1, where
 * nothing stops it.
 *
 * Nothing here repairs such an install; the bytes are genuinely absent. What it
 * does is turn an unexplained crash-on-launch into a screen that says what is
 * wrong and offers the one action that fixes it.
 */
internal object NativeLibsGuard {

    private const val TAG = "NativeLibsGuard"
    private const val ENGINE = "libflutter.so"

    /**
     * `true` when the engine is loadable (or at least present and worth
     * letting Flutter try), `false` only when this install demonstrably has no
     * native libraries at all.
     *
     * Deliberately biased towards returning `true`: a false positive here
     * blocks a working app, which is far worse than the crash being guarded
     * against.
     */
    fun isInstallComplete(context: Context): Boolean {
        // Fast path, and the common one. Costs a few milliseconds on a healthy
        // install and is work Flutter is about to do anyway — ReLinker's own
        // first step is this same call.
        try {
            System.loadLibrary("flutter")
            return true
        } catch (_: UnsatisfiedLinkError) {
            // Not conclusive on its own. A library that is present but which
            // the system loader misses is exactly the case ReLinker exists to
            // recover from, by unpacking it out of the apk. Only the scan
            // below can tell the two apart.
        } catch (t: Throwable) {
            Log.w(TAG, "Unexpected error probing $ENGINE — letting startup continue", t)
            return true
        }

        val abis = enginesInApks(context.applicationInfo)
        if (abis.isEmpty()) {
            Log.e(TAG, "No $ENGINE in any installed apk — install is incomplete")
            return false
        }

        Log.w(TAG, "$ENGINE did not load but is present for $abis — leaving it to ReLinker")
        return true
    }

    /** ABIs that actually ship an engine, across the base apk and every split. */
    private fun enginesInApks(info: ApplicationInfo): Set<String> {
        val found = linkedSetOf<String>()

        for (path in apkPaths(info)) {
            try {
                ZipFile(path).use { zip ->
                    val entries = zip.entries()
                    while (entries.hasMoreElements()) {
                        val name = entries.nextElement().name
                        if (name.startsWith("lib/") && name.endsWith("/$ENGINE")) {
                            found.add(name.substring(4, name.length - ENGINE.length - 1))
                        }
                    }
                }
            } catch (t: Throwable) {
                // An unreadable apk is not evidence either way; skip it rather
                // than let one failure condemn the whole install.
                Log.w(TAG, "Could not read $path", t)
            }
        }
        return found
    }

    /**
     * The base apk **and** its splits.
     *
     * ReLinker looks at `splitSourceDirs` alone whenever it is non-empty, which
     * is why its message can read "found: []" on an install whose base apk does
     * carry libraries. Checking both is what makes this guard trustworthy
     * enough to shut the app down on.
     */
    private fun apkPaths(info: ApplicationInfo): List<String> {
        val paths = mutableListOf<String>()
        info.sourceDir?.let(paths::add)
        info.splitSourceDirs?.let(paths::addAll)
        return paths
    }
}
