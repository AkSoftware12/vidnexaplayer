import 'package:docman/docman.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// What a pending clipboard operation will do when pasted.
enum ClipboardMode { copy, cut }

/// Outcome of a bulk operation, so the caller can report "3 of 5 copied"
/// instead of a bare success/failure.
class BulkResult {
  const BulkResult({
    required this.succeeded,
    required this.failed,
    this.firstError,
  });

  final int succeeded;
  final int failed;
  final String? firstError;

  bool get allOk => failed == 0;
  int get total => succeeded + failed;
}

/// The cut/copy buffer, shared across the whole file browser.
///
/// A singleton rather than state on one tab: the point of cut-and-paste is
/// that you take something from one folder and drop it in another, and the
/// Folders and Docs tabs are two separate [SafFolderBrowser] instances with
/// their own navigation stacks.
class FileClipboard extends ChangeNotifier {
  FileClipboard._();
  static final FileClipboard instance = FileClipboard._();

  List<DocumentFile> _items = const [];
  ClipboardMode _mode = ClipboardMode.copy;

  List<DocumentFile> get items => _items;
  ClipboardMode get mode => _mode;
  bool get isEmpty => _items.isEmpty;
  bool get isNotEmpty => _items.isNotEmpty;

  void put(List<DocumentFile> items, ClipboardMode mode) {
    _items = List.unmodifiable(items);
    _mode = mode;
    notifyListeners();
  }

  void clear() {
    if (_items.isEmpty) return;
    _items = const [];
    notifyListeners();
  }
}

/// Storage Access Framework file operations.
///
/// Every call here works inside a tree the user granted through the system
/// picker. Nothing touches a filesystem path, so none of it needs
/// `MANAGE_EXTERNAL_STORAGE` — see [SafFolderBrowser]'s header for why that
/// permission is off the table for this app.
class FileOps {
  FileOps._();

  static const MethodChannel _channel =
      MethodChannel('com.vidnexa.videoplayer/saf_ops');

  /// Renames [file] and returns the renamed document, or null on failure.
  ///
  /// Goes through a platform channel because `docman` 1.2.0 ships its own
  /// `rename` commented out. The provider may hand back a *different* uri, so
  /// the result is re-fetched rather than assuming the old handle still points
  /// at anything.
  static Future<DocumentFile?> rename(DocumentFile file, String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty || trimmed == file.name) return file;

    try {
      final uri = await _channel.invokeMethod<String>('rename', {
        'uri': file.uri,
        'name': trimmed,
      });
      if (uri == null) return null;
      return DocumentFile(uri: uri).get();
    } on PlatformException catch (e) {
      debugPrint('FileOps.rename failed: $e');
      return null;
    }
  }

  /// Whether [parent] already contains a child called [name].
  ///
  /// One cursor over the children instead of `listDocuments()`, which builds a
  /// DocumentFile — and pays an IPC round trip — for every entry in the folder
  /// just to compare names.
  static Future<bool> exists(DocumentFile parent, String name) async {
    try {
      return await _channel.invokeMethod<bool>('exists', {
            'parent': parent.uri,
            'name': name,
          }) ??
          false;
    } on PlatformException catch (e) {
      debugPrint('FileOps.exists failed: $e');
      return false;
    }
  }

  /// "report.pdf" -> "report (1).pdf" -> "report (2).pdf", skipping names that
  /// are already taken in [parent].
  ///
  /// Capped at 99 tries so a pathological folder cannot spin here forever; at
  /// that point the caller gets the last candidate and the provider decides.
  static Future<String> uniqueName(DocumentFile parent, String name) async {
    if (!await exists(parent, name)) return name;

    final dot = name.lastIndexOf('.');
    final stem = dot <= 0 ? name : name.substring(0, dot);
    final ext = dot <= 0 ? '' : name.substring(dot);

    for (var i = 1; i < 100; i++) {
      final candidate = '$stem ($i)$ext';
      if (!await exists(parent, candidate)) return candidate;
    }
    return '$stem (${DateTime.now().millisecondsSinceEpoch})$ext';
  }

  static Future<DocumentFile?> createFolder(
    DocumentFile parent,
    String name,
  ) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return null;
    try {
      return await parent.createDirectory(trimmed);
    } catch (e) {
      debugPrint('FileOps.createFolder failed: $e');
      return null;
    }
  }

  /// Deletes each of [items], reporting how many made it.
  ///
  /// A failure on one entry does not stop the rest: half a selection deleting
  /// is a better outcome than the first read-only file aborting the batch and
  /// leaving the user to work out where it stopped.
  static Future<BulkResult> delete(
    List<DocumentFile> items, {
    void Function(int done, int total)? onProgress,
  }) async {
    var ok = 0;
    var bad = 0;
    String? firstError;

    for (var i = 0; i < items.length; i++) {
      try {
        if (await items[i].delete()) {
          ok++;
        } else {
          bad++;
          firstError ??= items[i].name;
        }
      } catch (e) {
        bad++;
        firstError ??= '${items[i].name}: $e';
      }
      onProgress?.call(i + 1, items.length);
    }

    return BulkResult(succeeded: ok, failed: bad, firstError: firstError);
  }

  /// Copies or moves [items] into [target].
  ///
  /// Name collisions are resolved by suffixing rather than overwriting —
  /// silently replacing a file the user cannot see is not recoverable.
  ///
  /// Pasting a folder into itself (or into its own descendant) is refused up
  /// front: SAF would happily start the recursion and it does not terminate.
  static Future<BulkResult> paste({
    required List<DocumentFile> items,
    required DocumentFile target,
    required ClipboardMode mode,
    void Function(int done, int total)? onProgress,
  }) async {
    var ok = 0;
    var bad = 0;
    String? firstError;

    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      try {
        if (_isSelfOrDescendant(target: target, source: item)) {
          bad++;
          firstError ??= item.name;
          onProgress?.call(i + 1, items.length);
          continue;
        }

        final name = await uniqueName(target, item.name);
        final result = mode == ClipboardMode.copy
            ? await item.copyTo(target.uri, name: name)
            : await item.moveTo(target.uri, name: name);

        if (result != null) {
          ok++;
        } else {
          bad++;
          firstError ??= item.name;
        }
      } catch (e) {
        bad++;
        firstError ??= '${item.name}: $e';
      }
      onProgress?.call(i + 1, items.length);
    }

    return BulkResult(succeeded: ok, failed: bad, firstError: firstError);
  }

  /// Rough containment test on document uris.
  ///
  /// SAF gives no parent pointer, so this compares the encoded document ids:
  /// a child's id starts with its ancestor's id followed by a separator. It is
  /// a heuristic — providers are not required to build ids that way — but on
  /// the external-storage provider (the one behind every internal/SD pick) ids
  /// are `primary:Path/To/Thing`, and it catches exactly the case that hangs.
  static bool _isSelfOrDescendant({
    required DocumentFile target,
    required DocumentFile source,
  }) {
    if (!source.isDirectory) return false;
    if (target.uri == source.uri) return true;

    final src = Uri.decodeFull(source.uri);
    final dst = Uri.decodeFull(target.uri);
    return dst.startsWith('$src/');
  }
}

/// Sort orders offered in the browser's overflow menu.
enum FileSort {
  nameAsc,
  nameDesc,
  sizeDesc,
  sizeAsc,
  dateDesc,
  dateAsc,
  typeAsc;

  String get prefsValue => name;

  static FileSort fromPrefs(String? value) => FileSort.values.firstWhere(
        (s) => s.name == value,
        orElse: () => FileSort.nameAsc,
      );
}

/// Sorts [entries] in place, always keeping folders above files.
///
/// Folders first is not a preference: SAF reports a directory's `size` as its
/// child count, so mixing them into a size sort would rank "a folder with 900
/// items" against "a 900-byte file".
void sortEntries(List<DocumentFile> entries, FileSort sort) {
  int byName(DocumentFile a, DocumentFile b) =>
      a.name.toLowerCase().compareTo(b.name.toLowerCase());

  entries.sort((a, b) {
    if (a.isDirectory != b.isDirectory) return a.isDirectory ? -1 : 1;

    switch (sort) {
      case FileSort.nameAsc:
        return byName(a, b);
      case FileSort.nameDesc:
        return byName(b, a);
      case FileSort.sizeDesc:
        if (a.isDirectory) return byName(a, b);
        return b.size.compareTo(a.size);
      case FileSort.sizeAsc:
        if (a.isDirectory) return byName(a, b);
        return a.size.compareTo(b.size);
      case FileSort.dateDesc:
        return b.lastModified.compareTo(a.lastModified);
      case FileSort.dateAsc:
        return a.lastModified.compareTo(b.lastModified);
      case FileSort.typeAsc:
        final ea = _ext(a.name);
        final eb = _ext(b.name);
        final c = ea.compareTo(eb);
        return c != 0 ? c : byName(a, b);
    }
  });
}

String _ext(String name) {
  final dot = name.lastIndexOf('.');
  return dot <= 0 ? '' : name.substring(dot + 1).toLowerCase();
}
