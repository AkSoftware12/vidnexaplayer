import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:on_audio_query_forked/on_audio_query.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:provider/provider.dart';

import '../../../../DirectoryFolder/directory_folder.dart' show FullScreenImageViewer;
import '../../../../LocalMusic/AUDIOCONTROLLER/global_audio_controller.dart';
import '../../../../LocalMusic/FullScreenPlayer/full_player_screen.dart';
import '../../../../NotifyListeners/LanguageProvider/language_provider.dart';
import '../../../../NotifyListeners/LanguageProvider/misc_strings.dart';
import '../../../../Utils/color.dart';
import '../../../../Utils/video_thumb.dart';
import '../../../../VideoPLayer/4kPlayer/4k_player.dart';
import '../../domain/entities/media_kind.dart';
import '../../domain/entities/video_entity.dart';

/// One search result row — thumbnail, name, duration, size, date, folder.
///
/// Branches on [VideoEntity.mediaKind] for both the thumbnail and what
/// happens on tap, but always reuses an existing app screen/player rather
/// than building a new one:
///  * video -> `AssetEntity.fromId` + `FullScreenVideoPlayerFixed`, exactly
///    like `DirectoryFolder` already does for files opened outside the
///    normal album browser.
///  * photo -> `AssetEntity.fromId` + `FullScreenImageViewer` (also from
///    `DirectoryFolder`).
///  * music -> re-resolves the `SongModel` via `OnAudioQuery` (the plugin
///    has no "by id" lookup, only bulk queries) and hands it to the same
///    `GlobalAudioController` + `FullPlayerScreen` the Music tab uses.
class VoiceSearchResultTile extends StatelessWidget {
  const VoiceSearchResultTile({
    super.key,
    required this.video,
    required this.onStale,
  });

  final VideoEntity video;

  /// Called when the underlying file/track no longer exists, so the caller
  /// (the search page) can drop it from the visible results and the index.
  final void Function(MediaKind kind, String id) onStale;

  /// A thumbnail-only `AssetEntity` built from already-indexed fields — no
  /// extra plugin round trip just to render a row. Only valid for
  /// video/photo; music uses `QueryArtworkWidget` instead.
  AssetEntity get _lightAsset => AssetEntity(
        id: video.id,
        typeInt: video.mediaKind == MediaKind.photo ? 1 : 2, // AssetType.image / .video
        width: video.width,
        height: video.height,
        duration: video.duration.inSeconds,
        title: video.fileName,
        relativePath: video.folderPath,
        mimeType: video.mimeType,
      );

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _open(context),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(width: 96, height: 64, child: _thumbnail()),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      video.fileName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 10,
                      runSpacing: 4,
                      children: [
                        if (video.mediaKind != MediaKind.photo)
                          _MetaChip(icon: Icons.timer_outlined, text: _formatDuration(video.duration)),
                        if (video.fileSizeBytes != null)
                          _MetaChip(icon: Icons.sd_storage_outlined, text: _formatSize(video.fileSizeBytes!)),
                        _MetaChip(
                          icon: Icons.calendar_today_outlined,
                          text: DateFormat('d MMM yyyy').format(video.createdDate),
                        ),
                        if (video.folderName != null)
                          _MetaChip(icon: Icons.folder_outlined, text: video.folderName!),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _thumbnail() {
    switch (video.mediaKind) {
      case MediaKind.video:
      case MediaKind.photo:
        return VideoThumb(
          key: ValueKey(video.id),
          asset: _lightAsset,
          width: 96,
          height: 64,
          placeholderIcon:
              video.mediaKind == MediaKind.photo ? Icons.image_outlined : Icons.movie_outlined,
        );
      case MediaKind.music:
        final songId = int.tryParse(video.id);
        if (songId == null) return _musicPlaceholder();
        return QueryArtworkWidget(
          controller: OnAudioQuery(),
          id: songId,
          type: ArtworkType.AUDIO,
          artworkFit: BoxFit.cover,
          artworkBorder: BorderRadius.zero,
          artworkWidth: 96,
          artworkHeight: 64,
          nullArtworkWidget: _musicPlaceholder(),
        );
    }
  }

  Widget _musicPlaceholder() => Container(
        color: Colors.grey.shade300,
        alignment: Alignment.center,
        child: const Icon(Icons.music_note, color: Colors.white, size: 28),
      );

  Future<void> _open(BuildContext context) async {
    switch (video.mediaKind) {
      case MediaKind.video:
        await _openVideo(context);
      case MediaKind.photo:
        await _openPhoto(context);
      case MediaKind.music:
        await _openMusic(context);
    }
  }

  Future<void> _openVideo(BuildContext context) async {
    final asset = await AssetEntity.fromId(video.id);
    if (asset == null) {
      _reportStale(context, 'voice_search_video_unavailable');
      return;
    }
    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FullScreenVideoPlayerFixed(videos: [asset], initialIndex: 0),
      ),
    );
  }

  Future<void> _openPhoto(BuildContext context) async {
    final asset = await AssetEntity.fromId(video.id);
    final file = await asset?.file;
    if (asset == null || file == null || !await file.exists()) {
      _reportStale(context, 'voice_search_photo_unavailable');
      return;
    }
    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => FullScreenImageViewer(imagePath: file.path)),
    );
  }

  Future<void> _openMusic(BuildContext context) async {
    final songId = int.tryParse(video.id);
    SongModel? song;
    if (songId != null) {
      try {
        final songs = await OnAudioQuery().querySongs();
        for (final s in songs) {
          if (s.id == songId) {
            song = s;
            break;
          }
        }
      } catch (_) {
        song = null;
      }
    }

    if (song == null) {
      _reportStale(context, 'voice_search_song_unavailable');
      return;
    }

    if (!context.mounted) return;
    await GlobalAudioController().playSongs([song], 0);
    if (!context.mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => const FullPlayerScreen()));
  }

  void _reportStale(BuildContext context, String messageKey) {
    onStale(video.mediaKind, video.id);
    if (!context.mounted) return;
    final lang = context.read<LocaleProvider>().locale.languageCode;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(MiscStrings.t(lang, messageKey))),
    );
  }

  static String _formatDuration(Duration duration) {
    String two(int n) => n.toString().padLeft(2, '0');
    final minutes = two(duration.inMinutes.remainder(60));
    final seconds = two(duration.inSeconds.remainder(60));
    return duration.inHours > 0 ? '${two(duration.inHours)}:$minutes:$seconds' : '$minutes:$seconds';
  }

  static String _formatSize(int bytes) {
    final mb = bytes / (1024 * 1024);
    return mb >= 1024 ? '${(mb / 1024).toStringAsFixed(2)} GB' : '${mb.toStringAsFixed(1)} MB';
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: ColorSelect.subtextColor),
        const SizedBox(width: 3),
        Text(
          text,
          style: GoogleFonts.poppins(fontSize: 10.5, color: ColorSelect.subtextColor),
        ),
      ],
    );
  }
}
