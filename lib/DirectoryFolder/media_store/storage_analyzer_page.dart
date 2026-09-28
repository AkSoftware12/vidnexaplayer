import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../NotifyListeners/LanguageProvider/home_strings.dart';
import '../../NotifyListeners/LanguageProvider/language_provider.dart';
import '../../Utils/app_palette.dart';
import '../file_browser/file_kind.dart';
import 'media_list_page.dart';
import 'media_store.dart';

/// What is using the space, by type and by folder.
///
/// Reads MediaStore instead of walking a granted folder tree, which is what the
/// previous version did. That one needed a folder pick, capped itself at 4 000
/// files because every directory was a separate binder call, and then had to
/// tell the user the picture was incomplete. This sees everything MediaStore
/// indexes for the app, in one query, with nothing to grant.
///
/// The honest limit is the same one the rest of the file manager has: scoped
/// storage hides other apps' non-media files, so this measures photos, video
/// and audio. On a phone that is very nearly all of it.
class StorageAnalyzerPage extends StatefulWidget {
  const StorageAnalyzerPage({super.key, this.accent = const Color(0xFF6C4DF6)});

  final Color accent;

  @override
  State<StorageAnalyzerPage> createState() => _StorageAnalyzerPageState();
}

class _StorageAnalyzerPageState extends State<StorageAnalyzerPage> {
  List<MediaFile> _files = const [];
  List<MediaFolder> _folders = const [];
  bool _loading = true;

  String get _lang => context.read<LocaleProvider>().locale.languageCode;
  String _t(String key) => HomeStrings.t(_lang, key);

  @override
  void initState() {
    super.initState();
    final files = MediaStoreRepo.instance.cached(MediaKind.all);
    final folders = MediaStoreRepo.instance.cachedFolders;
    if (files != null && folders != null) {
      _files = files;
      _folders = folders;
      _loading = false;
    }
    _load();
  }

  Future<void> _load({bool refresh = false}) async {
    final files = await MediaStoreRepo.instance.files(
      MediaKind.all,
      refresh: refresh,
    );
    final folders = await MediaStoreRepo.instance.folders(refresh: refresh);
    if (!mounted) return;
    setState(() {
      _files = files;
      _folders = folders;
      _loading = false;
    });
  }

  /// Bytes per category.
  ///
  /// Grouped by category, not by [FileKind]. Per-kind was the obvious grouping
  /// and the wrong one: pdf, document, spreadsheet, presentation and text are
  /// five kinds that all read as "Documents", so the legend listed Documents
  /// several times with different totals and no way to tell them apart.
  Map<_Slice, int> get _byCategory {
    final totals = <_Slice, int>{};
    for (final f in _files) {
      if (f.size <= 0) continue;
      final slice = _Slice.of(f.kind);
      totals[slice] = (totals[slice] ?? 0) + f.size;
    }
    return totals;
  }

  @override
  Widget build(BuildContext context) {
    AppPalette.sync(context);

    final slices = _byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = slices.fold<int>(0, (s, e) => s + e.value);

    return Scaffold(
      backgroundColor: AppPalette.surface,
      appBar: AppBar(
        backgroundColor: AppPalette.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppPalette.textH,
        titleSpacing: 0,
        title: Text(
          _t('fb_analyzer'),
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppPalette.textH,
          ),
        ),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: widget.accent))
          : RefreshIndicator(
              color: widget.accent,
              onRefresh: () => _load(refresh: true),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
                children: [
                  Center(
                    child: SizedBox(
                      height: 190,
                      width: 190,
                      child: CustomPaint(
                        painter: _DonutPainter(
                          slices: [
                            for (final e in slices)
                              (value: e.value.toDouble(), color: e.key.color),
                          ],
                          ringColor: AppPalette.border,
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                formatBytes(total),
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: AppPalette.textH,
                                ),
                              ),
                              Text(
                                _t('fb_items_count')
                                    .replaceAll('{count}', '${_files.length}'),
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: AppPalette.textS,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  for (final e in slices)
                    _Row(
                      color: e.key.color,
                      icon: e.key.icon,
                      label: _t(e.key.stringKey),
                      value: formatBytes(e.value),
                      fraction: total == 0 ? 0 : e.value / total,
                    ),

                  if (_folders.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    Text(
                      _t('fb_by_folder'),
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppPalette.textH,
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Tappable, unlike the old chart: the point of seeing that
                    // one folder holds 1.4 GB is to go and look at what is in
                    // it.
                    for (final f in _folders.take(15))
                      _Row(
                        color: FileKind.folder.color,
                        icon: Icons.folder_rounded,
                        label: f.name,
                        value: formatBytes(f.bytes),
                        fraction: total == 0 ? 0 : f.bytes / total,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            settings: const RouteSettings(
                              name: 'FolderFilesScreen',
                            ),
                            builder: (_) => MediaListPage(
                              kind: MediaKind.all,
                              title: f.name,
                              accent: widget.accent,
                              folderPath: f.path,
                            ),
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
    );
  }
}

/// The buckets the chart shows. Wraps several [FileKind]s each.
enum _Slice {
  videos,
  images,
  audio,
  documents,
  archives,
  apks,
  other;

  static _Slice of(FileKind kind) => switch (kind) {
        FileKind.video => _Slice.videos,
        FileKind.image => _Slice.images,
        FileKind.audio => _Slice.audio,
        FileKind.pdf ||
        FileKind.document ||
        FileKind.spreadsheet ||
        FileKind.presentation ||
        FileKind.text =>
          _Slice.documents,
        FileKind.archive => _Slice.archives,
        FileKind.apk => _Slice.apks,
        _ => _Slice.other,
      };

  String get stringKey => switch (this) {
        _Slice.videos => 'fb_cat_videos',
        _Slice.images => 'fb_cat_images',
        _Slice.audio => 'fb_cat_audio',
        _Slice.documents => 'fb_cat_documents',
        _Slice.archives => 'fb_cat_archives',
        _Slice.apks => 'fb_cat_apks',
        _Slice.other => 'fb_cat_other',
      };

  /// Borrows the colour and icon of the kind that best represents the bucket,
  /// so a row here matches what the same file shows in a list.
  FileKind get _face => switch (this) {
        _Slice.videos => FileKind.video,
        _Slice.images => FileKind.image,
        _Slice.audio => FileKind.audio,
        _Slice.documents => FileKind.document,
        _Slice.archives => FileKind.archive,
        _Slice.apks => FileKind.apk,
        _Slice.other => FileKind.other,
      };

  Color get color => _face.color;
  IconData get icon => _face.icon;
}

class _Row extends StatelessWidget {
  const _Row({
    required this.color,
    required this.icon,
    required this.label,
    required this.value,
    required this.fraction,
    this.onTap,
  });

  final Color color;
  final IconData icon;
  final String label;
  final String value;
  final double fraction;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            height: 32,
            width: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 17, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppPalette.textH,
                        ),
                      ),
                    ),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppPalette.textB,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: fraction,
                    minHeight: 4,
                    backgroundColor: AppPalette.border,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              ],
            ),
          ),
          if (onTap != null)
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: AppPalette.textS,
            ),
        ],
      ),
    );

    if (onTap == null) return row;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: row,
    );
  }
}

/// One ring of arcs. A CustomPainter rather than a charting package, because
/// this is the only chart in the app and the download size is something the
/// project tracks.
class _DonutPainter extends CustomPainter {
  _DonutPainter({required this.slices, required this.ringColor});

  final List<({double value, Color color})> slices;
  final Color ringColor;

  @override
  void paint(Canvas canvas, Size size) {
    final total = slices.fold<double>(0, (s, e) => s + e.value);
    final stroke = size.width * 0.17;
    final rect = Rect.fromCircle(
      center: Offset(size.width / 2, size.height / 2),
      radius: (size.width - stroke) / 2,
    );

    canvas.drawCircle(
      rect.center,
      rect.width / 2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = ringColor,
    );

    if (total <= 0) return;

    // Twelve o'clock, clockwise, with a hairline gap so adjacent slices of
    // similar colour stay apart.
    var start = -math.pi / 2;
    const gap = 0.012;

    for (final slice in slices) {
      if (slice.value <= 0) continue;
      final sweep = (slice.value / total) * math.pi * 2;

      canvas.drawArc(
        rect,
        start + gap / 2,
        math.max(sweep - gap, 0.001),
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.butt
          ..color = slice.color,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.slices != slices || old.ringColor != ringColor;
}
