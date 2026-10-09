import 'package:docman/docman.dart';
import 'package:flutter/foundation.dart';

/// Walks a Storage Access Framework tree the user granted.
///
/// Everything else in the file manager reads MediaStore, which needs no grant
/// and no walking. What is left here is the one place SAF is still needed:
/// Wireless Transfer enumerating the folder the user picked to share.
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
}
