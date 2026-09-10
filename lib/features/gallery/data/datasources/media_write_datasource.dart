import 'dart:io';
import 'dart:typed_data';

import 'package:gal/gal.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:share_plus/share_plus.dart';

/// The single owner of destructive and outward-facing photo operations in the
/// gallery module. No page or controller calls `PhotoManager.editor` directly.
///
/// Deletes matter here because the app targets SDK 36, where scoped storage
/// means `deleteWithIds` raises the system consent dialog on Android 11+. The
/// whole selection therefore goes in one call: the user sees one dialog, not
/// one per photo. A user who declines that dialog gets an empty result back,
/// which is a normal outcome and must not be reported as a failure.
class MediaWriteDatasource {
  Future<List<String>> deletePhotos(List<String> ids) async {
    if (ids.isEmpty) return const [];
    return PhotoManager.editor.deleteWithIds(ids);
  }

  /// Writes generated image bytes into the device gallery.
  ///
  /// Goes through `gal`, which handles the MediaStore insert and the album
  /// creation on Android. Results land in their own album rather than mixed
  /// into the camera roll, so an enhance or a collage is easy to find — and
  /// easy to delete if it was not wanted.
  ///
  /// Staged through a **uniquely named temp file** rather than handed over as
  /// bytes. `Gal.putImageBytes` names every file it writes `image.<ext>` — the
  /// name is hardcoded in the plugin — and leaves de-duplication to
  /// MediaProvider, which appends ` (1)`, ` (2)` and so on. MediaProvider only
  /// tries 32 suffixes: once an album held `image.jpg` through
  /// `image (31).jpg`, every further save threw
  /// `IllegalStateException: Failed to build unique file` and the tool reported
  /// a failure that no amount of retrying could clear. `Gal.putImage` takes the
  /// display name from the file instead, so a timestamped name sidesteps the
  /// collision entirely and also makes saves self-describing in a file manager.
  ///
  /// Returns false when saving was refused or failed, so the caller can say so
  /// instead of claiming a success that did not happen.
  Future<bool> saveImageBytes(Uint8List bytes, {required String album}) async {
    File? staged;
    try {
      if (!await Gal.hasAccess(toAlbum: true)) {
        final granted = await Gal.requestAccess(toAlbum: true);
        if (!granted) return false;
      }

      staged = File('${Directory.systemTemp.path}/${_fileName(album, bytes)}');
      await staged.writeAsBytes(bytes, flush: true);
      await Gal.putImage(staged.path, album: album);
      return true;
    } catch (_) {
      return false;
    } finally {
      // The copy in the gallery is the one that matters; this one would
      // otherwise sit in the cache at full resolution until Android evicts it.
      if (staged != null) {
        try {
          await staged.delete();
        } catch (_) {}
      }
    }
  }

  /// `VidNexa Collage-20260907-141530-847.jpg` — album, then a timestamp down
  /// to the millisecond so two saves in the same second cannot collide.
  ///
  /// The extension has to match the actual bytes: `gal` sets only the display
  /// name and the relative path, and MediaProvider derives the MIME type from
  /// the extension. The image tools encode JPEG, but text-on-photo composes
  /// through `toByteData(format: png)`, so the format is read off the magic
  /// number rather than assumed.
  static String _fileName(String album, Uint8List bytes) {
    final isPng = bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47;
    final now = DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    final stamp = '${now.year}${two(now.month)}${two(now.day)}'
        '-${two(now.hour)}${two(now.minute)}${two(now.second)}'
        '-${now.millisecond.toString().padLeft(3, '0')}';
    return '$album-$stamp.${isPng ? 'png' : 'jpg'}';
  }

  Future<void> shareFiles(List<File> files) async {
    if (files.isEmpty) return;
    await SharePlus.instance.share(
      ShareParams(files: files.map((file) => XFile(file.path)).toList()),
    );
  }
}
