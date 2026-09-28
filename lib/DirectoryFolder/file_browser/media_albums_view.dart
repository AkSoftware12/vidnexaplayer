import 'package:material_ui/material_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../Utils/app_palette.dart';
import '../../Utils/video_thumb.dart';
import '../../VideoPLayer/4kPlayer/4k_player.dart';
import '../directory_folder.dart' show FullScreenImageViewer;

/// Album (folder) list for one media type, read through MediaStore.
///
/// This is the half of the browser that needs no folder pick and no
/// All-files-access: `photo_manager` reads MediaStore, which the granular
/// `READ_MEDIA_VIDEO` / `READ_MEDIA_IMAGES` grants already cover on Android 13+
/// (and `READ_EXTERNAL_STORAGE` covers below that). MediaStore also groups
/// assets by their real on-disk folder, so the user still sees "Movies",
/// "WhatsApp Video", "Camera" — folder browsing in everything but name, minus
/// the permission that would put the Play listing at risk.
class MediaAlbumsView extends StatefulWidget {
  const MediaAlbumsView({
    super.key,
    required this.type,
    required this.accent,
    required this.emptyLabel,
    required this.permissionLabel,
    required this.grantLabel,
    required this.itemsSuffix,
  });

  final RequestType type;
  final Color accent;
  final String emptyLabel;
  final String permissionLabel;
  final String grantLabel;

  /// e.g. "videos" / "photos" — appended to the per-album count.
  final String itemsSuffix;

  @override
  State<MediaAlbumsView> createState() => _MediaAlbumsViewState();
}

class _MediaAlbumsViewState extends State<MediaAlbumsView> {
  List<_Album> _albums = const [];
  bool _loading = true;
  bool _denied = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final state = await PhotoManager.requestPermissionExtend();
      if (!mounted) return;
      if (!state.isAuth && !state.hasAccess) {
        setState(() {
          _loading = false;
          _denied = true;
        });
        return;
      }

      final paths = await PhotoManager.getAssetPathList(
        type: widget.type,
        // `onlyAll: false` is what gives one entry per on-disk folder rather
        // than a single merged "Recent" bucket.
        onlyAll: false,
      );

      // Counting is a separate async call per album, so gather them together
      // instead of awaiting inside the list build.
      final albums = <_Album>[];
      for (final path in paths) {
        final count = await path.assetCountAsync;
        if (count == 0) continue;
        albums.add(_Album(path: path, count: count));
      }
      albums.sort((a, b) => b.count.compareTo(a.count));

      if (!mounted) return;
      setState(() {
        _albums = albums;
        _loading = false;
        _denied = false;
      });
    } catch (_) {
      // A MediaStore hiccup must not take the tab down; an empty list renders
      // the same "nothing here" state as a genuinely empty library.
      if (!mounted) return;
      setState(() {
        _albums = const [];
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    AppPalette.sync(context);

    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_denied) {
      return _Message(
        icon: Icons.perm_media_outlined,
        text: widget.permissionLabel,
        actionLabel: widget.grantLabel,
        accent: widget.accent,
        onAction: () async {
          await PhotoManager.openSetting();
          await _load();
        },
      );
    }

    if (_albums.isEmpty) {
      return _Message(
        icon: Icons.folder_off_outlined,
        text: widget.emptyLabel,
        accent: widget.accent,
      );
    }

    return RefreshIndicator(
      color: widget.accent,
      onRefresh: _load,
      child: ListView.separated(
        padding: EdgeInsets.fromLTRB(12.w, 10.h, 12.w, 24.h),
        itemCount: _albums.length,
        separatorBuilder: (_, __) => SizedBox(height: 6.h),
        itemBuilder: (context, i) => _AlbumTile(
          album: _albums[i],
          accent: widget.accent,
          itemsSuffix: widget.itemsSuffix,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              settings: const RouteSettings(name: 'MediaAlbumGridScreen'),
              builder: (_) => MediaAlbumGrid(
                album: _albums[i].path,
                title: _albums[i].path.name,
                isVideo: widget.type == RequestType.video,
                accent: widget.accent,
                emptyLabel: widget.emptyLabel,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Album {
  const _Album({required this.path, required this.count});
  final AssetPathEntity path;
  final int count;
}

class _AlbumTile extends StatelessWidget {
  const _AlbumTile({
    required this.album,
    required this.accent,
    required this.itemsSuffix,
    required this.onTap,
  });

  final _Album album;
  final Color accent;
  final String itemsSuffix;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppPalette.card,
      borderRadius: BorderRadius.circular(14.r),
      child: InkWell(
        borderRadius: BorderRadius.circular(14.r),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(10.sp),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12.r),
                child: SizedBox(
                  height: 52.sp,
                  width: 52.sp,
                  child: _Cover(album: album, accent: accent),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      album.path.name.isEmpty ? '/' : album.path.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                        color: AppPalette.textH,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      '${album.count} $itemsSuffix',
                      style: TextStyle(
                        fontSize: 10.5.sp,
                        color: AppPalette.textS,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  size: 18.sp, color: AppPalette.textS),
            ],
          ),
        ),
      ),
    );
  }
}

/// First asset of the album, rendered through the hardened [VideoThumb] so a
/// broken/deleted cover degrades to a placeholder instead of throwing.
class _Cover extends StatefulWidget {
  const _Cover({required this.album, required this.accent});
  final _Album album;
  final Color accent;

  @override
  State<_Cover> createState() => _CoverState();
}

class _CoverState extends State<_Cover> {
  AssetEntity? _asset;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final assets =
          await widget.album.path.getAssetListRange(start: 0, end: 1);
      if (!mounted || assets.isEmpty) return;
      setState(() => _asset = assets.first);
    } catch (_) {
      // Cover is decoration; failing to fetch it is not worth surfacing.
    }
  }

  @override
  Widget build(BuildContext context) {
    final asset = _asset;
    if (asset == null) {
      return Container(
        color: widget.accent.withValues(alpha: 0.12),
        child: Icon(Icons.folder_rounded,
            color: widget.accent, size: 24.sp),
      );
    }
    return VideoThumb(
      asset: asset,
      width: 52.sp,
      height: 52.sp,
      fit: BoxFit.cover,
    );
  }
}

/// Paged grid of one album's assets.
class MediaAlbumGrid extends StatefulWidget {
  const MediaAlbumGrid({
    super.key,
    required this.album,
    required this.title,
    required this.isVideo,
    required this.accent,
    required this.emptyLabel,
  });

  final AssetPathEntity album;
  final String title;
  final bool isVideo;
  final Color accent;
  final String emptyLabel;

  @override
  State<MediaAlbumGrid> createState() => _MediaAlbumGridState();
}

class _MediaAlbumGridState extends State<MediaAlbumGrid> {
  static const _pageSize = 80;

  final List<AssetEntity> _assets = [];
  final ScrollController _scroll = ScrollController();
  bool _loading = true;
  bool _loadingMore = false;
  bool _exhausted = false;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _loadMore();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients || _loadingMore || _exhausted) return;
    if (_scroll.position.pixels >
        _scroll.position.maxScrollExtent - 600) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    _loadingMore = true;
    try {
      final batch = await widget.album.getAssetListPaged(
        page: _page,
        size: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        _assets.addAll(batch);
        _page++;
        _exhausted = batch.length < _pageSize;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _exhausted = true;
        _loading = false;
      });
    } finally {
      _loadingMore = false;
    }
  }

  Future<void> _open(int index) async {
    final asset = _assets[index];

    if (widget.isVideo) {
      Navigator.push(
        context,
        MaterialPageRoute(
          settings: const RouteSettings(name: 'VideoPlayerScreen'),
          builder: (_) => FullScreenVideoPlayerFixed(
            videos: _assets,
            initialIndex: index,
          ),
        ),
      );
      return;
    }

    // Images need a real path for the in-app viewer. `file` can be null when
    // the row survives in MediaStore but the file behind it is gone.
    final file = await asset.file;
    if (!mounted || file == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: 'FullScreenImageViewer'),
        builder: (_) => FullScreenImageViewer(imagePath: file.path),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    AppPalette.sync(context);
    return Scaffold(
      backgroundColor: AppPalette.surface,
      appBar: AppBar(
        title: Text(
          widget.title.isEmpty ? '/' : widget.title,
          style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w800),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _assets.isEmpty
              ? _Message(
                  icon: Icons.image_not_supported_outlined,
                  text: widget.emptyLabel,
                  accent: widget.accent,
                )
              : GridView.builder(
                  controller: _scroll,
                  padding: EdgeInsets.all(10.sp),
                  gridDelegate:
                      SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8.sp,
                    mainAxisSpacing: 8.sp,
                  ),
                  itemCount: _assets.length,
                  itemBuilder: (context, i) => GestureDetector(
                    onTap: () => _open(i),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        VideoThumb(
                          asset: _assets[i],
                          fit: BoxFit.cover,
                          borderRadius: BorderRadius.circular(10.r),
                          placeholderIcon: widget.isVideo
                              ? Icons.movie_outlined
                              : Icons.image_outlined,
                        ),
                        if (widget.isVideo)
                          Positioned(
                            right: 5.sp,
                            bottom: 5.sp,
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 5.w, vertical: 1.h),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.65),
                                borderRadius: BorderRadius.circular(6.r),
                              ),
                              child: Text(
                                _duration(_assets[i]),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
    );
  }

  static String _duration(AssetEntity asset) {
    final seconds = asset.duration;
    if (seconds <= 0) return '';
    final d = Duration(seconds: seconds);
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return d.inHours > 0 ? '${d.inHours}:$m:$s' : '$m:$s';
  }
}

/// Shared empty / permission state.
class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.text,
    required this.accent,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String text;
  final Color accent;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 72.sp,
              width: 72.sp,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32.sp, color: accent),
            ),
            SizedBox(height: 16.h),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5.sp,
                height: 1.45,
                color: AppPalette.textS,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              SizedBox(height: 18.h),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: accent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                ),
                onPressed: onAction,
                child: Text(
                  actionLabel!,
                  style: TextStyle(
                      fontSize: 13.sp, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
