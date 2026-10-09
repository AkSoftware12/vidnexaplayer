import 'package:material_ui/material_ui.dart';
import 'package:on_audio_query_forked/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:provider/provider.dart';

import '../../LocalMusic/AUDIOCONTROLLER/global_audio_controller.dart';
import '../../LocalMusic/FullScreenPlayer/full_player_screen.dart';
import '../../VideoPLayer/4kPlayer/4k_player.dart';
import '../directory_folder.dart' show FullScreenImageViewer;

import '../../NotifyListeners/LanguageProvider/home_strings.dart';
import '../../NotifyListeners/LanguageProvider/language_provider.dart';
import '../../Utils/app_palette.dart';
import '../../ads/app_open_ad_manager.dart';
import '../../ads/list_native_ad.dart';
import '../file_browser/file_kind.dart';
import '../file_browser/file_ops.dart';
import 'media_store.dart';
import 'media_thumb.dart';

/// One screen, one kind of file.
///
/// Replaces the five-tab browser that came before it. The tabs meant every
/// entry point landed on the same screen and left the user to find the right
/// tab; each card in the File Manager now opens the thing it names, and nothing
/// else. There is no folder to pick first — [MediaStoreRepo] reads the index
/// the system already keeps.
class MediaListPage extends StatefulWidget {
  const MediaListPage({
    super.key,
    required this.kind,
    required this.title,
    this.accent = const Color(0xFF6C4DF6),
    this.recentOnly = false,
    this.folderPath,
    this.volume,
  });

  final MediaKind kind;
  final String title;
  final Color accent;

  /// Keeps only the last 30 days. Used by the Recent card, which is the same
  /// list with a filter rather than a screen of its own.
  final bool recentOnly;

  /// Restricts to exactly this folder — what tapping a row in [FolderListPage]
  /// opens.
  final String? folderPath;

  /// Reads only this volume (an SD card) when given. Needed alongside
  /// [folderPath] because paths are relative to their volume — `DCIM/Camera/`
  /// can exist on both the phone and the card.
  final String? volume;

  @override
  State<MediaListPage> createState() => _MediaListPageState();
}

class _MediaListPageState extends State<MediaListPage> {
  List<MediaFile> _all = const [];
  bool _loading = true;
  bool _denied = false;

  FileSort _sort = FileSort.dateDesc;
  bool _grid = false;
  String _query = '';
  bool _searchOpen = false;
  final TextEditingController _searchCtrl = TextEditingController();

  String get _lang => context.read<LocaleProvider>().locale.languageCode;
  String _t(String key) => HomeStrings.t(_lang, key);

  /// Photos and videos are recognised by sight, so they open as a grid;
  /// everything else is identified by its name and stays a list.
  bool get _gridByDefault =>
      widget.kind == MediaKind.image || widget.kind == MediaKind.video;

  @override
  void initState() {
    super.initState();
    _grid = _gridByDefault;

    // Paint from cache on the first frame when there is one. Re-entering a
    // screen then costs nothing, which is most of what "fast" means here.
    final cached = widget.volume == null
        ? MediaStoreRepo.instance.cached(widget.kind)
        : null;
    if (cached != null) {
      _all = cached;
      _loading = false;
    }
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({bool refresh = false}) async {
    if (!await _ensurePermission()) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _denied = true;
      });
      return;
    }

    final rows = await MediaStoreRepo.instance.files(
      widget.kind,
      refresh: refresh,
      volume: widget.volume,
    );
    if (!mounted) return;
    setState(() {
      _all = rows;
      _loading = false;
      _denied = false;
    });
  }

  /// MediaStore returns nothing for other apps' media without these, so it is
  /// asked for up front rather than showing a convincing empty state.
  Future<bool> _ensurePermission() async {
    final wanted = <Permission>[
      Permission.photos,
      Permission.videos,
      Permission.audio,
    ];

    for (final p in wanted) {
      if (await p.isGranted) return true;
    }

    final results = await wanted.request();
    return results.values.any((s) => s.isGranted || s.isLimited);
  }

  List<MediaFile> get _visible {
    var rows = _all;

    final folder = widget.folderPath;
    if (folder != null) {
      rows = rows.where((f) => f.path == folder).toList();
    }

    if (widget.recentOnly) {
      final cutoff = DateTime.now().subtract(const Duration(days: 30));
      rows = rows.where((f) => f.modified.isAfter(cutoff)).toList();
    }

    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      rows = rows.where((f) => f.name.toLowerCase().contains(q)).toList();
    }

    final sorted = [...rows];
    sortMediaFiles(sorted, _sort);
    return sorted;
  }

  /// Videos, photos and music open in the app's own player/viewer; only
  /// other kinds (and anything the in-app path cannot resolve) go to the
  /// system "Open with".
  /// Gives the interstitial its chance first. It is frequency-capped inside
  /// [AppOpenAdManager], so most taps open the file straight away.
  void _open(MediaFile file) {
    AppOpenAdManager().showInterstitialIfAllowed(
      onContinue: () {
        if (mounted) _openNow(file);
      },
    );
  }

  Future<void> _openNow(MediaFile file) async {
    final rows = _visible;
    final opened = switch (file.kind) {
          FileKind.video => await _openVideo(file, rows),
          FileKind.image => await _openImage(file),
          FileKind.audio => await _openAudio(file, rows),
          _ => false,
        } ||
        await _openOutside(file);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('fb_open_failed'))),
      );
    }
  }

  /// How many neighbours either side of the tapped video are resolved for
  /// next/previous. Each one is a platform call, so not the whole library.
  static const int _videoQueueRadius = 25;

  Future<bool> _openVideo(MediaFile file, List<MediaFile> rows) async {
    final videos = rows.where((f) => f.kind == FileKind.video).toList();
    final at = videos.indexWhere((f) => f.id == file.id);
    if (at < 0) return false;

    final start = (at - _videoQueueRadius).clamp(0, videos.length);
    final end = (at + _videoQueueRadius + 1).clamp(0, videos.length);
    final window = videos.sublist(start, end);

    final assets = await Future.wait(
      window.map((f) => AssetEntity.fromId(f.id.toString())),
    );
    final resolved = <AssetEntity>[];
    var initial = -1;
    for (var i = 0; i < window.length; i++) {
      final a = assets[i];
      if (a == null) continue;
      if (window[i].id == file.id) initial = resolved.length;
      resolved.add(a);
    }
    if (initial < 0 || !mounted) return false;

    Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: 'VideoPlayerScreen'),
        builder: (_) => FullScreenVideoPlayerFixed(
          videos: resolved,
          initialIndex: initial,
        ),
      ),
    );
    return true;
  }

  /// The in-app viewer needs a real path, which MediaStore never hands out;
  /// photo_manager resolves it from the same id.
  Future<bool> _openImage(MediaFile file) async {
    final asset = await AssetEntity.fromId(file.id.toString());
    final real = await asset?.file;
    if (real == null || !mounted) return false;

    Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: 'FullScreenImageViewer'),
        builder: (_) => FullScreenImageViewer(imagePath: real.path),
      ),
    );
    return true;
  }

  /// Queues every visible audio file so next/previous stay in this list,
  /// then opens the full player.
  Future<bool> _openAudio(MediaFile file, List<MediaFile> rows) async {
    final tracks = rows.where((f) => f.kind == FileKind.audio).toList();
    final at = tracks.indexWhere((f) => f.id == file.id);
    if (at < 0) return false;

    await GlobalAudioController().playSongs(tracks.map(_asSong).toList(), at);
    if (!mounted) return true;

    Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: 'MusicFullPlayerScreen'),
        builder: (_) => const FullPlayerScreen(),
      ),
    );
    return true;
  }

  /// A [SongModel] built from the MediaStore row. Files and Audio share the
  /// same `_id`, so artwork lookups by id still find the right track.
  static SongModel _asSong(MediaFile f) {
    final dot = f.name.lastIndexOf('.');
    final bare = dot > 0 ? f.name.substring(0, dot) : f.name;
    return SongModel({
      '_id': f.id,
      '_data': '',
      '_uri': 'content://media/external/audio/media/${f.id}',
      '_display_name': f.name,
      '_display_name_wo_ext': bare,
      '_size': f.size,
      'title': bare,
      'artist': null,
      'album': null,
      'duration': null,
      'date_modified': f.modified.millisecondsSinceEpoch ~/ 1000,
    });
  }

  Future<bool> _openOutside(MediaFile file) =>
      MediaStoreRepo.instance.openExternally(file);

  @override
  Widget build(BuildContext context) {
    AppPalette.sync(context);
    final rows = _visible;

    return Scaffold(
      backgroundColor: AppPalette.surface,
      appBar: AppBar(
        backgroundColor: AppPalette.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppPalette.textH,
        titleSpacing: 0,
        title: _searchOpen ? _searchField() : _titleBlock(rows.length),
        actions: [
          IconButton(
            tooltip: _t('fb_search_hint'),
            onPressed: () => setState(() {
              _searchOpen = !_searchOpen;
              if (!_searchOpen) {
                _query = '';
                _searchCtrl.clear();
              }
            }),
            icon: Icon(_searchOpen ? Icons.close_rounded : Icons.search_rounded),
          ),
          IconButton(
            tooltip: _grid ? _t('fb_view_list') : _t('fb_view_grid'),
            onPressed: () => setState(() => _grid = !_grid),
            icon: Icon(_grid ? Icons.view_list_rounded : Icons.grid_view_rounded),
          ),
          _sortMenu(),
        ],
      ),
      body: RefreshIndicator(
        color: widget.accent,
        onRefresh: () => _load(refresh: true),
        child: _body(rows),
      ),
    );
  }

  /// Rows shown before the native ad in list view: far enough down that the
  /// first thing seen is the files, close enough that the ad is seen at all.
  static const int _adAfterRows = 4;

  /// Grid cells before the ad — three full rows of three.
  static const int _adAfterCells = 9;

  Widget _titleBlock(int count) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          widget.title,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppPalette.textH,
          ),
        ),
        if (!_loading)
          Text(
            _t('fb_items_count').replaceAll('{count}', '$count'),
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 10.5,
              color: AppPalette.textS,
            ),
          ),
      ],
    );
  }

  Widget _searchField() {
    return TextField(
      controller: _searchCtrl,
      autofocus: true,
      style: TextStyle(fontSize: 14, color: AppPalette.textH),
      decoration: InputDecoration(
        isDense: true,
        border: InputBorder.none,
        hintText: _t('fb_search_hint'),
        hintStyle: TextStyle(fontSize: 14, color: AppPalette.textS),
      ),
      onChanged: (v) => setState(() => _query = v.trim()),
    );
  }

  Widget _sortMenu() {
    return PopupMenuButton<FileSort>(
      tooltip: _t('fb_sort'),
      color: AppPalette.card,
      icon: const Icon(Icons.sort_rounded),
      onSelected: (s) => setState(() => _sort = s),
      itemBuilder: (context) => [
        _sortItem(FileSort.dateDesc, 'fb_sort_date_desc'),
        _sortItem(FileSort.dateAsc, 'fb_sort_date_asc'),
        _sortItem(FileSort.nameAsc, 'fb_sort_name_asc'),
        _sortItem(FileSort.nameDesc, 'fb_sort_name_desc'),
        _sortItem(FileSort.sizeDesc, 'fb_sort_size_desc'),
        _sortItem(FileSort.sizeAsc, 'fb_sort_size_asc'),
      ],
    );
  }

  PopupMenuItem<FileSort> _sortItem(FileSort sort, String key) {
    final active = _sort == sort;
    return PopupMenuItem<FileSort>(
      value: sort,
      height: 40,
      child: Row(
        children: [
          Expanded(
            child: Text(
              _t(key),
              style: TextStyle(
                fontSize: 13,
                color: active ? widget.accent : AppPalette.textH,
                fontWeight: active ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
          if (active)
            Icon(Icons.check_rounded, size: 16, color: widget.accent),
        ],
      ),
    );
  }

  Widget _body(List<MediaFile> rows) {
    if (_loading) {
      return Center(
        child: CircularProgressIndicator(color: widget.accent),
      );
    }

    if (_denied) {
      return _message(
        Icons.lock_outline_rounded,
        _t('fb_media_permission'),
        action: _t('fb_grant'),
        onAction: () async {
          await openAppSettings();
          if (mounted) _load(refresh: true);
        },
      );
    }

    if (rows.isEmpty) {
      return _message(
        Icons.inbox_rounded,
        _query.isEmpty ? _t('fb_no_files') : _t('fb_no_matches'),
      );
    }

    return _grid ? _gridView(rows) : _listView(rows);
  }

  /// One native ad sits among the rows, after [_adAfterRows] of them (or at
  /// the end of a shorter list).
  Widget _listView(List<MediaFile> rows) {
    final adAt = rows.length < _adAfterRows ? rows.length : _adAfterRows;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      itemCount: rows.length + 1,
      itemBuilder: (context, i) {
        if (i == adAt) return const ListNativeAd();
        final file = rows[i > adAt ? i - 1 : i];
        return _Tile(
          file: file,
          accent: widget.accent,
          onTap: () => _open(file),
        );
      },
      separatorBuilder: (_, __) => const SizedBox(height: 6),
    );
  }

  /// The grid is split around a full-width ad after [_adAfterCells] cells:
  /// an ad squeezed into one thumbnail-sized cell would be unreadable.
  Widget _gridView(List<MediaFile> rows) {
    final split = rows.length < _adAfterCells ? rows.length : _adAfterCells;
    const delegate = SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 3,
      mainAxisSpacing: 6,
      crossAxisSpacing: 6,
    );

    Widget grid(int from, int to) => SliverGrid(
          gridDelegate: delegate,
          delegate: SliverChildBuilderDelegate(
            (context, i) => _Cell(
              file: rows[from + i],
              onTap: () => _open(rows[from + i]),
            ),
            childCount: to - from,
          ),
        );

    return CustomScrollView(
      // Pull-to-refresh needs the list to be scrollable even when short.
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
          sliver: grid(0, split),
        ),
        const SliverToBoxAdapter(
          child: ListNativeAd(padding: EdgeInsets.fromLTRB(10, 8, 10, 2)),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 24),
          sliver: grid(split, rows.length),
        ),
      ],
    );
  }

  Widget _message(
    IconData icon,
    String text, {
    String? action,
    VoidCallback? onAction,
  }) {
    // Scrollable so pull-to-refresh still works on an empty screen, which is
    // exactly when someone wants to retry.
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 120),
      children: [
        Icon(icon, size: 44, color: AppPalette.textS),
        const SizedBox(height: 14),
        Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            height: 1.45,
            color: AppPalette.textS,
          ),
        ),
        if (action != null && onAction != null) ...[
          const SizedBox(height: 18),
          Center(
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: widget.accent,
                foregroundColor: Colors.white,
              ),
              onPressed: onAction,
              child: Text(action),
            ),
          ),
        ],
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.file, required this.accent, required this.onTap});

  final MediaFile file;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppPalette.card,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  height: 44,
                  width: 44,
                  child: MediaThumb(file: file, size: 128),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      file.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppPalette.textH,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        formatBytes(file.size),
                        if (file.folderName.isNotEmpty) file.folderName,
                      ].where((s) => s.isNotEmpty).join('  ·  '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10.5, color: AppPalette.textS),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.open_in_new_rounded,
                size: 17,
                color: AppPalette.textS,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.file, required this.onTap});

  final MediaFile file;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppPalette.raised,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            MediaThumb(file: file, size: 256),
            if (file.kind == FileKind.video)
              const Center(
                child: Icon(
                  Icons.play_circle_fill_rounded,
                  size: 34,
                  color: Colors.white70,
                ),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(6, 10, 6, 4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.7),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Text(
                  formatBytes(file.size),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
