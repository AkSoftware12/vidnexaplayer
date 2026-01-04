import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:on_audio_query_forked/on_audio_query.dart'
    show SongModel, AlbumModel, OnAudioQuery, AudiosFromType, ArtworkType, QueryArtworkWidget;
import 'package:videoplayer/Utils/color.dart';
import '../../../../../LocalMusic/AUDIOCONTROLLER/global_audio_controller.dart';
import '../../song_repository.dart';

class AlbumPage extends StatefulWidget {
  final AlbumModel album;
  final Color color;
  final Color colortext;

  const AlbumPage({
    Key? key,
    required this.album,
    required this.color,
    required this.colortext,
  }) : super(key: key);

  @override
  State<AlbumPage> createState() => _AlbumPageState();
}

class _AlbumPageState extends State<AlbumPage> {
  late List<SongModel> _songs;
  late final SongRepository songRepository;
  final AudioPlayer audioPlayer = AudioPlayer();
  final audio = GlobalAudioController();

  @override
  void initState() {
    super.initState();
    _songs = [];
    _getSongs();
  }

  Future<void> _getSongs() async {
    final OnAudioQuery audioQuery = OnAudioQuery();

    final List<SongModel> songs = await audioQuery.queryAudiosFrom(
      AudiosFromType.ALBUM_ID,
      widget.album.id,
    );

    songs.removeWhere((song) => (song.duration ?? 0) < 10000);

    setState(() => _songs = songs);
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: widget.color,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ✅ Premium Header (Collapsing)
            SliverAppBar(
              backgroundColor: widget.color,
              elevation: 0,
              pinned: true,
              expandedHeight: 200,
              leading: Padding(
                padding: const EdgeInsets.only(left: 10),
                child: _glassIconButton(
                  icon: Icons.arrow_back_ios_new_rounded,
                  onTap: () => Navigator.of(context).pop(),
                ),
              ),
              actions: [
                // Padding(
                //   padding: const EdgeInsets.only(right: 12),
                //   child: _glassIconButton(
                //     icon: Icons.more_vert_rounded,
                //     onTap: () {},
                //   ),
                // ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    // subtle gradient background
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            widget.color,
                            widget.color.withOpacity(0.85),
                            widget.color.withOpacity(0.6),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),

                    // glow blobs
                    Positioned(
                      top: -40,
                      left: -40,
                      child: Container(
                        width: 180,
                        height: 180,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: widget.colortext.withOpacity(0.10),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -60,
                      right: -50,
                      child: Container(
                        width: 220,
                        height: 220,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: widget.colortext.withOpacity(0.08),
                        ),
                      ),
                    ),

                    // album artwork card
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(18, top + 20, 18, 16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _albumArtCard(),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.album.album,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: widget.colortext,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    widget.album.artist ?? 'Unknown',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w500,
                                      color: widget.colortext.withOpacity(0.70),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      _pillInfo(
                                        icon: Icons.library_music_rounded,
                                        text: "${_songs.length} songs",
                                      ),
                                      const SizedBox(width: 10),
                                      _pillInfo(
                                        icon: Icons.album_rounded,
                                        text: "Album",
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ✅ Actions
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: _primaryButton(
                        icon: Icons.play_arrow_rounded,
                        text: "Play All",
                        onTap: _songs.isEmpty
                            ? null
                            : () {
                          audio.playSongs(_songs, 0);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _secondaryButton(
                        icon: Icons.shuffle_rounded,
                        text: "Shuffle",
                        onTap: _songs.isEmpty
                            ? null
                            : () {
                          // UI only: shuffle behaviour depends on your controller
                          audio.playSongs(_songs, 0);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ✅ Songs title
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Tracks",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: widget.colortext,
                      ),
                    ),
                    Text(
                      _songs.isEmpty ? "" : "Tap to play",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: widget.colortext.withOpacity(0.60),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ✅ Song list
            SliverList(
              delegate: SliverChildBuilderDelegate(
                    (context, index) {
                  final song = _songs[index];

                  return Padding(
                    padding: EdgeInsets.fromLTRB(
                      14,
                      index == 0 ? 2 : 0,
                      14,
                      index == _songs.length - 1 ? 18 : 0,
                    ),
                    child: _songTile(
                      index: index,
                      song: song,
                      onTap: () => audio.playSongs(_songs, index),
                    ),
                  );
                },
                childCount: _songs.length,
              ),
            ),

            if (_songs.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 40, 18, 18),
                  child: _emptyState(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ========================= UI WIDGETS =========================

  Widget _albumArtCard() {
    return Container(
      width: 132,
      height: 132,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          fit: StackFit.expand,
          children: [
            QueryArtworkWidget(
              id: widget.album.id,
              type: ArtworkType.ALBUM,
              artworkQuality: FilterQuality.high,
              artworkFit: BoxFit.cover,
              artworkBorder: BorderRadius.zero,
              nullArtworkWidget: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  Icons.music_note_rounded,
                  size: 56,
                  color: widget.colortext.withOpacity(0.8),
                ),
              ),
            ),

            // subtle bottom gradient
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                height: 70,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withOpacity(0.00),
                      Colors.black.withOpacity(0.45),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),

            // play icon overlay
            Align(
              alignment: Alignment.bottomRight,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withOpacity(0.18)),
                  ),
                  child: Icon(
                    Icons.play_arrow_rounded,
                    color: widget.colortext,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _songTile({
    required int index,
    required SongModel song,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withOpacity(0.05),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              // artwork
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 52,
                  height: 52,
                  child: QueryArtworkWidget(
                    id: song.id,
                    type: ArtworkType.AUDIO,
                    artworkFit: BoxFit.cover,
                    artworkBorder: BorderRadius.zero,
                    nullArtworkWidget: Container(
                      color: Colors.white.withOpacity(0.06),
                      child: Icon(
                        Icons.music_note_rounded,
                        color: widget.colortext.withOpacity(0.7),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // texts
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14.5,
                        color: widget.colortext,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${song.artist ?? "Unknown"}  •  ${song.album ?? ""}",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: widget.colortext.withOpacity(0.65),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // index bubble
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.10)),
                ),
                child: Text(
                  "${index + 1}",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: widget.colortext.withOpacity(0.85),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withOpacity(0.05),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.music_off_rounded,
              color: widget.colortext.withOpacity(0.75),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "No songs found in this album.",
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: widget.colortext.withOpacity(0.75),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _glassIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Material(
          color: Colors.white.withOpacity(0.10),
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              width: 44,
              height: 44,
              child: Icon(icon, color: widget.colortext, size: 20),
            ),
          ),
        ),
      ),
    );
  }

  Widget _pillInfo({required IconData icon, required String text}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white.withOpacity(0.10),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: widget.colortext.withOpacity(0.85)),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: widget.colortext.withOpacity(0.85),
            ),
          ),
        ],
      ),
    );
  }

  Widget _primaryButton({
    required IconData icon,
    required String text,
    required VoidCallback? onTap,
  }) {
    return Opacity(
      opacity: onTap == null ? 0.45 : 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              colors: [
                ColorSelect.maineColor2,
                ColorSelect.maineColor2,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.colortext.withOpacity(0.22),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: widget.color, size: 24),
              const SizedBox(width: 10),
              Text(
                text,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: widget.color,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _secondaryButton({
    required IconData icon,
    required String text,
    required VoidCallback? onTap,
  }) {
    return Opacity(
      opacity: onTap == null ? 0.45 : 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: Colors.white.withOpacity(0.06),
            border: Border.all(color: Colors.white.withOpacity(0.10)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: widget.colortext, size: 22),
              const SizedBox(width: 10),
              Text(
                text,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: widget.colortext,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
