package com.vidnexa.videoplayer

import android.content.Context
import android.os.Build
import android.provider.MediaStore
import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * Byte sizes for every image in MediaStore, in one query.
 *
 * The gallery's signature pass needs a size per photo. `photo_manager` 3.8.3
 * has no size API, so the only way to get one through the plugin was
 * `AssetEntity.file`, which on Android 10+ **copies the photo into the app's
 * cache directory** before it can be stat'ed (see `ScopedCache
 * .getCacheFileFromEntity`). Over a 5000-photo library that copied the whole
 * library — minutes of I/O and gigabytes of cache — to read a number MediaStore
 * already stores in a column.
 *
 * This reads that column instead. One cursor over `_ID` + `SIZE` for the whole
 * library costs a few milliseconds, and replaces 5000 round-trips with one.
 */
class MediaSizePlugin(
    private val context: Context,
    messenger: BinaryMessenger,
) {
    companion object {
        const val CHANNEL = "com.vidnexa.videoplayer/media_size"
        private const val TAG = "MediaSize"
    }

    private var channel: MethodChannel? = MethodChannel(messenger, CHANNEL).apply {
        setMethodCallHandler { call, result ->
            when (call.method) {
                "imageSizes" -> result.success(imageSizes())
                else -> result.notImplemented()
            }
        }
    }

    /**
     * MediaStore id (as a string, matching `AssetEntity.id`) -> size in bytes.
     *
     * Rows with a zero or missing size are dropped rather than reported as 0,
     * so a caller can tell "no size on record" from "an empty file". Never
     * throws: a failure here degrades a size filter, it must not take down a
     * scan.
     */
    private fun imageSizes(): Map<String, Long> {
        val sizes = HashMap<String, Long>()
        val collection = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL)
        } else {
            MediaStore.Images.Media.EXTERNAL_CONTENT_URI
        }

        try {
            context.contentResolver.query(
                collection,
                arrayOf(MediaStore.Images.Media._ID, MediaStore.Images.Media.SIZE),
                null,
                null,
                null,
            )?.use { cursor ->
                val idColumn = cursor.getColumnIndexOrThrow(MediaStore.Images.Media._ID)
                val sizeColumn = cursor.getColumnIndexOrThrow(MediaStore.Images.Media.SIZE)
                while (cursor.moveToNext()) {
                    val size = cursor.getLong(sizeColumn)
                    if (size <= 0L) continue
                    sizes[cursor.getLong(idColumn).toString()] = size
                }
            }
        } catch (error: Exception) {
            Log.w(TAG, "imageSizes query failed", error)
        }

        return sizes
    }

    fun dispose() {
        channel?.setMethodCallHandler(null)
        channel = null
    }
}
