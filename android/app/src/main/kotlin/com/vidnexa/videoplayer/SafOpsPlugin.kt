package com.vidnexa.videoplayer

import android.content.Context
import android.net.Uri
import android.provider.DocumentsContract
import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * The Storage Access Framework calls the `docman` plugin does not expose.
 *
 * `docman` 1.2.0 ships `rename` commented out in both its extension and its
 * method class, so a file manager built on it has no way to rename anything.
 * Rather than fork the package, the two contract calls it is missing live
 * here.
 *
 * Everything below operates on a tree the user already granted through the
 * system picker. No `MANAGE_EXTERNAL_STORAGE`, no filesystem paths.
 */
class SafOpsPlugin(
    private val context: Context,
    messenger: BinaryMessenger,
) {
    companion object {
        const val CHANNEL = "com.vidnexa.videoplayer/saf_ops"
        private const val TAG = "SafOps"
    }

    private var channel: MethodChannel? = MethodChannel(messenger, CHANNEL).apply {
        setMethodCallHandler { call, result ->
            when (call.method) {
                "rename" -> {
                    val uri = call.argument<String>("uri")
                    val name = call.argument<String>("name")
                    if (uri.isNullOrEmpty() || name.isNullOrEmpty()) {
                        result.error("bad_args", "uri and name are required", null)
                    } else {
                        result.success(rename(uri, name))
                    }
                }

                // Deleting a document whose parent tree is known is what
                // DocumentsContract.deleteDocument does; docman covers that.
                // What it cannot do is tell a caller whether a name is already
                // taken without listing the whole directory, which on a large
                // folder is an IPC per entry.
                "exists" -> {
                    val parent = call.argument<String>("parent")
                    val name = call.argument<String>("name")
                    if (parent.isNullOrEmpty() || name.isNullOrEmpty()) {
                        result.error("bad_args", "parent and name are required", null)
                    } else {
                        result.success(childExists(parent, name))
                    }
                }

                else -> result.notImplemented()
            }
        }
    }

    /**
     * Returns the renamed document's uri, or null if the provider refused.
     *
     * The uri changes on some providers and stays the same on others, so the
     * caller must use what comes back rather than assuming the old one is
     * still valid.
     */
    private fun rename(uri: String, name: String): String? {
        return try {
            DocumentsContract.renameDocument(
                context.contentResolver,
                Uri.parse(uri),
                name,
            )?.toString()
        } catch (e: Exception) {
            // A provider that does not support renaming throws
            // UnsupportedOperationException; a name collision throws
            // FileNotFoundException. Neither should crash the app.
            Log.w(TAG, "rename failed: $e")
            null
        }
    }

    /**
     * Whether [parent] (a tree/document uri) already holds a child called
     * [name]. Used to warn before a copy or paste silently produces
     * "report (1).pdf".
     */
    private fun childExists(parent: String, name: String): Boolean {
        return try {
            val parentUri = Uri.parse(parent)
            val childrenUri = DocumentsContract.buildChildDocumentsUriUsingTree(
                parentUri,
                DocumentsContract.getDocumentId(parentUri),
            )

            context.contentResolver.query(
                childrenUri,
                arrayOf(DocumentsContract.Document.COLUMN_DISPLAY_NAME),
                null,
                null,
                null,
            )?.use { cursor ->
                while (cursor.moveToNext()) {
                    if (cursor.getString(0) == name) return true
                }
            }
            false
        } catch (e: Exception) {
            Log.w(TAG, "exists failed: $e")
            false
        }
    }

    fun dispose() {
        channel?.setMethodCallHandler(null)
        channel = null
    }
}
