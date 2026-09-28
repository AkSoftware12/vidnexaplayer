import 'package:material_ui/material_ui.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../NotifyListeners/LanguageProvider/home_strings.dart';
import '../../NotifyListeners/LanguageProvider/language_provider.dart';
import '../../Utils/app_palette.dart';
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
    final cached = MediaStoreRepo.instance.cached(widget.kind);
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

  Future<void> _open(MediaFile file) async {
    final messenger = ScaffoldMessenger.of(context);
    final opened = await MediaStoreRepo.instance.openExternally(file);
    if (!opened && mounted) {
      messenger.showSnackBar(
        SnackBar(content: Text(_t('fb_open_failed'))),
      );
    }
  }

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

  Widget _listView(List<MediaFile> rows) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      itemCount: rows.length,
      // Constant extent: the list knows every row is 68px tall, so it can jump
      // straight to an offset instead of measuring its way there. On a few
      // thousand files that is the difference between a smooth fling and one
      // that hitches.
      itemBuilder: (context, i) => _Tile(
        file: rows[i],
        accent: widget.accent,
        onTap: () => _open(rows[i]),
      ),
      separatorBuilder: (_, __) => const SizedBox(height: 6),
    );
  }

  Widget _gridView(List<MediaFile> rows) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
      ),
      itemCount: rows.length,
      itemBuilder: (context, i) => _Cell(
        file: rows[i],
        onTap: () => _open(rows[i]),
      ),
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
