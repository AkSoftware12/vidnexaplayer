import 'package:archive/archive.dart';
import 'package:docman/docman.dart';
import 'package:flutter/foundation.dart';

/// Storage Access Framework operations that need to walk or rewrite a tree.
///
/// Only the documents side of the file manager still uses SAF; everything else
/// reads MediaStore, which needs no grant and no walking. See
/// `media_store/saf_docs_page.dart` for why documents are the exception.
///
/// This file used to be much larger — it also backed the categories screen, the
/// recent list, the storage analyzer and the duplicate finder. All four now
/// answer from MediaStore in one cursor instead of thousands of binder calls,
/// so what is left here is the two things SAF is genuinely still needed for:
/// enumerating a granted tree, and reading/writing archives inside it.
class TreeWalk {
  const TreeWalk({required this.files, required this.truncated});

  final List<DocumentFile> files;

  /// True when a cap was hit, so the caller can say the picture is partial
  /// rather than passing a truncated list off as complete.
  final bool truncated;
}

class FileTools {
  FileTools._();

  /// Caps on a walk.
  ///
  /// Every directory listed is a separate binder round trip to the
  /// DocumentsProvider, and each entry returns a fully-populated DocumentFile.
  /// On a grant of a large tree that is tens of thousands of calls, so the
  /// worst case is bounded to a few seconds rather than an apparent freeze.
  static const int maxFiles = 4000;
  static const int maxDirs = 1200;

  /// Breadth-first walk of everything under [root].
  static Future<TreeWalk> walk(
    DocumentFile root, {
    bool includeHidden = false,
    void Function(int filesSeen, int dirsSeen)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final files = <DocumentFile>[];
    final queue = <DocumentFile>[root];

    var dirsSeen = 0;
    var truncated = false;

    while (queue.isNotEmpty) {
      if (isCancelled?.call() ?? false) {
        truncated = true;
        break;
      }
      if (files.length >= maxFiles || dirsSeen >= maxDirs) {
        truncated = true;
        break;
      }

      final dir = queue.removeAt(0);
      dirsSeen++;

      List<DocumentFile> children;
      try {
        children = await dir.listDocuments();
      } catch (e) {
        debugPrint('TreeWalk: cannot list ${dir.name} — $e');
        continue;
      }

      for (final child in children) {
        if (!includeHidden && child.name.startsWith('.')) continue;
        if (child.isDirectory) {
          queue.add(child);
        } else {
          files.add(child);
        }
      }

      onProgress?.call(files.length, dirsSeen);
    }

    return TreeWalk(files: files, truncated: truncated);
  }

  /// Zips [items] into [target] as [zipName].
  ///
  /// Folders are added recursively. Everything goes through memory because SAF
  /// gives no file path to stream from, which is why there is a total cap.
  static Future<DocumentFile?> compress({
    required List<DocumentFile> items,
    required DocumentFile target,
    required String zipName,
    int maxTotalBytes = 256 * 1024 * 1024,
    void Function(int done, int total)? onProgress,
  }) async {
    final archive = Archive();
    final flat = <({DocumentFile file, String path})>[];

    for (final item in items) {
      if (item.isDirectory) {
        await _collect(item, item.name, flat);
      } else {
        flat.add((file: item, path: item.name));
      }
    }

    var total = 0;
    for (var i = 0; i < flat.length; i++) {
      final entry = flat[i];
      try {
        final bytes = await entry.file.read();
        if (bytes == null) continue;

        total += bytes.length;
        if (total > maxTotalBytes) {
          debugPrint('compress: aborted, over $maxTotalBytes bytes');
          return null;
        }

        archive.addFile(ArchiveFile(entry.path, bytes.length, bytes));
      } catch (e) {
        debugPrint('compress: skipping ${entry.file.name} — $e');
      }
      onProgress?.call(i + 1, flat.length);
    }

    if (archive.isEmpty) return null;

    final encoded = ZipEncoder().encode(archive);

    // No mimeType argument: docman derives it from the extension, and throws
    // if it cannot — which is why the caller must pass a name ending in .zip.
    return target.createFile(
      name: zipName,
      bytes: Uint8List.fromList(encoded),
    );
  }

  static Future<void> _collect(
    DocumentFile dir,
    String prefix,
    List<({DocumentFile file, String path})> out,
  ) async {
    if (out.length > maxFiles) return;
    try {
      for (final child in await dir.listDocuments()) {
        if (child.isDirectory) {
          await _collect(child, '$prefix/${child.name}', out);
        } else {
          out.add((file: child, path: '$prefix/${child.name}'));
        }
      }
    } catch (e) {
      debugPrint('compress: cannot list ${dir.name} — $e');
    }
  }

  /// Extracts [zip] into a new folder beside it.
  ///
  /// ZIP only. There is no maintained pure-Dart RAR or 7z decoder, so those are
  /// left to whichever app on the device claims them.
  static Future<DocumentFile?> extract({
    required DocumentFile zip,
    required DocumentFile target,
    required String folderName,
    void Function(int done, int total)? onProgress,
  }) async {
    Uint8List? bytes;
    try {
      bytes = await zip.read();
    } catch (e) {
      debugPrint('extract: cannot read ${zip.name} — $e');
      return null;
    }
    if (bytes == null) return null;

    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (e) {
      debugPrint('extract: not a readable zip — $e');
      return null;
    }

    final root = await target.createDirectory(folderName);
    if (root == null) return null;

    // Directories are created lazily and cached: a 500-entry archive that all
    // lives in one folder would otherwise ask SAF to create it 500 times.
    final dirCache = <String, DocumentFile>{'': root};

    var done = 0;
    for (final entry in archive) {
      done++;
      onProgress?.call(done, archive.length);

      if (!entry.isFile) continue;

      // Guard against "../.." entries escaping the destination — a zip is
      // untrusted input, and a path traversal here would write wherever the
      // grant reaches.
      final safe = entry.name
          .split('/')
          .where((s) => s.isNotEmpty && s != '.' && s != '..')
          .toList();
      if (safe.isEmpty) continue;

      final fileName = safe.removeLast();
      final dir = await _ensureDir(root, safe, dirCache);
      if (dir == null) continue;

      try {
        await dir.createFile(
          name: fileName,
          bytes: Uint8List.fromList(entry.content as List<int>),
        );
      } catch (e) {
        debugPrint('extract: cannot write $fileName — $e');
      }
    }

    return root;
  }

  static Future<DocumentFile?> _ensureDir(
    DocumentFile root,
    List<String> parts,
    Map<String, DocumentFile> cache,
  ) async {
    var key = '';
    var current = root;

    for (final part in parts) {
      key = key.isEmpty ? part : '$key/$part';
      final cached = cache[key];
      if (cached != null) {
        current = cached;
        continue;
      }
      final made = await current.createDirectory(part);
      if (made == null) return null;
      cache[key] = made;
      current = made;
    }
    return current;
  }
}
