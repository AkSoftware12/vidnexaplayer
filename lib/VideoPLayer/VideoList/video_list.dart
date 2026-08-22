import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path/path.dart' as path;
import 'package:provider/provider.dart';
import '../../NotifyListeners/LanguageProvider/language_provider.dart';
import '../../NotifyListeners/LanguageProvider/video_strings.dart';
import '../../Utils/color.dart';
import '../../Utils/video_thumb.dart';
import '../../ads/app_open_ad_manager.dart';
import '../../main.dart';
import '../4kPlayer/4k_player.dart';
import '../4kPlayer/FlotingVideo/floting_video.dart';



class VideoFolderScreen extends StatefulWidget {
  final String folderName;
  final AssetPathEntity videos;

  const VideoFolderScreen({
    super.key,
    required this.folderName,
    required this.videos,
  });

  @override
  _VideoFolderScreenState createState() => _VideoFolderScreenState();
}

class _VideoFolderScreenState extends State<VideoFolderScreen>
    with SingleTickerProviderStateMixin {

  // Singleton — initialised once in main.dart, never disposed by a screen.
  final appOpenManager = AppOpenAdManager();

  bool _isGridView = false;

  // Cached at the top of build() (context.watch) so language changes trigger
  // a rebuild; also reused from callbacks (via _t) outside build() where
  // `context.watch` cannot be called.
  String _lang = 'en';
  String _t(String key) => VideoStrings.t(_lang, key);

  List<AssetEntity> _photos = [];
  bool _isLoading = true;
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _loadPhotos();
  }

  @override
  void dispose() {
    // `super.dispose()` must come LAST — the old order tore down the State
    // first and then touched it, which trips a framework assertion.
    _controller.dispose();
    super.dispose();
  }

  /// Loads the whole folder in pages instead of silently stopping at 1000
  /// items, which used to hide videos in large folders.
  Future<void> _loadPhotos() async {
    try {
      const int pageSize = 200;
      final total = await widget.videos.assetCountAsync;

      final List<AssetEntity> photos = [];
      for (int start = 0; start < total; start += pageSize) {
        final end = (start + pageSize) > total ? total : start + pageSize;
        photos.addAll(
          await widget.videos.getAssetListRange(start: start, end: end),
        );
        if (!mounted) return;
      }

      if (!mounted) return;
      setState(() {
        _photos = photos;
        _isLoading = false;
      });
      _controller.forward();
    } catch (e) {
      debugPrint('Failed to load folder videos: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  /// Deletes [videoPath] from the device and refreshes the list.
  ///
  /// Returns `true` when the delete succeeded. Callers must NOT also remove the
  /// item themselves — `_loadPhotos()` already rebuilds the list, and the old
  /// extra `_photos.removeAt(index)` dropped a second, unrelated video.
  Future<bool> _onPhotoDeleted(String videoPath) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await deleteVideoFromDevice(context, videoPath);
      await _loadPhotos();

      if (!mounted) return true;
      messenger.showSnackBar(
        SnackBar(content: Text(_t('video_delete_success'))),
      );
      return true;
    } catch (e) {
      if (!mounted) return false;
      messenger.showSnackBar(
        SnackBar(content: Text('${_t('video_delete_failed_prefix')} $e')),
      );
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    _lang = context.watch<LocaleProvider>().locale.languageCode;
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(
          '${widget.folderName} ${'(${_photos.length.toString()})'}',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 2,
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _isGridView = true;
                    });
                  },
                  child: Container(
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _isGridView ? ColorSelect.maineColor2 : Colors.grey.shade200,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(10),
                        bottomLeft: Radius.circular(10),
                      ),
                    ),
                    child: Icon(
                      Icons.grid_view,
                      color: _isGridView ? Colors.white : Colors.black87,
                      size: 20,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _isGridView = false;
                    });
                  },
                  child: Container(
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: !_isGridView ? ColorSelect.maineColor2 : Colors.grey.shade200,
                      borderRadius: BorderRadius.only(
                        topRight: Radius.circular(10),
                        bottomRight: Radius.circular(10),
                      ),
                    ),
                    child: Icon(
                      Icons.list,
                      color: !_isGridView ? Colors.white : Colors.black87,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      // `_isLoading` was tracked but never rendered, so a big folder looked
      // like an empty one until the scan finished.
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _photos.isEmpty
              ? Center(child: Text(_t('video_no_videos_in_folder')))
              : FadeTransition(
                  opacity: _fadeAnimation,
                  child: _isGridView ? _buildGridView() : _buildListView(),
                ),
      bottomNavigationBar: appOpenManager.bannerWidget(),
    );
  }

  Widget _buildListView() {
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _photos.length,
      itemBuilder: (context, index) {
        return PhotoTile(
          photo: _photos[index],
          photos: _photos,
          initialIndex: index,
          onInfo: () {
            _showVideoInfo(_photos[index]);
          },
          onDelete: () async {
            final file = await _photos[index].file;
            if (!mounted) return;
            if (file == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(_t('video_unable_access_file'))),
              );
              return;
            }
            // _onPhotoDeleted reloads the list itself — do not remove again.
            await _onPhotoDeleted(file.path);
          },
          onShare: () async {
            // Wait for file to load
            final file = await _photos[index].file;
            if (file != null) {
              _shareVideo(context, file.path);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(_t('video_unable_access_file'))),
              );
            }
          },
        );

      },

    );
  }

  Widget _buildGridView() {
    return GridView.builder(
      padding: EdgeInsets.all(5.sp),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.95,
      ),
      itemCount: _photos.length,
      itemBuilder: (context, index) {
        return GridviewList(
          photo: _photos[index],
          photos: _photos,
          initialIndex: index,
          onDelete: () async {
            final file = await _photos[index].file;
            if (!mounted) return;
            if (file == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(_t('video_unable_access_file'))),
              );
              return;
            }
            // _onPhotoDeleted reloads the list itself — do not remove again.
            await _onPhotoDeleted(file.path);
          },

          onInfo: () {
            _showVideoInfo(_photos[index]);

          },
          onShare: () async {
            // Wait for file to load
            final file = await _photos[index].file;
            if (file != null) {
              _shareVideo(context, file.path);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(_t('video_unable_access_file'))),
              );
            }
          },
        );
      },
    );
  }

  Future<void> deleteVideoFromDevice(
    BuildContext context,
    String videoPath,
  ) async {
    // 1️⃣ Permission check
    final permission = await PhotoManager.requestPermissionExtend();
    if (!context.mounted) return;
    if (!permission.isAuth) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_t('video_permission_denied')),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // 2️⃣ Confirmation dialog
    bool? confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            title: Text(_t('video_delete_dialog_title')),
            content: Text(_t('video_delete_dialog_content')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  _t('common_cancel'),
                  style: const TextStyle(color: Colors.teal),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(
                  _t('common_delete'),
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );

    if (confirm != true) return;
    if (!context.mounted) return;

    // 3️⃣ Fetch all video asset paths
    final paths = await PhotoManager.getAssetPathList(type: RequestType.video);

    for (final p in paths) {
      final int total =
          await p.assetCountAsync; // ✅ Correct way to get asset count
      final assets = await p.getAssetListRange(start: 0, end: total);

      for (final asset in assets) {
        final file = await asset.file;
        if (file != null && file.path == videoPath) {
          if (!context.mounted) return;
          try {
            final result = await PhotoManager.editor.deleteWithIds([asset.id]);
            if (!context.mounted) return;
            if (result.isNotEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(_t('video_deleted_from_device')),
                  backgroundColor: Colors.green,
                  duration: const Duration(seconds: 2),
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(_t('video_delete_failed_generic')),
                  backgroundColor: Colors.red,
                ),
              );
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${_t('video_delete_error_prefix')} $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
          return; // Exit once video is deleted
        }
      }
    }
  }

  Future<void> _shareVideo(BuildContext context, String videoPath) async {
    try {

      final file = File(videoPath);
      if (!await file.exists()) {
        // No loading dialog/route is pushed before this method is called
        // (see the onShare callers above) — this used to pop the actual
        // VideoFolderScreen itself instead of just showing the snackbar.
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_t('video_file_not_found'))),
        );
        return;
      }
      if (!context.mounted) return;

      final ext = path.extension(videoPath).replaceFirst('.', '').toLowerCase();
      final shareFile = XFile(videoPath, mimeType: 'video/$ext');

      // small artificial delay (ensure dialog paints)
      await Future.delayed(const Duration(milliseconds: 300));

      // share_plus 11: the static `Share.*` helpers are deprecated in favour of
      // the `SharePlus.instance` + `ShareParams` API.
      await SharePlus.instance.share(
        ShareParams(
          files: [shareFile],
          text: '🎥 Watch this video: ${path.basename(videoPath)}',
        ),
      );

    } catch (e, st) {
      debugPrint('Error sharing: $e\n$st');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_t('video_share_failed'))),
        );
      }
    } finally {
      // Navigator.pop(context); // hide loader
    }
  }

  Future<void> _showVideoInfo(AssetEntity photo) async {
    // `photo` is always a local-gallery AssetEntity here (this screen is fed
    // from PhotoManager, never a network stream), so `photo.file` is a
    // Future<File?> whose `.toString()` — e.g. "Instance of 'Future<File?>'"
    // — can never actually start with "http". This "network video" guard
    // never triggered; removed rather than left as dead/misleading code.
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          backgroundColor: Colors.white,
          title: Row(
            children: [
              Icon(Icons.video_file, color: ColorSelect.maineColor, size: 30),
              SizedBox(width: 8),
              Text(
                _t('video_info_title'),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: ColorSelect.maineColor,
                ),
              ),
            ],
          ),
          content: FutureBuilder<File?>(
            future: photo.file,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data == null) {
                return Text(
                  _t('video_info_file_not_found'),
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                );
              }

              final file = snapshot.data!;
              final size = (file.lengthSync() / (1024 * 1024));
              final duration = photo.videoDuration;
              final durationText = _formatDuration(duration);

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoRow(_t('video_info_name'), photo.title ?? _t('video_info_unknown')),
                  SizedBox(height: 12),
                  _buildInfoRow(_t('video_info_path'), file.path),
                  SizedBox(height: 12),
                  _buildInfoRow(_t('video_info_size'), '${size.toStringAsFixed(2)} MB'),
                  SizedBox(height: 12),
                  _buildInfoRow(_t('video_info_duration'), durationText),
                  SizedBox(height: 12),
                  _buildInfoRow(
                    // `createDateTime` is non-nullable — the `?.`/`??` never fired.
                    _t('video_info_last_modified'),
                    photo.createDateTime.toString().split('.').first,
                  ),
                ],
              );
            },
          ),



          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: ColorSelect.maineColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _t('common_ok'),
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: Colors.grey[600],
          ),
        ),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(fontWeight: FontWeight.w400, color: Colors.black),
        ),
      ],
    );
  }
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "${duration.inHours > 0 ? '${twoDigits(duration.inHours)}:' : ''}$minutes:$seconds";
  }

}

class PhotoTile extends StatelessWidget {
  final AssetEntity photo;
  final List<AssetEntity> photos;
  final int initialIndex;
  final VoidCallback onDelete;
  final VoidCallback onInfo;
  final VoidCallback onShare;

  const PhotoTile({
    super.key,
    required this.photo,
    required this.photos,
    required this.initialIndex,
    required this.onDelete,
    required this.onInfo,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LocaleProvider>().locale.languageCode;
    String t(String key) => VideoStrings.t(lang, key);
    return GestureDetector(
      onTap: () {
        appOpenManager.showInterstitialIfAllowed(
          onContinue: () {
            FloatingVideoManager.hide(); // ya close/remove/stop jo method tumhare manager me ho
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => FullScreenVideoPlayerFixed(
                  videos: photos,
                  initialIndex: initialIndex,
                ),
              ),
            );
          },
        );
      },
      child: Card(
        elevation: 3,
        margin: EdgeInsets.symmetric(vertical: 6.sp, horizontal: 8.sp),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.sp),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 6.sp, vertical: 6.sp),
          child: Row(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10.sp),
                    child: VideoThumb(
                      // Keyed by asset so ListView recycling swaps the image
                      // instead of showing the previous row's frame.
                      key: ValueKey(photo.id),
                      asset: photo,
                      width: 100.sp,
                      height: 70.sp,
                    ),
                  ),
                  Icon(
                    Icons.play_circle_fill,
                    color: Colors.white.withValues(alpha: 0.8),
                    size: 28.sp,
                  ),
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      // `videoDuration` comes straight off the already-loaded
                      // AssetEntity; the old code awaited `photo.file` (which
                      // materialises the whole file from MediaStore) purely to
                      // decide whether to show it.
                      child: Text(
                        _formatDuration(photo.videoDuration),
                        style: GoogleFonts.poppins(
                          fontSize: 9.sp,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(width: 10.sp),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      photo.title ?? t('video_untitled'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 5.sp),
                    _PhotoTileFileInfo(photo: photo),
                  ],
                ),
              ),
              GestureDetector(
                onTapDown: (details) {
                  showMenu(
                    context: context,
                    position: RelativeRect.fromLTRB(
                      details.globalPosition.dx,
                      details.globalPosition.dy,
                      MediaQuery.of(context).size.width -
                          details.globalPosition.dx,
                      MediaQuery.of(context).size.height,
                    ),
                    items: [
                      _buildMenuItem(Icons.play_circle, "play", t('common_play'), Colors.blue),
                      _buildMenuItem(Icons.delete, "delete", t('common_delete'), Colors.red),
                      _buildMenuItem(Icons.info, "info", t('common_info'), Colors.teal),
                      _buildMenuItem(Icons.share, "share", t('common_share'), Colors.black54),
                    ],
                  ).then((value) async {
                    if (value == "play") {
                      appOpenManager.showInterstitialIfAllowed(
                        onContinue: () {
                          FloatingVideoManager.hide(); // ya close/remove/stop jo method tumhare manager me ho

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => FullScreenVideoPlayerFixed(
                                videos: photos,
                                initialIndex: initialIndex,
                              ),
                            ),
                          );
                        },
                      );

                    } else if (value == "delete") {
                      onDelete();
                    } else if (value == "info") {
                      onInfo();
                    } else if (value == "share") {
                      onShare();

                    }
                  });
                },
                child: Padding(
                  padding: EdgeInsets.only(left: 4.sp),
                  child: Icon(
                    Icons.more_vert,
                    color: Colors.black87,
                    size: 18.sp,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  PopupMenuItem<String> _buildMenuItem(
    IconData icon,
    String value,
    String label,
    Color color,
  ) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, color: color, size: 20.sp),
          SizedBox(width: 8),
          Text(label, style: GoogleFonts.poppins(fontSize: 12.sp)),
        ],
      ),
    );
  }



  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "${duration.inHours > 0 ? '${twoDigits(duration.inHours)}:' : ''}$minutes:$seconds";
  }
}

/// Shows a video tile's file size + duration.
///
/// The old inline version built a fresh `photo.file` Future (and did
/// `existsSync()`/`lengthSync()` disk I/O) directly inside `PhotoTile.build()`,
/// so every rebuild of every visible tile — every scroll frame — re-resolved
/// and re-stat'd the file. `_FileSizeBadge` elsewhere in this file already
/// fixed the same anti-pattern for the grid view; this mirrors it for the
/// list view.
class _PhotoTileFileInfo extends StatefulWidget {
  const _PhotoTileFileInfo({required this.photo});

  final AssetEntity photo;

  /// asset id -> size in MB (null == missing/unavailable).
  static final Map<String, double?> _cache = <String, double?>{};

  @override
  State<_PhotoTileFileInfo> createState() => _PhotoTileFileInfoState();
}

class _PhotoTileFileInfoState extends State<_PhotoTileFileInfo> {
  double? _sizeMB;
  bool _resolved = false;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(_PhotoTileFileInfo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photo.id != widget.photo.id) {
      _resolved = false;
      _resolve();
    }
  }

  Future<void> _resolve() async {
    final id = widget.photo.id;

    if (_PhotoTileFileInfo._cache.containsKey(id)) {
      final cached = _PhotoTileFileInfo._cache[id];
      if (mounted) setState(() {
        _sizeMB = cached;
        _resolved = true;
      });
      return;
    }

    double? size;
    try {
      final file = await widget.photo.file;
      if (file != null && await file.exists()) {
        size = (await file.length()) / (1024 * 1024);
      }
    } catch (e) {
      debugPrint('Error reading file size: $e');
      size = null;
    }

    _PhotoTileFileInfo._cache[id] = size;
    if (!mounted) return;
    setState(() {
      _sizeMB = size;
      _resolved = true;
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "${duration.inHours > 0 ? '${twoDigits(duration.inHours)}:' : ''}$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LocaleProvider>().locale.languageCode;
    final sizeMB = _sizeMB ?? 0;
    final duration = widget.photo.videoDuration;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          !_resolved
              ? ''
              : (sizeMB > 0 ? '${sizeMB.toStringAsFixed(2)} MB' : VideoStrings.t(lang, 'video_file_missing')),
          style: GoogleFonts.poppins(
            fontSize: 10.sp,
            color: sizeMB > 0 ? Colors.grey[600] : Colors.redAccent,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          _formatDuration(duration),
          style: GoogleFonts.poppins(
            fontSize: 10.sp,
            color: Colors.grey[700],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class GridviewList extends StatelessWidget {
  final AssetEntity photo;
  final List<AssetEntity> photos;
  final int initialIndex;
  final VoidCallback onDelete;
  final VoidCallback onInfo;
  final VoidCallback onShare;



  const GridviewList({
    super.key,
    required this.photo,
    required this.photos,
    required this.initialIndex,
    required this.onDelete, required this.onInfo, required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LocaleProvider>().locale.languageCode;
    String t(String key) => VideoStrings.t(lang, key);
    return GestureDetector(
      onTap: () {
        appOpenManager.showInterstitialIfAllowed(
          onContinue: () {
            FloatingVideoManager.hide(); // ya close/remove/stop jo method tumhare manager me ho
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => FullScreenVideoPlayerFixed(
                  videos: photos,
                  initialIndex: initialIndex,
                ),
              ),
            );
          },
        );
      },
      child: Card(
        elevation: 3,
        margin: EdgeInsets.symmetric(vertical: 5.sp, horizontal: 5.sp),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(5.sp),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 0.sp, vertical: 0.sp),
          child: Column(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(5.sp),
                      topRight: Radius.circular(5.sp),
                    ),
                    child: VideoThumb(
                      key: ValueKey(photo.id),
                      asset: photo,
                      width: double.infinity,
                      height: 140.sp,
                    ),
                  ),
                  Icon(
                    Icons.play_circle_fill,
                    color: Colors.white.withValues(alpha: 0.8),
                    size: 28.sp,
                  ),
                  // --- File size, bottom left ---
                  Positioned(
                    bottom: 4,
                    left: 4,
                    child: _FileSizeBadge(asset: photo),
                  ),
                  // --- Duration bottom right ---
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _formatDuration(photo.videoDuration),
                        style: GoogleFonts.poppins(
                          fontSize: 9.sp,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 5.sp,),
              Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding:  EdgeInsets.all(5.sp),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            photo.title ?? t('video_untitled'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTapDown: (details) {
                      showMenu(
                        context: context,
                        position: RelativeRect.fromLTRB(
                          details.globalPosition.dx,
                          details.globalPosition.dy,
                          MediaQuery.of(context).size.width -
                              details.globalPosition.dx,
                          MediaQuery.of(context).size.height,
                        ),
                        items: [
                          _buildMenuItem(Icons.play_circle, "play", t('common_play'), Colors.blue),
                          _buildMenuItem(Icons.delete, "delete", t('common_delete'), Colors.red),
                          _buildMenuItem(Icons.info, "info", t('common_info'), Colors.teal),
                          _buildMenuItem(Icons.share, "share", t('common_share'), Colors.black54),
                        ],
                      ).then((value) async {
                        if (value == "play") {
                          appOpenManager.showInterstitialIfAllowed(
                            onContinue: () {
                              FloatingVideoManager.hide(); // ya close/remove/stop jo method tumhare manager me ho

                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => FullScreenVideoPlayerFixed(
                                    videos: photos,
                                    initialIndex: initialIndex,
                                  ),
                                ),
                              );
                            },
                          );
                        } else if (value == "delete") {
                          onDelete();
                        } else if (value == "info") {
                          onInfo();
                        } else if (value == "share") {
                          onShare();
                        }
                      });
                    },
                    child: Padding(
                      padding: EdgeInsets.only(left: 4.sp),
                      child: Icon(
                        Icons.more_vert,
                        color: Colors.black87,
                        size: 18.sp,
                      ),
                    ),
                  ),

                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  PopupMenuItem<String> _buildMenuItem(
      IconData icon, String value, String label, Color color) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, color: color, size: 20.sp),
          SizedBox(width: 8),
          Text(label, style: GoogleFonts.poppins(fontSize: 12.sp)),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "${duration.inHours > 0 ? '${twoDigits(duration.inHours)}:' : ''}$minutes:$seconds";
  }
}

/// Shows a video's file size.
///
/// The old inline version created its `photo.file` future inside `build()` and
/// then called `lengthSync()` — synchronous disk I/O on the UI thread, repeated
/// on every rebuild of every visible tile. That is a direct contributor to the
/// dropped-frame storms in logcat.
class _FileSizeBadge extends StatefulWidget {
  const _FileSizeBadge({required this.asset});

  final AssetEntity asset;

  /// asset id -> size in bytes (null == unavailable).
  static final Map<String, int?> _cache = <String, int?>{};

  @override
  State<_FileSizeBadge> createState() => _FileSizeBadgeState();
}

class _FileSizeBadgeState extends State<_FileSizeBadge> {
  int? _bytes;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(_FileSizeBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.asset.id != widget.asset.id) _resolve();
  }

  Future<void> _resolve() async {
    final id = widget.asset.id;

    if (_FileSizeBadge._cache.containsKey(id)) {
      final cached = _FileSizeBadge._cache[id];
      if (mounted) setState(() => _bytes = cached);
      return;
    }

    int? size;
    try {
      final file = await widget.asset.file;
      // `length()` is async — unlike the old `lengthSync()`.
      if (file != null) size = await file.length();
    } catch (_) {
      size = null;
    }

    _FileSizeBadge._cache[id] = size;
    if (!mounted) return;
    setState(() => _bytes = size);
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;
    if (bytes == null) return const SizedBox.shrink();

    final mb = bytes / (1024 * 1024);
    final label = mb >= 1024
        ? '${(mb / 1024).toStringAsFixed(2)} GB'
        : '${mb.toStringAsFixed(2)} MB';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: ColorSelect.maineColor2,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9.sp,
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

