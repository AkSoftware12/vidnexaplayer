import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../NotifyListeners/LanguageProvider/home_strings.dart';
import '../../NotifyListeners/LanguageProvider/language_provider.dart';
import '../../Utils/app_palette.dart';
import '../file_browser/file_kind.dart';
import 'media_store.dart';
import 'media_thumb.dart';

/// Files that are byte-for-byte identical, grouped, biggest waste first.
///
/// Two passes, and the order matters. Files are bucketed by size first and only
/// buckets with more than one member are hashed — hashing everything would mean
/// reading every byte on the device, and size alone eliminates almost all of it
/// for free. The hashing itself happens on the platform side in 64 KB blocks;
/// see `MediaStorePlugin.hashes`.
class DuplicatesPage extends StatefulWidget {
  const DuplicatesPage({super.key, this.accent = const Color(0xFF6C4DF6)});

  final Color accent;

  @override
  State<DuplicatesPage> createState() => _DuplicatesPageState();
}

class _DuplicatesPageState extends State<DuplicatesPage> {
  static const MethodChannel _channel =
      MethodChannel('com.vidnexa.videoplayer/media_store');

  /// Files above this are compared on size alone and never hashed. Reading a
  /// 2 GB video to confirm what its size already strongly implies costs more
  /// than the answer is worth.
  static const int _maxHashBytes = 512 * 1024 * 1024;

  List<List<MediaFile>> _groups = const [];
  bool _loading = true;
  bool _cancelled = false;
  String _status = '';

  String get _lang => context.read<LocaleProvider>().locale.languageCode;
  String _t(String key) => HomeStrings.t(_lang, key);

  @override
  void initState() {
    super.initState();
    _scan();
  }

  @override
  void dispose() {
    _cancelled = true;
    super.dispose();
  }

  Future<void> _scan() async {
    setState(() {
      _loading = true;
      _status = '';
    });

    final files = await MediaStoreRepo.instance.files(MediaKind.all);
    if (!mounted || _cancelled) return;

    // Pass 1 — size buckets.
    final bySize = <int, List<MediaFile>>{};
    for (final f in files) {
      if (f.size <= 0 || f.size > _maxHashBytes) continue;
      bySize.putIfAbsent(f.size, () => []).add(f);
    }

    final candidates = <MediaFile>[];
    for (final bucket in bySize.values) {
      if (bucket.length > 1) candidates.addAll(bucket);
    }

    if (candidates.isEmpty) {
      setState(() {
        _groups = const [];
        _loading = false;
      });
      return;
    }

    setState(() {
      _status = _t('fb_working')
          .replaceAll('{done}', '0')
          .replaceAll('{total}', '${candidates.length}');
    });

    // Pass 2 — hash, in chunks so progress moves and a huge candidate set does
    // not sit in one platform call for a minute.
    final byHash = <String, List<MediaFile>>{};
    const chunk = 40;

    for (var i = 0; i < candidates.length; i += chunk) {
      if (!mounted || _cancelled) return;

      final slice = candidates.skip(i).take(chunk).toList();
      Map<Object?, Object?>? result;
      try {
        result = await _channel.invokeMapMethod<Object?, Object?>('hashes', {
          'uris': slice.map((f) => f.uri).toList(),
        });
      } on PlatformException catch (e) {
        debugPrint('hashes failed: $e');
      }

      for (final f in slice) {
        final hash = result?[f.uri] as String?;
        if (hash == null) continue;
        // Size is part of the key, so a collision across different sizes can
        // never merge two unrelated files.
        byHash.putIfAbsent('${f.size}:$hash', () => []).add(f);
      }

      if (!mounted || _cancelled) return;
      setState(() {
        _status = _t('fb_working')
            .replaceAll('{done}', '${(i + slice.length)}')
            .replaceAll('{total}', '${candidates.length}');
      });
    }

    final groups = byHash.values.where((g) => g.length > 1).toList()
      ..sort(
        (a, b) => (b.first.size * (b.length - 1))
            .compareTo(a.first.size * (a.length - 1)),
      );

    if (!mounted || _cancelled) return;
    setState(() {
      _groups = groups;
      _loading = false;
    });
  }

  int get _wasted => _groups.fold<int>(
        0,
        (sum, g) => sum + g.first.size * (g.length - 1),
      );

  @override
  Widget build(BuildContext context) {
    AppPalette.sync(context);

    return Scaffold(
      backgroundColor: AppPalette.surface,
      appBar: AppBar(
        backgroundColor: AppPalette.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppPalette.textH,
        titleSpacing: 0,
        title: Text(
          _t('fb_duplicates'),
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppPalette.textH,
          ),
        ),
      ),
      body: _loading
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: widget.accent),
                  const SizedBox(height: 14),
                  Text(
                    _status.isEmpty ? _t('fb_searching') : _status,
                    style: TextStyle(fontSize: 12, color: AppPalette.textS),
                  ),
                ],
              ),
            )
          : _groups.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.done_all_rounded,
                        size: 44,
                        color: AppPalette.textS,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _t('fb_no_duplicates'),
                        style: TextStyle(
                          fontSize: 13,
                          color: AppPalette.textS,
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: widget.accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        _t('fb_dupes_summary')
                            .replaceAll('{groups}', '${_groups.length}')
                            .replaceAll('{size}', formatBytes(_wasted)),
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppPalette.textH,
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
                        itemCount: _groups.length,
                        itemBuilder: (context, i) => _Group(
                          files: _groups[i],
                          accent: widget.accent,
                          countLabel: _t('fb_items_count'),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({
    required this.files,
    required this.accent,
    required this.countLabel,
  });

  final List<MediaFile> files;
  final Color accent;
  final String countLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppPalette.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppPalette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  height: 36,
                  width: 36,
                  child: MediaThumb(file: files.first, size: 128),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  files.first.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppPalette.textH,
                  ),
                ),
              ),
              Text(
                '${files.length}× ${formatBytes(files.first.size)}',
                style: TextStyle(fontSize: 10.5, color: AppPalette.textS),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Every copy is listed, and the first is marked as the one to keep.
          // Deliberately read-only: deleting a MediaStore file another app owns
          // needs a system consent dialog per file, and a "delete all
          // duplicates" that half-works is worse than one that does not exist.
          for (var i = 0; i < files.length; i++)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Icon(
                    i == 0 ? Icons.star_rounded : Icons.copy_all_rounded,
                    size: 13,
                    color: i == 0
                        ? const Color(0xFFF59E0B)
                        : AppPalette.textS,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      files[i].path.isEmpty ? files[i].name : files[i].path,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        color: AppPalette.textS,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
