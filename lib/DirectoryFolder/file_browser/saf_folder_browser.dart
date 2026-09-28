import 'package:docman/docman.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../LockScreen/service/vault_service.dart';
import '../../NotifyListeners/LanguageProvider/home_strings.dart';
import '../../NotifyListeners/LanguageProvider/language_provider.dart';
import '../../Utils/app_palette.dart';
import 'bookmarks.dart';
import 'file_kind.dart';
import 'file_ops.dart';
import 'file_tools.dart';

/// Folder browser built on the Storage Access Framework.
///
/// ## Why not the filesystem
///
/// Walking `/storage/emulated/0` with `dart:io` needs
/// `MANAGE_EXTERNAL_STORAGE` ("All files access") from Android 11 onwards.
/// That permission is not declared by this app, and declaring it would put the
/// Play listing through the All-files-access declaration review — which Google
/// routinely rejects for media players. `READ_EXTERNAL_STORAGE` is capped at
/// `maxSdkVersion="32"` in the manifest and does nothing on newer devices, so
/// on every Android 13+ phone the old browser could only ever render its
/// "Storage access needed" empty state.
///
/// SAF has no such problem: the user grants one folder through the system
/// picker, Android persists that grant across reboots, and everything below it
/// is readable *and writable* — real directories, real sub-folders, every file
/// type. No declaration form, no policy risk.
///
/// The granted tree URI is remembered in [prefsKey] so the pick is a one-time
/// step rather than something the user repeats on every visit.
class SafFolderBrowser extends StatefulWidget {
  const SafFolderBrowser({
    super.key,
    required this.prefsKey,
    required this.emptyTitle,
    required this.emptyBody,
    required this.pickLabel,
    required this.changeLabel,
    required this.noItemsLabel,
    this.documentsOnly = false,
    this.accent = const Color(0xFF6C4DF6),
  });

  /// SharedPreferences key holding the persisted tree URI. Documents and
  /// Folders keep separate picks so choosing a Documents folder does not throw
  /// away the folder someone browses files in.
  final String prefsKey;

  final String emptyTitle;
  final String emptyBody;
  final String pickLabel;
  final String changeLabel;
  final String noItemsLabel;

  /// Hides media files, leaving only PDFs/office/text/archives. Sub-folders are
  /// always shown regardless — hiding them would make the tree unwalkable.
  final bool documentsOnly;

  final Color accent;

  @override
  State<SafFolderBrowser> createState() => SafFolderBrowserState();
}

class SafFolderBrowserState extends State<SafFolderBrowser> {
  /// View preferences are shared by every browser instance, not scoped to
  /// [SafFolderBrowser.prefsKey]: someone who switches to grid in Folders does
  /// not then want Docs still in list.
  static const _kSortKey = 'file_browser_sort';
  static const _kGridKey = 'file_browser_grid';
  static const _kHiddenKey = 'file_browser_show_hidden';

  /// Ceiling on a recursive search, so a pick of the storage root cannot walk
  /// tens of thousands of documents while the user waits.
  static const _kDeepSearchLimit = 400;
  static const _kDeepSearchDirs = 300;

  /// Navigation stack; `first` is the granted root, `last` is on screen.
  final List<DocumentFile> _stack = [];

  /// Everything in the current directory, before search filtering.
  List<DocumentFile> _entries = const [];

  /// Results of a sub-folder search. Null when not in deep-search mode.
  List<DocumentFile>? _deepResults;

  bool _loading = true;
  bool _picking = false;
  String? _error;

  FileSort _sort = FileSort.nameAsc;
  bool _grid = false;
  bool _showHidden = false;

  bool _searchOpen = false;
  String _query = '';
  bool _deepSearching = false;
  final TextEditingController _searchCtrl = TextEditingController();

  /// URIs of selected entries. URIs rather than DocumentFile because the list
  /// is rebuilt on every directory load and object identity does not survive.
  final Set<String> _selected = <String>{};
  bool get _selecting => _selected.isNotEmpty;

  /// A copy/move/delete in flight, with its progress.
  bool _busy = false;
  int _busyDone = 0;
  int _busyTotal = 0;

  String get _lang => context.read<LocaleProvider>().locale.languageCode;
  String _t(String key) => HomeStrings.t(_lang, key);

  @override
  void initState() {
    super.initState();
    FileClipboard.instance.addListener(_onClipboardChanged);
    Bookmarks.instance.addListener(_onClipboardChanged);
    Bookmarks.instance.load();
    _restorePrefs();
    _restore();
  }

  @override
  void dispose() {
    FileClipboard.instance.removeListener(_onClipboardChanged);
    Bookmarks.instance.removeListener(_onClipboardChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onClipboardChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _restorePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _sort = FileSort.fromPrefs(prefs.getString(_kSortKey));
      _grid = prefs.getBool(_kGridKey) ?? false;
      _showHidden = prefs.getBool(_kHiddenKey) ?? false;
    });
  }

  /// True when a back press was consumed here. Checked by the hosting page
  /// before it pops the route.
  ///
  /// Order matters: a selection or an open search box is "inner state" the
  /// user expects back to clear before it starts climbing directories.
  bool handleBack() {
    if (_selecting) {
      setState(_selected.clear);
      return true;
    }
    if (_deepResults != null) {
      setState(() => _deepResults = null);
      return true;
    }
    if (_searchOpen) {
      _closeSearch();
      return true;
    }
    if (_stack.length <= 1) return false;
    _stack.removeLast();
    unawaitedOpen(_stack.last, pushToStack: false);
    return true;
  }

  /// Re-opens the persisted tree, if there is still a live grant for it.
  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(widget.prefsKey);
      if (saved == null || saved.isEmpty) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      // A persisted grant can disappear: the user revokes it in Settings, the
      // SD card is unmounted, or the folder is deleted. `get()` returning null
      // (or a document that no longer exists) is the normal signal for that,
      // and the stale key is dropped so the empty state offers a fresh pick.
      final restored = await DocumentFile(uri: saved).get();
      if (restored == null || !restored.exists || !restored.isDirectory) {
        await prefs.remove(widget.prefsKey);
        if (mounted) setState(() => _loading = false);
        return;
      }

      await unawaitedOpen(restored, pushToStack: true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  /// Lists [dir] and shows it. Never throws — an unreadable directory renders
  /// an inline error instead of taking the tab down.
  Future<void> unawaitedOpen(
    DocumentFile dir, {
    required bool pushToStack,
  }) async {
    if (mounted) {
      setState(() {
        _loading = true;
        _selected.clear();
        _deepResults = null;
      });
    }

    try {
      final all = await dir.listDocuments();

      final visible = <DocumentFile>[];
      for (final entry in all) {
        if (!_showHidden && entry.name.startsWith('.')) continue;
        if (entry.isDirectory) {
          visible.add(entry);
        } else if (!widget.documentsOnly || FileKind.of(entry.name).isDocument) {
          visible.add(entry);
        }
      }
      sortEntries(visible, _sort);

      if (!mounted) return;
      setState(() {
        if (pushToStack) _stack.add(dir);
        _entries = visible;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  /// Re-lists the folder currently on screen. Called after every write so the
  /// listing reflects what just happened — SAF pushes no change notifications.
  Future<void> _refresh() async {
    if (_stack.isEmpty) return;
    await unawaitedOpen(_stack.last, pushToStack: false);
  }

  Future<void> _pick() async {
    if (_picking) return;
    setState(() => _picking = true);

    try {
      // Grants persisted read/write access to the whole subtree, so this is
      // asked once and survives app restarts and reboots.
      final picked = await DocMan.pick.directory(
        initDir: _stack.isNotEmpty ? _stack.first.uri : null,
      );
      if (picked == null) {
        if (mounted) setState(() => _picking = false);
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(widget.prefsKey, picked.uri);

      if (!mounted) return;
      setState(() {
        _picking = false;
        _stack.clear();
      });
      await unawaitedOpen(picked, pushToStack: true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _picking = false;
        _error = '$e';
      });
    }
  }

  Future<void> _openEntry(DocumentFile entry) async {
    if (entry.isDirectory) {
      await unawaitedOpen(entry, pushToStack: true);
      return;
    }

    // Hand the file to whichever installed app claims its type. Going through
    // SAF means we hold a content:// URI and no real path, so an in-app viewer
    // would have to copy the bytes to cache first; for documents the system
    // viewer is both faster and what users expect. (Videos, photos and music
    // are opened in-app from their own tabs, which are MediaStore-backed.)
    try {
      await entry.open();
    } catch (e) {
      _snack('$e');
    }
  }

  // ───────────────────────── selection ─────────────────────────

  void _toggle(DocumentFile entry) {
    setState(() {
      if (!_selected.remove(entry.uri)) _selected.add(entry.uri);
    });
  }

  List<DocumentFile> get _selectedEntries {
    final source = _deepResults ?? _visible;
    return source.where((e) => _selected.contains(e.uri)).toList();
  }

  void _selectAll() {
    final source = _deepResults ?? _visible;
    setState(() {
      if (_selected.length == source.length) {
        _selected.clear();
      } else {
        _selected
          ..clear()
          ..addAll(source.map((e) => e.uri));
      }
    });
  }

  // ───────────────────────── search ─────────────────────────

  /// The current folder's entries with the search box applied.
  List<DocumentFile> get _visible {
    if (_query.isEmpty) return _entries;
    final q = _query.toLowerCase();
    return _entries.where((e) => e.name.toLowerCase().contains(q)).toList();
  }

  void _closeSearch() {
    setState(() {
      _searchOpen = false;
      _query = '';
      _deepResults = null;
      _searchCtrl.clear();
    });
  }

  /// Walks the tree below the current folder looking for [_query].
  ///
  /// Breadth-first and hard-capped. Every directory listed here is a separate
  /// IPC round trip to the DocumentsProvider, so an uncapped recursive search
  /// from a storage-root grant would take minutes and allocate a DocumentFile
  /// per file on the device.
  Future<void> _deepSearch() async {
    if (_query.isEmpty || _stack.isEmpty) return;

    setState(() {
      _deepSearching = true;
      _deepResults = const [];
      _selected.clear();
    });

    final q = _query.toLowerCase();
    final hits = <DocumentFile>[];
    final queue = <DocumentFile>[_stack.last];
    var dirsVisited = 0;

    try {
      while (queue.isNotEmpty &&
          hits.length < _kDeepSearchLimit &&
          dirsVisited < _kDeepSearchDirs) {
        final dir = queue.removeAt(0);
        dirsVisited++;

        final children = await dir.listDocuments();
        for (final child in children) {
          if (!_showHidden && child.name.startsWith('.')) continue;
          if (child.isDirectory) queue.add(child);

          if (!child.name.toLowerCase().contains(q)) continue;
          if (!child.isDirectory &&
              widget.documentsOnly &&
              !FileKind.of(child.name).isDocument) {
            continue;
          }
          hits.add(child);
        }
      }
    } catch (e) {
      debugPrint('deep search failed: $e');
    }

    sortEntries(hits, _sort);
    if (!mounted) return;
    setState(() {
      _deepResults = hits;
      _deepSearching = false;
    });
  }

  // ───────────────────────── operations ─────────────────────────

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _report(BulkResult r) {
    _snack(
      r.allOk
          ? _t('fb_done_all').replaceAll('{ok}', '${r.succeeded}')
          : _t('fb_done_some')
              .replaceAll('{ok}', '${r.succeeded}')
              .replaceAll('{bad}', '${r.failed}'),
    );
  }

  void _onProgress(int done, int total) {
    if (!mounted) return;
    setState(() {
      _busyDone = done;
      _busyTotal = total;
    });
  }

  Future<void> _runBusy(Future<BulkResult> Function() op) async {
    setState(() {
      _busy = true;
      _busyDone = 0;
      _busyTotal = 0;
    });
    final result = await op();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _selected.clear();
    });
    _report(result);
    await _refresh();
  }

  void _clip(ClipboardMode mode) {
    final items = _selectedEntries;
    if (items.isEmpty) return;
    FileClipboard.instance.put(items, mode);
    setState(_selected.clear);
    _snack(
      _t('fb_clipboard_ready').replaceAll('{count}', '${items.length}'),
    );
  }

  Future<void> _paste() async {
    if (_stack.isEmpty) return;
    final clip = FileClipboard.instance;
    if (clip.isEmpty) return;

    final items = clip.items;
    final mode = clip.mode;
    await _runBusy(
      () => FileOps.paste(
        items: items,
        target: _stack.last,
        mode: mode,
        onProgress: _onProgress,
      ),
    );

    // A cut is consumed by its paste; a copy stays on the clipboard so the
    // same selection can be dropped into several folders.
    if (mode == ClipboardMode.cut) clip.clear();
  }

  Future<void> _deleteSelected() async {
    final items = _selectedEntries;
    if (items.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppPalette.card,
        content: Text(
          _t('fb_delete_confirm').replaceAll('{count}', '${items.length}'),
          style: TextStyle(color: AppPalette.textB, fontSize: 13.sp),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(_t('fb_cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade600),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(_t('fb_delete')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await _runBusy(() => FileOps.delete(items, onProgress: _onProgress));
  }

  Future<void> _newFolder() async {
    if (_stack.isEmpty) return;
    final name = await _promptName(
      title: _t('fb_new_folder'),
      label: _t('fb_folder_name'),
      confirmLabel: _t('fb_create'),
    );
    if (name == null) return;

    final created = await FileOps.createFolder(_stack.last, name);
    if (created == null) {
      _snack(_t('fb_new_folder'));
      return;
    }
    await _refresh();
  }

  Future<void> _renameSelected() async {
    final items = _selectedEntries;
    if (items.length != 1) return;
    final target = items.first;

    final name = await _promptName(
      title: _t('fb_rename'),
      label: _t('fb_new_name'),
      confirmLabel: _t('fb_rename'),
      initial: target.name,
    );
    if (name == null) return;

    final renamed = await FileOps.rename(target, name);
    if (!mounted) return;
    if (renamed == null) {
      // Providers are allowed to refuse a rename outright, and some do for
      // files on removable volumes. Say so rather than silently no-op.
      _snack(_t('fb_rename'));
      return;
    }
    setState(_selected.clear);
    await _refresh();
  }

  /// Zips the selection into the folder on screen.
  ///
  /// Named after the first item, so "Photos" becomes "Photos.zip" — a default
  /// the user can accept without reading, which is what a rename dialog on
  /// every compress would stop them doing.
  Future<void> _compressSelected() async {
    final items = _selectedEntries;
    if (items.isEmpty || _stack.isEmpty) return;

    final suggested = items.length == 1
        ? '${_stripExt(items.first.name)}.zip'
        : '${_stack.last.name}.zip';

    final name = await _promptName(
      title: _t('fb_compress'),
      label: _t('fb_zip_name'),
      confirmLabel: _t('fb_compress'),
      initial: suggested,
    );
    if (name == null) return;

    final zipName = name.toLowerCase().endsWith('.zip') ? name : '$name.zip';
    final target = _stack.last;

    setState(() {
      _busy = true;
      _busyDone = 0;
      _busyTotal = 0;
    });

    final created = await FileTools.compress(
      items: items,
      target: target,
      zipName: await FileOps.uniqueName(target, zipName),
      onProgress: _onProgress,
    );

    if (!mounted) return;
    setState(() {
      _busy = false;
      _selected.clear();
    });
    if (created == null) _snack(_t('fb_zip_failed'));
    await _refresh();
  }

  Future<void> _extractSelected() async {
    final items = _selectedEntries;
    if (items.length != 1 || _stack.isEmpty) return;

    final zip = items.first;
    if (!zip.name.toLowerCase().endsWith('.zip')) {
      // .rar and .7z reach here too; there is no maintained pure-Dart decoder
      // for either, so say so instead of failing silently.
      _snack(_t('fb_zip_only'));
      return;
    }

    final target = _stack.last;
    setState(() {
      _busy = true;
      _busyDone = 0;
      _busyTotal = 0;
    });

    final folder = await FileTools.extract(
      zip: zip,
      target: target,
      folderName: await FileOps.uniqueName(target, _stripExt(zip.name)),
      onProgress: _onProgress,
    );

    if (!mounted) return;
    setState(() {
      _busy = false;
      _selected.clear();
    });
    if (folder == null) _snack(_t('fb_extract_failed'));
    await _refresh();
  }

  /// Moves the selection into the app's private vault.
  ///
  /// SAF hands out content URIs, and [VaultService] works on real files, so
  /// each document is cached to a temp file first and the original deleted
  /// only once the vault copy is confirmed — a failure here must never be able
  /// to lose the file.
  Future<void> _vaultSelected() async {
    final items = _selectedEntries.where((e) => !e.isDirectory).toList();
    if (items.isEmpty) return;

    setState(() {
      _busy = true;
      _busyDone = 0;
      _busyTotal = items.length;
    });

    final vault = VaultService();
    var ok = 0;

    for (var i = 0; i < items.length; i++) {
      try {
        final cached = await items[i].cache();
        if (cached != null) {
          final added = await vault.addToVault(cached);
          // `addToVault` deletes the *cached copy*, not the document behind
          // the content uri — SAF is the only thing that can remove that, so
          // the original is deleted here, and only once the vault file exists.
          if (added.vaultPath.isNotEmpty) {
            await items[i].delete();
            ok++;
          }
        }
      } catch (e) {
        debugPrint('vault: ${items[i].name} — $e');
      }
      _onProgress(i + 1, items.length);
    }

    if (!mounted) return;
    setState(() {
      _busy = false;
      _selected.clear();
    });
    _snack(ok > 0 ? _t('fb_vault_done') : _t('fb_vault_failed'));
    await _refresh();
  }

  static String _stripExt(String name) {
    final dot = name.lastIndexOf('.');
    return dot <= 0 ? name : name.substring(0, dot);
  }

  /// Extra selection actions that do not fit on the six-slot action bar.
  Future<void> _moreActions() async {
    final items = _selectedEntries;
    final singleZip = items.length == 1 &&
        items.first.name.toLowerCase().endsWith('.zip');

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppPalette.card,
      shape: RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 8.h),
            _sheetTile(ctx, Icons.folder_zip_rounded, _t('fb_compress'),
                _compressSelected),
            if (singleZip)
              _sheetTile(ctx, Icons.unarchive_rounded, _t('fb_extract'),
                  _extractSelected),
            _sheetTile(ctx, Icons.lock_rounded, _t('fb_to_vault'),
                _vaultSelected),
            SizedBox(height: 8.h),
          ],
        ),
      ),
    );
  }

  Widget _sheetTile(
    BuildContext sheetContext,
    IconData icon,
    String label,
    Future<void> Function() action,
  ) {
    return ListTile(
      leading: Icon(icon, size: 20.sp, color: widget.accent),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 13.sp,
          color: AppPalette.textH,
          fontWeight: FontWeight.w600,
        ),
      ),
      onTap: () {
        Navigator.pop(sheetContext);
        action();
      },
    );
  }

  Future<void> _shareSelected() async {
    final items = _selectedEntries;
    if (items.isEmpty) return;
    try {
      // docman shares one document at a time; the common case is one file.
      await items.first.share();
    } catch (e) {
      _snack('$e');
    }
  }

  Future<String?> _promptName({
    required String title,
    required String label,
    required String confirmLabel,
    String initial = '',
  }) async {
    final ctrl = TextEditingController(text: initial);
    // Pre-select the stem so typing replaces the name but keeps ".pdf".
    final dot = initial.lastIndexOf('.');
    ctrl.selection = TextSelection(
      baseOffset: 0,
      extentOffset: dot > 0 ? dot : initial.length,
    );

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppPalette.card,
        title: Text(
          title,
          style: TextStyle(
            color: AppPalette.textH,
            fontSize: 15.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: TextStyle(color: AppPalette.textH, fontSize: 13.sp),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: TextStyle(color: AppPalette.textS),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: widget.accent),
            ),
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(_t('fb_cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: widget.accent),
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );

    ctrl.dispose();
    final trimmed = result?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }

  Future<void> _showProperties(DocumentFile entry) async {
    final perms = <String>[
      if (entry.canRead) _t('fb_perm_read'),
      if (entry.canWrite) _t('fb_perm_write'),
      if (entry.canDelete) _t('fb_perm_delete'),
    ].join(', ');

    final modified = entry.lastModifiedDate;

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppPalette.card,
        title: Text(
          _t('fb_properties'),
          style: TextStyle(
            color: AppPalette.textH,
            fontSize: 15.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PropRow(label: _t('fb_prop_name'), value: entry.name),
              _PropRow(
                label: _t('fb_prop_type'),
                value: entry.isDirectory
                    ? _t('fb_folder')
                    : (entry.type.isEmpty ? '—' : entry.type),
              ),
              _PropRow(
                label: _t('fb_prop_size'),
                value: entry.isDirectory
                    ? _t('fb_items_count')
                        .replaceAll('{count}', '${entry.size}')
                    : formatBytes(entry.size),
              ),
              if (modified != null)
                _PropRow(
                  label: _t('fb_prop_modified'),
                  value: '${modified.day.toString().padLeft(2, '0')}/'
                      '${modified.month.toString().padLeft(2, '0')}/'
                      '${modified.year}  '
                      '${modified.hour.toString().padLeft(2, '0')}:'
                      '${modified.minute.toString().padLeft(2, '0')}',
                ),
              _PropRow(
                label: _t('fb_prop_perms'),
                value: perms.isEmpty ? '—' : perms,
              ),
              // The decoded document id, which for the external-storage
              // provider reads as "primary:DCIM/Camera". Closest thing SAF has
              // to a path — there is no real filesystem path to show.
              _PropRow(
                label: _t('fb_prop_path'),
                value: _readablePath(entry.uri),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(_t('fb_close')),
          ),
        ],
      ),
    );
  }

  static String _readablePath(String uri) {
    final decoded = Uri.decodeFull(uri);
    final marker = decoded.lastIndexOf('/document/');
    if (marker < 0) return decoded;
    return decoded.substring(marker + '/document/'.length);
  }

  // ───────────────────────── build ─────────────────────────

  @override
  Widget build(BuildContext context) {
    AppPalette.sync(context);

    // Nothing picked yet: a spinner while the persisted grant is restored,
    // then the pick-a-folder state.
    if (_stack.isEmpty) {
      return _loading
          ? const Center(child: CircularProgressIndicator())
          : _emptyState();
    }

    final entries = _deepResults ?? _visible;

    // Once a tree is open the breadcrumbs stay put across loads. Returning a
    // bare spinner here instead made every step into a sub-folder blank the
    // whole tab for as long as SAF took to enumerate it, which on a folder of
    // a few dozen files is long enough to look like the screen broke.
    return Column(
      children: [
        if (_selecting) _selectionBar() else _toolbar(),
        if (_searchOpen && !_selecting) _searchBar(),
        if (_error != null) _errorBar(),
        if (_busy) _progressBar(),
        Expanded(
          child: _loading || _deepSearching
              ? const Center(child: CircularProgressIndicator())
              : entries.isEmpty
                  ? _centeredMessage(
                      Icons.folder_open_rounded,
                      _query.isEmpty ? widget.noItemsLabel : _t('fb_no_matches'),
                    )
                  : _grid
                      ? _gridView(entries)
                      : _listView(entries),
        ),
        if (_selecting) _actionBar(),
      ],
    );
  }

  Widget _listView(List<DocumentFile> entries) {
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(12.w, 8.h, 12.w, 24.h),
      itemCount: entries.length,
      separatorBuilder: (_, __) => SizedBox(height: 6.h),
      itemBuilder: (context, i) => _EntryTile(
        entry: entries[i],
        selected: _selected.contains(entries[i].uri),
        selecting: _selecting,
        accent: widget.accent,
        folderLabel: _t('fb_folder'),
        itemsLabel: _t('fb_items_count'),
        onTap: () =>
            _selecting ? _toggle(entries[i]) : _openEntry(entries[i]),
        onLongPress: () => _toggle(entries[i]),
        onInfo: () => _showProperties(entries[i]),
      ),
    );
  }

  Widget _gridView(List<DocumentFile> entries) {
    return GridView.builder(
      padding: EdgeInsets.fromLTRB(12.w, 8.h, 12.w, 24.h),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 8.h,
        crossAxisSpacing: 8.w,
        childAspectRatio: 0.86,
      ),
      itemCount: entries.length,
      itemBuilder: (context, i) => _EntryCard(
        entry: entries[i],
        selected: _selected.contains(entries[i].uri),
        selecting: _selecting,
        accent: widget.accent,
        onTap: () =>
            _selecting ? _toggle(entries[i]) : _openEntry(entries[i]),
        onLongPress: () => _toggle(entries[i]),
      ),
    );
  }

  /// Tappable path trail plus the view controls.
  ///
  /// Tapping an ancestor truncates the stack back to it, which is the only way
  /// back up on a device with a gesture-only navbar.
  Widget _toolbar() {
    final clip = FileClipboard.instance;

    return Container(
      height: 46.h,
      decoration: BoxDecoration(
        color: AppPalette.card,
        border: Border(bottom: BorderSide(color: AppPalette.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 12.w),
              itemCount: _stack.length,
              itemBuilder: (context, i) {
                final isLast = i == _stack.length - 1;
                return Row(
                  children: [
                    if (i > 0)
                      Icon(Icons.chevron_right_rounded,
                          size: 16.sp, color: AppPalette.textS),
                    InkWell(
                      onTap: isLast
                          ? null
                          : () {
                              final target = _stack[i];
                              setState(
                                  () => _stack.removeRange(i, _stack.length));
                              unawaitedOpen(target, pushToStack: true);
                            },
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: 6.w, vertical: 4.h),
                        child: Text(
                          i == 0 && _stack[i].name.isEmpty
                              ? '/'
                              : _stack[i].name,
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight:
                                isLast ? FontWeight.w700 : FontWeight.w500,
                            color: isLast ? AppPalette.textH : AppPalette.textS,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          if (clip.isNotEmpty)
            IconButton(
              tooltip: _t('fb_paste'),
              onPressed: _busy ? null : _paste,
              icon: Icon(Icons.content_paste_rounded,
                  size: 19.sp, color: widget.accent),
              visualDensity: VisualDensity.compact,
            ),
          IconButton(
            tooltip: _t('fb_search_hint'),
            onPressed: () => setState(() {
              _searchOpen = !_searchOpen;
              if (!_searchOpen) _closeSearch();
            }),
            icon: Icon(Icons.search_rounded,
                size: 19.sp, color: AppPalette.textB),
            visualDensity: VisualDensity.compact,
          ),
          _overflow(),
        ],
      ),
    );
  }

  Widget _overflow() {
    final bookmarked =
        _stack.isNotEmpty && Bookmarks.instance.contains(_stack.last.uri);

    return PopupMenuButton<String>(
      tooltip: '',
      color: AppPalette.card,
      icon: Icon(Icons.more_vert_rounded,
          size: 19.sp, color: AppPalette.textB),
      onSelected: (value) async {
        final prefs = await SharedPreferences.getInstance();
        switch (value) {
          case 'view':
            setState(() => _grid = !_grid);
            await prefs.setBool(_kGridKey, _grid);
          case 'hidden':
            setState(() => _showHidden = !_showHidden);
            await prefs.setBool(_kHiddenKey, _showHidden);
            await _refresh();
          case 'new':
            await _newFolder();
          case 'change':
            await _pick();
          case 'bookmark':
            if (_stack.isNotEmpty) {
              await Bookmarks.instance.toggle(_stack.last);
            }
          case 'bookmarks':
            await _showBookmarks();
          default:
            final sort = FileSort.fromPrefs(value);
            setState(() {
              _sort = sort;
              final list = [..._entries];
              sortEntries(list, sort);
              _entries = list;
              if (_deepResults != null) {
                final deep = [..._deepResults!];
                sortEntries(deep, sort);
                _deepResults = deep;
              }
            });
            await prefs.setString(_kSortKey, sort.prefsValue);
        }
      },
      itemBuilder: (context) => [
        _menuItem('new', Icons.create_new_folder_rounded, _t('fb_new_folder')),
        _menuItem(
          'bookmark',
          bookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
          bookmarked ? _t('fb_bookmark_remove') : _t('fb_bookmark_add'),
        ),
        _menuItem('bookmarks', Icons.bookmarks_rounded, _t('fb_bookmarks')),
        _menuItem(
          'view',
          _grid ? Icons.view_list_rounded : Icons.grid_view_rounded,
          _grid ? _t('fb_view_list') : _t('fb_view_grid'),
        ),
        _menuItem(
          'hidden',
          _showHidden
              ? Icons.visibility_off_rounded
              : Icons.visibility_rounded,
          _t('fb_show_hidden'),
          checked: _showHidden,
        ),
        _menuItem('change', Icons.drive_folder_upload_rounded,
            widget.changeLabel),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          enabled: false,
          height: 28.h,
          child: Text(
            _t('fb_sort'),
            style: TextStyle(fontSize: 10.5.sp, color: AppPalette.textS),
          ),
        ),
        _sortItem(FileSort.nameAsc, 'fb_sort_name_asc'),
        _sortItem(FileSort.nameDesc, 'fb_sort_name_desc'),
        _sortItem(FileSort.sizeDesc, 'fb_sort_size_desc'),
        _sortItem(FileSort.sizeAsc, 'fb_sort_size_asc'),
        _sortItem(FileSort.dateDesc, 'fb_sort_date_desc'),
        _sortItem(FileSort.dateAsc, 'fb_sort_date_asc'),
        _sortItem(FileSort.typeAsc, 'fb_sort_type'),
      ],
    );
  }

  PopupMenuItem<String> _menuItem(
    String value,
    IconData icon,
    String label, {
    bool checked = false,
  }) {
    return PopupMenuItem<String>(
      value: value,
      height: 40.h,
      child: Row(
        children: [
          Icon(icon, size: 17.sp, color: AppPalette.textB),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 12.sp, color: AppPalette.textH),
            ),
          ),
          if (checked)
            Icon(Icons.check_rounded, size: 15.sp, color: widget.accent),
        ],
      ),
    );
  }

  PopupMenuItem<String> _sortItem(FileSort sort, String key) {
    final active = _sort == sort;
    return PopupMenuItem<String>(
      value: sort.prefsValue,
      height: 36.h,
      child: Row(
        children: [
          SizedBox(width: 27.w),
          Expanded(
            child: Text(
              _t(key),
              style: TextStyle(
                fontSize: 12.sp,
                color: active ? widget.accent : AppPalette.textH,
                fontWeight: active ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
          if (active)
            Icon(Icons.check_rounded, size: 15.sp, color: widget.accent),
        ],
      ),
    );
  }

  /// Bookmarked folders, as a jump list.
  ///
  /// A bookmark that no longer resolves is dropped by [Bookmarks.resolve]
  /// rather than shown as a row that does nothing when tapped — SAF grants go
  /// away when the user revokes them or unmounts the card.
  Future<void> _showBookmarks() async {
    await Bookmarks.instance.load();
    if (!mounted) return;

    final items = Bookmarks.instance.items;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppPalette.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (ctx) => SafeArea(
        child: items.isEmpty
            ? Padding(
                padding: EdgeInsets.all(28.sp),
                child: Text(
                  _t('fb_no_bookmarks'),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12.5.sp, color: AppPalette.textS),
                ),
              )
            : ListView(
                shrinkWrap: true,
                children: [
                  SizedBox(height: 8.h),
                  for (final b in items)
                    ListTile(
                      leading: Icon(Icons.folder_rounded,
                          size: 20.sp, color: widget.accent),
                      title: Text(
                        b.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.sp,
                          color: AppPalette.textH,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      trailing: IconButton(
                        onPressed: () async {
                          await Bookmarks.instance.remove(b.uri);
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                        icon: Icon(Icons.close_rounded,
                            size: 16.sp, color: AppPalette.textS),
                      ),
                      onTap: () async {
                        Navigator.pop(ctx);
                        final doc = await Bookmarks.instance.resolve(b);
                        if (doc == null || !mounted) return;
                        setState(_stack.clear);
                        await unawaitedOpen(doc, pushToStack: true);
                      },
                    ),
                  SizedBox(height: 8.h),
                ],
              ),
      ),
    );
  }

  Widget _searchBar() {
    return Container(
      color: AppPalette.card,
      padding: EdgeInsets.fromLTRB(12.w, 0, 6.w, 8.h),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 38.h,
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                style: TextStyle(fontSize: 12.5.sp, color: AppPalette.textH),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: _t('fb_search_hint'),
                  hintStyle:
                      TextStyle(fontSize: 12.sp, color: AppPalette.textS),
                  prefixIcon: Icon(Icons.search_rounded,
                      size: 17.sp, color: AppPalette.textS),
                  suffixIcon: IconButton(
                    onPressed: _closeSearch,
                    icon: Icon(Icons.close_rounded,
                        size: 16.sp, color: AppPalette.textS),
                  ),
                  filled: true,
                  fillColor: AppPalette.raised,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (v) => setState(() {
                  _query = v.trim();
                  // Typing goes back to filtering this folder; the deep result
                  // set belonged to the previous query.
                  _deepResults = null;
                }),
              ),
            ),
          ),
          SizedBox(width: 4.w),
          TextButton(
            onPressed: _query.isEmpty ? null : _deepSearch,
            child: Text(
              _t('fb_search_deep'),
              style: TextStyle(
                fontSize: 10.5.sp,
                fontWeight: FontWeight.w700,
                color: _query.isEmpty ? AppPalette.textS : widget.accent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _selectionBar() {
    final source = _deepResults ?? _visible;
    return Container(
      height: 46.h,
      color: widget.accent.withValues(alpha: 0.12),
      padding: EdgeInsets.symmetric(horizontal: 6.w),
      child: Row(
        children: [
          IconButton(
            onPressed: () => setState(_selected.clear),
            icon: Icon(Icons.close_rounded,
                size: 19.sp, color: AppPalette.textH),
            visualDensity: VisualDensity.compact,
          ),
          Expanded(
            child: Text(
              _t('fb_selected').replaceAll('{count}', '${_selected.length}'),
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w700,
                color: AppPalette.textH,
              ),
            ),
          ),
          TextButton(
            onPressed: _selectAll,
            child: Text(
              _t('fb_select_all'),
              style: TextStyle(
                fontSize: 11.sp,
                fontWeight: FontWeight.w700,
                color: widget.accent,
              ),
            ),
          ),
          SizedBox(width: 4.w),
          Text(
            '${_selected.length}/${source.length}',
            style: TextStyle(fontSize: 10.5.sp, color: AppPalette.textS),
          ),
          SizedBox(width: 8.w),
        ],
      ),
    );
  }

  Widget _actionBar() {
    final one = _selected.length == 1;
    return Container(
      decoration: BoxDecoration(
        color: AppPalette.card,
        border: Border(top: BorderSide(color: AppPalette.border)),
      ),
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _action(Icons.content_copy_rounded, _t('fb_copy'),
                () => _clip(ClipboardMode.copy)),
            _action(Icons.content_cut_rounded, _t('fb_cut'),
                () => _clip(ClipboardMode.cut)),
            _action(Icons.drive_file_rename_outline_rounded, _t('fb_rename'),
                one ? _renameSelected : null),
            _action(Icons.share_rounded, _t('fb_share'),
                one ? _shareSelected : null),
            _action(Icons.delete_outline_rounded, _t('fb_delete'),
                _deleteSelected, danger: true),
            _action(Icons.more_horiz_rounded, _t('fb_more'), _moreActions),
          ],
        ),
      ),
    );
  }

  Widget _action(
    IconData icon,
    String label,
    VoidCallback? onTap, {
    bool danger = false,
  }) {
    final enabled = onTap != null && !_busy;
    final color = !enabled
        ? AppPalette.textS.withValues(alpha: 0.45)
        : danger
            ? Colors.red.shade600
            : AppPalette.textB;

    return Expanded(
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(10.r),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 6.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 19.sp, color: color),
              SizedBox(height: 3.h),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 9.5.sp, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _progressBar() {
    return Container(
      color: widget.accent.withValues(alpha: 0.08),
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
      child: Row(
        children: [
          SizedBox(
            height: 13.sp,
            width: 13.sp,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: widget.accent,
              value: _busyTotal == 0 ? null : _busyDone / _busyTotal,
            ),
          ),
          SizedBox(width: 10.w),
          Text(
            _t('fb_working')
                .replaceAll('{done}', '$_busyDone')
                .replaceAll('{total}', '$_busyTotal'),
            style: TextStyle(fontSize: 11.sp, color: AppPalette.textB),
          ),
        ],
      ),
    );
  }

  Widget _errorBar() {
    return Container(
      width: double.infinity,
      color: Colors.red.withValues(alpha: 0.08),
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
      child: Text(
        _error!,
        style: TextStyle(fontSize: 11.sp, color: Colors.red.shade700),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 78.sp,
              width: 78.sp,
              decoration: BoxDecoration(
                color: widget.accent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.drive_folder_upload_rounded,
                  size: 36.sp, color: widget.accent),
            ),
            SizedBox(height: 18.h),
            Text(
              widget.emptyTitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15.sp,
                fontWeight: FontWeight.w800,
                color: AppPalette.textH,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              widget.emptyBody,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.sp,
                height: 1.45,
                color: AppPalette.textS,
              ),
            ),
            if (_error != null) ...[
              SizedBox(height: 10.h),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11.sp, color: Colors.red.shade700),
              ),
            ],
            SizedBox(height: 22.h),
            SizedBox(
              height: 44.h,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: widget.accent,
                  // Explicit, not inherited. Without it the label and icon
                  // took their colour from the app theme and rendered black
                  // on the violet fill.
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 22.w),
                ),
                onPressed: _picking ? null : _pick,
                icon: _picking
                    ? SizedBox(
                        height: 16.sp,
                        width: 16.sp,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.folder_open_rounded, size: 18),
                label: Text(
                  widget.pickLabel,
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _centeredMessage(IconData icon, String text) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 42.sp, color: AppPalette.textS),
          SizedBox(height: 10.h),
          Text(
            text,
            style: TextStyle(fontSize: 12.5.sp, color: AppPalette.textS),
          ),
        ],
      ),
    );
  }
}

class _PropRow extends StatelessWidget {
  const _PropRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 10.sp, color: AppPalette.textS),
          ),
          SizedBox(height: 2.h),
          SelectableText(
            value,
            style: TextStyle(
              fontSize: 12.sp,
              color: AppPalette.textH,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({
    required this.entry,
    required this.selected,
    required this.selecting,
    required this.accent,
    required this.folderLabel,
    required this.itemsLabel,
    required this.onTap,
    required this.onLongPress,
    required this.onInfo,
  });

  final DocumentFile entry;
  final bool selected;
  final bool selecting;
  final Color accent;
  final String folderLabel;
  final String itemsLabel;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onInfo;

  @override
  Widget build(BuildContext context) {
    final kind = entry.isDirectory ? FileKind.folder : FileKind.of(entry.name);

    // For a directory SAF reports the child count in `size`, not a byte count.
    final subtitle = entry.isDirectory
        ? (entry.size > 0
            ? itemsLabel.replaceAll('{count}', '${entry.size}')
            : folderLabel)
        : formatBytes(entry.size);

    return Material(
      color: selected ? accent.withValues(alpha: 0.14) : AppPalette.card,
      borderRadius: BorderRadius.circular(14.r),
      child: InkWell(
        borderRadius: BorderRadius.circular(14.r),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
          child: Row(
            children: [
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    height: 42.sp,
                    width: 42.sp,
                    decoration: BoxDecoration(
                      color: kind.color.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Icon(kind.icon, color: kind.color, size: 22.sp),
                  ),
                  if (selected)
                    Container(
                      decoration: BoxDecoration(
                        color: accent,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppPalette.card, width: 1.5),
                      ),
                      padding: EdgeInsets.all(1.sp),
                      child: Icon(Icons.check_rounded,
                          size: 11.sp, color: Colors.white),
                    ),
                ],
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                        color: AppPalette.textH,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      SizedBox(height: 2.h),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 10.5.sp,
                          color: AppPalette.textS,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // The info affordance disappears in selection mode: with a
              // selection running, every tap on the row should be changing the
              // selection, not opening a dialog over it.
              if (selecting)
                Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 20.sp,
                  color: selected ? accent : AppPalette.textS,
                )
              else
                InkWell(
                  onTap: onInfo,
                  borderRadius: BorderRadius.circular(20.r),
                  child: Padding(
                    padding: EdgeInsets.all(4.sp),
                    child: Icon(Icons.more_horiz_rounded,
                        size: 18.sp, color: AppPalette.textS),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({
    required this.entry,
    required this.selected,
    required this.selecting,
    required this.accent,
    required this.onTap,
    required this.onLongPress,
  });

  final DocumentFile entry;
  final bool selected;
  final bool selecting;
  final Color accent;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final kind = entry.isDirectory ? FileKind.folder : FileKind.of(entry.name);

    return Material(
      color: selected ? accent.withValues(alpha: 0.14) : AppPalette.card,
      borderRadius: BorderRadius.circular(14.r),
      child: InkWell(
        borderRadius: BorderRadius.circular(14.r),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: EdgeInsets.all(8.sp),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                alignment: Alignment.topRight,
                children: [
                  Container(
                    height: 46.sp,
                    width: 46.sp,
                    decoration: BoxDecoration(
                      color: kind.color.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                    child: Icon(kind.icon, color: kind.color, size: 24.sp),
                  ),
                  if (selecting)
                    Icon(
                      selected
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      size: 14.sp,
                      color: selected ? accent : AppPalette.textS,
                    ),
                ],
              ),
              SizedBox(height: 6.h),
              Text(
                entry.name,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5.sp,
                  fontWeight: FontWeight.w600,
                  color: AppPalette.textH,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
