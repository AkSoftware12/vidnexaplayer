import 'package:docman/docman.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../Utils/app_palette.dart';
import 'file_kind.dart';

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
/// is readable — real directories, real sub-folders, every file type. No
/// declaration form, no policy risk.
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
  /// Navigation stack; `first` is the granted root, `last` is on screen.
  final List<DocumentFile> _stack = [];

  List<DocumentFile> _entries = const [];
  bool _loading = true;
  bool _picking = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  /// True when a back press was consumed by walking one level up. The hosting
  /// page asks this before popping the route.
  bool handleBack() {
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
    if (mounted) setState(() => _loading = true);

    try {
      final all = await dir.listDocuments();

      final dirs = <DocumentFile>[];
      final files = <DocumentFile>[];
      for (final entry in all) {
        if (entry.name.startsWith('.')) continue; // hidden
        if (entry.isDirectory) {
          dirs.add(entry);
        } else if (!widget.documentsOnly ||
            FileKind.of(entry.name).isDocument) {
          files.add(entry);
        }
      }

      int byName(DocumentFile a, DocumentFile b) =>
          a.name.toLowerCase().compareTo(b.name.toLowerCase());
      dirs.sort(byName);
      files.sort(byName);

      if (!mounted) return;
      setState(() {
        if (pushToStack) _stack.add(dir);
        _entries = [...dirs, ...files];
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

  Future<void> _pick() async {
    if (_picking) return;
    setState(() => _picking = true);

    try {
      // Grants persisted read access to the whole subtree, so this is asked
      // once and survives app restarts and reboots.
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
  }

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

    // Once a tree is open the breadcrumbs stay put across loads. Returning a
    // bare spinner here instead made every step into a sub-folder blank the
    // whole tab for as long as SAF took to enumerate it, which on a folder of
    // a few dozen files is long enough to look like the screen broke.
    return Column(
      children: [
        _breadcrumbs(),
        if (_error != null) _errorBar(),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _entries.isEmpty
              ? _centeredMessage(
                  Icons.folder_open_rounded,
                  widget.noItemsLabel,
                )
              : ListView.separated(
                  padding: EdgeInsets.fromLTRB(12.w, 8.h, 12.w, 24.h),
                  itemCount: _entries.length,
                  separatorBuilder: (_, __) => SizedBox(height: 6.h),
                  itemBuilder: (context, i) => _EntryTile(
                    entry: _entries[i],
                    onTap: () => _openEntry(_entries[i]),
                  ),
                ),
        ),
      ],
    );
  }

  /// Tappable path trail. Tapping an ancestor truncates the stack back to it,
  /// which is the only way back up on a device with a gesture-only navbar.
  Widget _breadcrumbs() {
    return Container(
      height: 44.h,
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
          TextButton(
            onPressed: _picking ? null : _pick,
            child: Text(
              widget.changeLabel,
              style: TextStyle(
                fontSize: 11.sp,
                fontWeight: FontWeight.w700,
                color: widget.accent,
              ),
            ),
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

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry, required this.onTap});

  final DocumentFile entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final kind = entry.isDirectory ? FileKind.folder : FileKind.of(entry.name);

    // For a directory SAF reports the child count in `size`, not a byte count.
    final subtitle = entry.isDirectory
        ? (entry.size > 0 ? '${entry.size} items' : 'Folder')
        : formatBytes(entry.size);

    return Material(
      color: AppPalette.card,
      borderRadius: BorderRadius.circular(14.r),
      child: InkWell(
        borderRadius: BorderRadius.circular(14.r),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
          child: Row(
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
              Icon(
                entry.isDirectory
                    ? Icons.chevron_right_rounded
                    : Icons.open_in_new_rounded,
                size: 18.sp,
                color: AppPalette.textS,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
