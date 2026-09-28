package com.vidnexa.videoplayer

import android.content.ContentResolver
import android.content.ContentUris
import android.content.Context
import android.database.Cursor
import android.os.Build
import android.os.Bundle
import android.provider.MediaStore
import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * Reads the device's file index straight out of MediaStore.
 *
 * ## Why this replaced the folder picker
 *
 * The file browser used to be built on the Storage Access Framework: the user
 * picked a folder, and everything — browsing, categories, the analyzer — ran
 * inside that grant. It worked, but it cost a folder pick before anything could
 * be shown, and every directory listed was a separate binder round trip, so a
 * "what is in this tree" question took seconds and had to be capped.
 *
 * MediaStore already holds that index, maintained by the system. One cursor
 * answers the same questions over the whole device in milliseconds, with no
 * picker and no `MANAGE_EXTERNAL_STORAGE` — the `READ_MEDIA_*` permissions the
 * app already declares are enough.
 *
 * What that buys, and what it costs, is in [query]'s notes.
 */
class MediaStorePlugin(
    private val context: Context,
    messenger: BinaryMessenger,
) {
    companion object {
        const val CHANNEL = "com.vidnexa.videoplayer/media_store"
        private const val TAG = "MediaStore"

        /**
         * Extensions per category.
         *
         * Matched on the display name rather than the MIME column on purpose:
         * a large share of real files on a phone are indexed as
         * `application/octet-stream` (anything a downloader wrote without
         * sniffing the content), and for those the extension is the only usable
         * signal. Verified on-device — the WhatsApp document folder is full of
         * exactly that.
         */
        private val DOCUMENT_EXT = listOf(
            "pdf", "doc", "docx", "odt", "rtf", "txt", "md", "log",
            "xls", "xlsx", "csv", "ods", "ppt", "pptx", "odp", "epub",
        )
        private val ARCHIVE_EXT = listOf("zip", "rar", "7z", "tar", "gz")
        private val APK_EXT = listOf("apk", "apks", "xapk")
    }

    private var channel: MethodChannel? = MethodChannel(messenger, CHANNEL).apply {
        setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "query" -> result.success(
                        query(
                            kind = call.argument<String>("kind") ?: "all",
                            limit = call.argument<Int>("limit") ?: 0,
                        ),
                    )

                    "folders" -> result.success(folders())

                    "hashes" -> result.success(
                        hashes(call.argument<List<String>>("uris") ?: emptyList()),
                    )

                    "open" -> result.success(
                        openExternally(
                            uri = call.argument<String>("uri"),
                            mime = call.argument<String>("mime"),
                        ),
                    )

                    "thumbnail" -> result.success(
                        thumbnail(
                            uri = call.argument<String>("uri"),
                            size = call.argument<Int>("size") ?: 256,
                        ),
                    )

                    else -> result.notImplemented()
                }
            } catch (t: Throwable) {
                Log.e(TAG, "${call.method} failed", t)
                result.error("mediastore_failed", t.message, null)
            }
        }
    }

    /**
     * Rows for [kind], newest first.
     *
     * ### What is visible
     *
     * Images, video and audio come back for the whole device, because the
     * `READ_MEDIA_*` permissions cover other apps' media.
     *
     * Non-media — documents, archives, apks — is the interesting case. Scoped
     * storage does **not** hand an app other apps' non-media files, so what
     * comes back here is what this app may legitimately read. That is less than
     * a root-explorer would show and is the deliberate trade for not asking for
     * All-files access, which Play reviews separately and routinely refuses to
     * media players.
     *
     * [limit] of 0 means no limit.
     */
    private fun query(kind: String, limit: Int): List<Map<String, Any?>> {
        val uri = MediaStore.Files.getContentUri(MediaStore.VOLUME_EXTERNAL)

        val projection = arrayOf(
            MediaStore.Files.FileColumns._ID,
            MediaStore.Files.FileColumns.DISPLAY_NAME,
            MediaStore.Files.FileColumns.SIZE,
            MediaStore.Files.FileColumns.DATE_MODIFIED,
            MediaStore.Files.FileColumns.MIME_TYPE,
            MediaStore.Files.FileColumns.RELATIVE_PATH,
            MediaStore.Files.FileColumns.MEDIA_TYPE,
        )

        val (selection, args) = selectionFor(kind)
        val rows = ArrayList<Map<String, Any?>>(if (limit > 0) limit else 256)

        runQuery(uri, projection, selection, args, limit)?.use { c ->
            val idCol = c.getColumnIndexOrThrow(MediaStore.Files.FileColumns._ID)
            val nameCol = c.getColumnIndexOrThrow(MediaStore.Files.FileColumns.DISPLAY_NAME)
            val sizeCol = c.getColumnIndexOrThrow(MediaStore.Files.FileColumns.SIZE)
            val dateCol = c.getColumnIndexOrThrow(MediaStore.Files.FileColumns.DATE_MODIFIED)
            val mimeCol = c.getColumnIndexOrThrow(MediaStore.Files.FileColumns.MIME_TYPE)
            val pathCol = c.getColumnIndexOrThrow(MediaStore.Files.FileColumns.RELATIVE_PATH)
            val typeCol = c.getColumnIndexOrThrow(MediaStore.Files.FileColumns.MEDIA_TYPE)

            while (c.moveToNext()) {
                val name = c.getString(nameCol) ?: continue
                val id = c.getLong(idCol)

                rows.add(
                    mapOf(
                        "id" to id,
                        "name" to name,
                        "size" to c.getLong(sizeCol),
                        // Seconds in the column, milliseconds everywhere in Dart.
                        "modified" to c.getLong(dateCol) * 1000L,
                        "mime" to c.getString(mimeCol),
                        "path" to (c.getString(pathCol) ?: ""),
                        "mediaType" to c.getInt(typeCol),
                        "uri" to ContentUris.withAppendedId(uri, id).toString(),
                    ),
                )
            }
        }

        return rows
    }

    /**
     * Every folder that holds at least one visible file, with its file count
     * and total bytes.
     *
     * Aggregated here rather than in Dart so a device with 20 000 indexed files
     * sends back a few hundred folder rows instead of all 20 000 — the whole
     * point of the rewrite was that the folder screen opens immediately.
     */
    private fun folders(): List<Map<String, Any?>> {
        val uri = MediaStore.Files.getContentUri(MediaStore.VOLUME_EXTERNAL)
        val projection = arrayOf(
            MediaStore.Files.FileColumns.RELATIVE_PATH,
            MediaStore.Files.FileColumns.SIZE,
            MediaStore.Files.FileColumns.DATE_MODIFIED,
        )

        class Bucket {
            var count = 0
            var bytes = 0L
            var newest = 0L
        }

        val buckets = HashMap<String, Bucket>()

        runQuery(uri, projection, "${MediaStore.Files.FileColumns.SIZE} > 0", null, 0)?.use { c ->
            val pathCol = c.getColumnIndexOrThrow(MediaStore.Files.FileColumns.RELATIVE_PATH)
            val sizeCol = c.getColumnIndexOrThrow(MediaStore.Files.FileColumns.SIZE)
            val dateCol = c.getColumnIndexOrThrow(MediaStore.Files.FileColumns.DATE_MODIFIED)

            while (c.moveToNext()) {
                val path = c.getString(pathCol) ?: continue
                if (path.isEmpty()) continue

                val bucket = buckets.getOrPut(path) { Bucket() }
                bucket.count++
                bucket.bytes += c.getLong(sizeCol)
                val modified = c.getLong(dateCol) * 1000L
                if (modified > bucket.newest) bucket.newest = modified
            }
        }

        return buckets.entries
            .sortedByDescending { it.value.bytes }
            .map { (path, bucket) ->
                mapOf(
                    "path" to path,
                    "count" to bucket.count,
                    "bytes" to bucket.bytes,
                    "modified" to bucket.newest,
                )
            }
    }

    /**
     * MD5 per uri, for the duplicate finder. Uris that cannot be read are
     * simply absent from the result.
     *
     * Streamed in 64 KB blocks rather than read whole. The Dart side could do
     * this too, but only by pulling every candidate file across the method
     * channel into the heap first — on a set of 4K videos that is the
     * out-of-memory kill, and it would copy gigabytes to compute 16 bytes.
     *
     * MD5 and not SHA-256 because this compares files that already have
     * identical sizes; the threat model is accidental duplicates, not an
     * adversary constructing a collision.
     */
    private fun hashes(uris: List<String>): Map<String, String> {
        val out = HashMap<String, String>(uris.size)
        val buffer = ByteArray(64 * 1024)

        for (uri in uris) {
            try {
                val digest = java.security.MessageDigest.getInstance("MD5")
                context.contentResolver.openInputStream(android.net.Uri.parse(uri))
                    ?.use { stream ->
                        while (true) {
                            val read = stream.read(buffer)
                            if (read <= 0) break
                            digest.update(buffer, 0, read)
                        }
                    } ?: continue

                out[uri] = digest.digest().joinToString("") { "%02x".format(it) }
            } catch (t: Throwable) {
                Log.w(TAG, "Could not hash $uri", t)
            }
        }
        return out
    }

    /**
     * Hands a file to whichever installed app claims its type.
     *
     * The uri is a `content://` one from MediaStore, so the read grant has to
     * travel with the intent — the receiving app has no permission of its own
     * to the user's storage. Returns false rather than throwing when nothing on
     * the device can open the type, which is a normal outcome for, say, a `.db`
     * backup.
     */
    private fun openExternally(uri: String?, mime: String?): Boolean {
        if (uri.isNullOrEmpty()) return false

        val parsed = android.net.Uri.parse(uri)
        val type = if (mime.isNullOrEmpty()) {
            context.contentResolver.getType(parsed) ?: "*/*"
        } else {
            mime
        }

        val intent = android.content.Intent(android.content.Intent.ACTION_VIEW).apply {
            setDataAndType(parsed, type)
            addFlags(android.content.Intent.FLAG_GRANT_READ_URI_PERMISSION)
            // Started from an application context, which has no task of its own.
            addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
        }

        return try {
            context.startActivity(intent)
            true
        } catch (t: Throwable) {
            Log.w(TAG, "Nothing could open $type", t)
            false
        }
    }

    /**
     * A square JPEG preview for one item, or null when there isn't one.
     *
     * `loadThumbnail` is the only API that reads the thumbnail the system
     * already generated instead of decoding the full image or seeking the
     * video — the difference between a grid that scrolls and one that stutters.
     * It arrived in API 29; below that this returns null and the UI falls back
     * to the file-type icon rather than paying to decode originals.
     */
    private fun thumbnail(uri: String?, size: Int): ByteArray? {
        if (uri.isNullOrEmpty()) return null
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return null

        return try {
            val bitmap = context.contentResolver.loadThumbnail(
                android.net.Uri.parse(uri),
                android.util.Size(size, size),
                null,
            )
            java.io.ByteArrayOutputStream().use { out ->
                bitmap.compress(android.graphics.Bitmap.CompressFormat.JPEG, 80, out)
                bitmap.recycle()
                out.toByteArray()
            }
        } catch (t: Throwable) {
            // Perfectly normal: a document has no thumbnail, and a file can go
            // away between the listing and the scroll that reaches it.
            null
        }
    }

    private fun selectionFor(kind: String): Pair<String?, Array<String>?> {
        val typeCol = MediaStore.Files.FileColumns.MEDIA_TYPE
        val nameCol = MediaStore.Files.FileColumns.DISPLAY_NAME
        val sizeGuard = "${MediaStore.Files.FileColumns.SIZE} > 0"

        fun byExtension(extensions: List<String>): Pair<String, Array<String>> {
            val clause = extensions.joinToString(" OR ") { "$nameCol LIKE ?" }
            return "$sizeGuard AND ($clause)" to extensions.map { "%.$it" }.toTypedArray()
        }

        return when (kind) {
            "video" -> "$typeCol = ${MediaStore.Files.FileColumns.MEDIA_TYPE_VIDEO}" to null
            "image" -> "$typeCol = ${MediaStore.Files.FileColumns.MEDIA_TYPE_IMAGE}" to null
            "audio" -> "$typeCol = ${MediaStore.Files.FileColumns.MEDIA_TYPE_AUDIO}" to null
            "document" -> byExtension(DOCUMENT_EXT)
            "archive" -> byExtension(ARCHIVE_EXT)
            "apk" -> byExtension(APK_EXT)
            "download" ->
                "$sizeGuard AND ${MediaStore.Files.FileColumns.RELATIVE_PATH} LIKE ?" to
                    arrayOf("Download%")
            // "all" and anything unrecognised: every indexed file with content.
            else -> sizeGuard to null
        }
    }

    /**
     * `LIMIT` has to be applied two different ways.
     *
     * From API 30 the resolver takes it as a query argument, which is what
     * actually stops SQLite materialising the rest of the rows. Below that the
     * only route is appending it to the sort order — an old trick that works on
     * the framework provider but is not contractual, so a failure there falls
     * back to an unlimited query rather than returning nothing.
     */
    private fun runQuery(
        uri: android.net.Uri,
        projection: Array<String>,
        selection: String?,
        args: Array<String>?,
        limit: Int,
    ): Cursor? {
        val resolver: ContentResolver = context.contentResolver
        val dateDesc = "${MediaStore.Files.FileColumns.DATE_MODIFIED} DESC"

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val extras = Bundle().apply {
                selection?.let { putString(ContentResolver.QUERY_ARG_SQL_SELECTION, it) }
                args?.let { putStringArray(ContentResolver.QUERY_ARG_SQL_SELECTION_ARGS, it) }
                putString(ContentResolver.QUERY_ARG_SQL_SORT_ORDER, dateDesc)
                if (limit > 0) putInt(ContentResolver.QUERY_ARG_LIMIT, limit)
            }
            return resolver.query(uri, projection, extras, null)
        }

        val sort = if (limit > 0) "$dateDesc LIMIT $limit" else dateDesc
        return try {
            resolver.query(uri, projection, selection, args, sort)
        } catch (t: Throwable) {
            Log.w(TAG, "LIMIT in sort order rejected; retrying unlimited", t)
            resolver.query(uri, projection, selection, args, dateDesc)
        }
    }

    fun dispose() {
        channel?.setMethodCallHandler(null)
        channel = null
    }
}
