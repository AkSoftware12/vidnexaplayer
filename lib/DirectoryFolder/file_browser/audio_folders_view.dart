import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:on_audio_query_forked/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../LocalMusic/AUDIOCONTROLLER/global_audio_controller.dart';
import '../../Utils/app_palette.dart';
import 'file_kind.dart';

/// Music grouped by the folder each track actually sits in.
///
/// Same trade as [MediaAlbumsView]: `on_audio_query` reads MediaStore, so the
/// `READ_MEDIA_AUDIO` grant the app already asks for on the onboarding screen
/// is enough. Folder grouping is done here in Dart from `SongModel.data`,
/// which is the file's real path — so the user browses "Music", "Downloads",
/// "WhatsApp Audio" without the app needing All-files access to walk them.
///
/// Note this only ever *reads* the permission status. Requesting through
/// `on_audio_query` parks a result callback on the Activity that crashes the
/// app if it is recreated while the dialog is up — see
/// `AudioScannerDatasource.hasPermission`.
class AudioFoldersView extends StatefulWidget {
  const AudioFoldersView({
    super.key,
    required this.accent,
    required this.emptyLabel,
    required this.permissionLabel,
    required this.grantLabel,
    required this.itemsSuffix,
  });

  final Color accent;
  final String emptyLabel;
  final String permissionLabel;
  final String grantLabel;
  final String itemsSuffix;

  @override
  State<AudioFoldersView> createState() => _AudioFoldersViewState();
}

class _AudioFoldersViewState extends State<AudioFoldersView> {
  final OnAudioQuery _query = OnAudioQuery();

  List<_AudioFolder> _folders = const [];
  bool _loading = true;
  bool _denied = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<bool> _hasPermission() async {
    try {
      if (await Permission.audio.isGranted) return true;
      if (await Permission.storage.isGranted) return true;
      return false;
    } catch (_) {
      return true;
    }
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);

    if (!await _hasPermission()) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _denied = true;
      });
      return;
    }

    try {
      final songs = await _query.querySongs(
        orderType: OrderType.ASC_OR_SMALLER,
        uriType: UriType.EXTERNAL,
        ignoreCase: true,
      );

      final grouped = <String, List<SongModel>>{};
      for (final song in songs) {
        final path = song.data;
        final cut = path.lastIndexOf('/');
        if (cut <= 0) continue;
        grouped.putIfAbsent(path.substring(0, cut), () => []).add(song);
      }

      final folders = grouped.entries
          .map((e) => _AudioFolder(path: e.key, songs: e.value))
          .toList()
        ..sort((a, b) => b.songs.length.compareTo(a.songs.length));

      if (!mounted) return;
      setState(() {
        _folders = folders;
        _loading = false;
        _denied = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _folders = const [];
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    AppPalette.sync(context);

    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_denied) {
      return _centered(
        Icons.library_music_outlined,
        widget.permissionLabel,
        actionLabel: widget.grantLabel,
        onAction: () async {
          await openAppSettings();
          await _load();
        },
      );
    }

    if (_folders.isEmpty) {
      return _centered(Icons.music_off_outlined, widget.emptyLabel);
    }

    return RefreshIndicator(
      color: widget.accent,
      onRefresh: _load,
      child: ListView.separated(
        padding: EdgeInsets.fromLTRB(12.w, 10.h, 12.w, 24.h),
        itemCount: _folders.length,
        separatorBuilder: (_, __) => SizedBox(height: 6.h),
        itemBuilder: (context, i) {
          final folder = _folders[i];
          return Material(
            color: AppPalette.card,
            borderRadius: BorderRadius.circular(14.r),
            child: InkWell(
              borderRadius: BorderRadius.circular(14.r),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  settings: const RouteSettings(name: 'AudioFolderScreen'),
                  builder: (_) => _AudioFolderPage(
                    folder: folder,
                    accent: widget.accent,
                  ),
                ),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: 12.w, vertical: 10.h),
                child: Row(
                  children: [
                    Container(
                      height: 42.sp,
                      width: 42.sp,
                      decoration: BoxDecoration(
                        color: widget.accent.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Icon(Icons.folder_rounded,
                          color: widget.accent, size: 22.sp),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            folder.name,
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
                            '${folder.songs.length} ${widget.itemsSuffix}',
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
        },
      ),
    );
  }

  Widget _centered(
    IconData icon,
    String text, {
    String? actionLabel,
    VoidCallback? onAction,
  }) {
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
                color: widget.accent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32.sp, color: widget.accent),
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
                  backgroundColor: widget.accent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                ),
                onPressed: onAction,
                child: Text(
                  actionLabel,
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

class _AudioFolder {
  _AudioFolder({required this.path, required this.songs});

  final String path;
  final List<SongModel> songs;

  String get name {
    final cut = path.lastIndexOf('/');
    final leaf = cut < 0 ? path : path.substring(cut + 1);
    return leaf.isEmpty ? path : leaf;
  }
}

/// Track list for one folder. Tapping hands the whole folder to
/// [GlobalAudioController] as the queue, so next/previous stay inside it.
class _AudioFolderPage extends StatelessWidget {
  const _AudioFolderPage({required this.folder, required this.accent});

  final _AudioFolder folder;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    AppPalette.sync(context);
    final audio = GlobalAudioController();

    return Scaffold(
      backgroundColor: AppPalette.surface,
      appBar: AppBar(
        title: Text(
          folder.name,
          style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView.separated(
        padding: EdgeInsets.fromLTRB(12.w, 10.h, 12.w, 24.h),
        itemCount: folder.songs.length,
        separatorBuilder: (_, __) => SizedBox(height: 6.h),
        itemBuilder: (context, i) {
          final song = folder.songs[i];
          return Material(
            color: AppPalette.card,
            borderRadius: BorderRadius.circular(14.r),
            child: InkWell(
              borderRadius: BorderRadius.circular(14.r),
              onTap: () => audio.playSongs(folder.songs, i),
              child: Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: 12.w, vertical: 10.h),
                child: Row(
                  children: [
                    Container(
                      height: 42.sp,
                      width: 42.sp,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Icon(Icons.music_note_rounded,
                          color: accent, size: 22.sp),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            song.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w600,
                              color: AppPalette.textH,
                            ),
                          ),
                          SizedBox(height: 2.h),
                          Text(
                            [
                              song.artist ?? '',
                              formatBytes(song.size),
                            ].where((s) => s.isNotEmpty).join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10.5.sp,
                              color: AppPalette.textS,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.play_arrow_rounded,
                        size: 20.sp, color: accent),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
