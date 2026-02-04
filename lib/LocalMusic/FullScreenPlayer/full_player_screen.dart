import 'dart:io';
import 'dart:typed_data';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:on_audio_query_forked/on_audio_query.dart';
import 'package:rxdart/rxdart.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../TextScroll/text_scroll.dart';
import '../../Utils/color.dart';
import '../../Utils/common.dart';
import '../AUDIOCONTROLLER/global_audio_controller.dart';

class PositionData {
  final Duration position;
  final Duration duration;
  PositionData(this.position, this.duration);
}

class FullPlayerScreen extends StatefulWidget {
  const FullPlayerScreen({super.key});

  @override
  State<FullPlayerScreen> createState() => _FullPlayerScreenState();
}

class _FullPlayerScreenState extends State<FullPlayerScreen> {
  late final PageController _pageCtrl;

  Duration? selectedTimer;
  bool _isDragging = false;
  double? _dragValueMs;
  double _lastUiValueMs = 0; // ✅ for animation smoothness



  final List<Duration> timerOptions = const [
    Duration(minutes: 10),
    Duration(minutes: 30),
    Duration(minutes: 60),
    Duration(minutes: 120),
  ];

  Color currentColor = ColorSelect.maineColor2;
  void changeColor(Color c) => setState(() => currentColor = c);

  // ✅ prevent infinite loop between onPageChanged and animateToPage
  bool _pageChangeFromCode = false;
  int _lastAnimatedIndex = -1;

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController(viewportFraction: .85);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  Future<void> _launchYoutubeSearch(String query) async {
    final url = Uri.parse('https://www.youtube.com/search?q=$query');
    if (await canLaunchUrl(url)) await launchUrl(url);
  }

  Future<void> _launchGoogleSearch(String query) async {
    final url = Uri.parse('https://www.google.com/search?q=$query');
    if (await canLaunchUrl(url)) await launchUrl(url);
  }

  String _formatBadge(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    if (m >= 60) {
      final h = m ~/ 60;
      final rm = m % 60;
      return "${h}h ${rm}m";
    }
    return "${m}m ${s.toString().padLeft(2, '0')}s";
  }

  @override
  Widget build(BuildContext context) {
    final audio = GlobalAudioController();

    return StreamBuilder<MediaItem?>(
      stream: audio.handler.mediaItem,
      builder: (context, snapshot) {
        final mediaItem = snapshot.data;
        if (mediaItem == null) {
          return const Scaffold(
            backgroundColor: Colors.black,
            body: Center(child: CircularProgressIndicator(color: Colors.white)),
          );
        }

        return Scaffold(
          backgroundColor: currentColor,
          body: SafeArea(
            child: Column(
              children: [
                // APP BAR
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 6),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.keyboard_arrow_down, size: 30, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          _iconBtn(() {
                            showDialog(
                              context: context,
                              builder: (_) => AlertDialog(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(25),
                                ),
                                content: HueRingPicker(
                                  pickerColor: currentColor,
                                  onColorChanged: changeColor,
                                ),
                              ),
                            );
                          }, Icons.color_lens),
                          SizedBox(width: 10,),
                          _iconBtn(() {
                            Share.share("${mediaItem.title}\n${mediaItem.artist}\n${mediaItem.artUri}");
                          }, Icons.share),
                        ],
                      )
                    ],
                  ),
                ),

                const SizedBox(height: 0),

                // ARTWORK CAROUSEL
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.35,
                  child: ValueListenableBuilder<List<SongModel>>(
                    valueListenable: audio.currentSongs,
                    builder: (_, songs, __) {
                      return ValueListenableBuilder<int>(
                        valueListenable: audio.currentIndex,
                        builder: (_, currentIndex, __) {
                          if (songs.isEmpty) {
                            return const Center(
                              child: Icon(Icons.music_note, size: 80, color: Colors.white),
                            );
                          }

                          // ✅ animate only when index changed
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (!_pageCtrl.hasClients) return;
                            if (currentIndex == _lastAnimatedIndex) return;

                            _lastAnimatedIndex = currentIndex;
                            _pageChangeFromCode = true;

                            _pageCtrl.animateToPage(
                              currentIndex,
                              duration: const Duration(milliseconds: 350),
                              curve: Curves.easeOutCubic,
                            ).whenComplete(() {
                              _pageChangeFromCode = false;
                            });
                          });

                          return PageView.builder(
                            controller: _pageCtrl,
                            itemCount: songs.length,
                            onPageChanged: (i) async {
                              // ✅ ignore if we are animating due to next/prev
                              if (_pageChangeFromCode) return;

                              await audio.handler.skipToQueueItem(i);
                            },
                            itemBuilder: (_, i) {
                              final isActive = i == currentIndex;
                              final song = songs[i];

                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                padding: EdgeInsets.symmetric(
                                  vertical: isActive ? 0 : 25,
                                  horizontal: 8,
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(5),
                                  child:SongArtwork(
                                    songId: song.id,
                                    size: 80,
                                    borderRadius: BorderRadius.circular(5),
                                  ),

                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),

                const Spacer(),

                // TITLE (BOTTOM)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  child: TextScroll(
                    mediaItem.title,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                Text(
                  mediaItem.artist ?? "Unknown Artist",
                  style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 50.sp),

                // Middle Icons Row
                Padding(
                  padding: EdgeInsets.only(left: 18.sp, right: 18.sp),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () => _openSleepTimerSheet(context, audio),
                        child: ValueListenableBuilder<Duration?>(
                          valueListenable: audio.sleepRemaining,
                          builder: (context, remaining, _) {
                            final active = remaining != null && remaining > Duration.zero;
                            return Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Icon(
                                  Icons.access_time,
                                  size: 30,
                                  color: active ? ColorSelect.maineColor : Colors.white,
                                ),
                                if (active)
                                  Positioned(
                                    top: -10,
                                    right: -18,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.55),
                                        borderRadius: BorderRadius.circular(999),
                                        border: Border.all(color: Colors.white24),
                                      ),
                                      child: Text(
                                        _formatBadge(remaining),
                                        style: GoogleFonts.poppins(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      ),

                      GestureDetector(
                        onTap: () async {
                          showSliderDialog(
                            context: context,
                            title: "Adjust volume",
                            divisions: 10,
                            min: 0.0,
                            max: 1.0,
                            stream: audio.player.volumeStream,
                            onChanged: audio.player.setVolume,
                            colors: Colors.white,
                            value: 0.5,
                          );
                        },
                        child: const Icon(Icons.volume_up, color: Colors.white, size: 30),
                      ),

                      GestureDetector(
                        onTap: () => _openQueue(context, audio),
                        child: const Icon(Icons.playlist_play, color: Colors.white, size: 30),
                      ),

                      GestureDetector(
                        onTap: () => _launchYoutubeSearch(mediaItem.title),
                        child: const Icon(Icons.ondemand_video, color: Colors.white, size: 30),
                      ),

                      GestureDetector(
                        onTap: () => _launchGoogleSearch('lyrics ${mediaItem.title}'),
                        child: const Icon(Icons.lyrics, color: Colors.white, size: 30),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 40.sp),

                // PROGRESS
                StreamBuilder<PositionData>(
                  stream: Rx.combineLatest2<Duration, Duration?, PositionData>(
                    // ✅ positionStream ki jagah (more smooth)
                    audio.player.createPositionStream(
                      minPeriod: const Duration(milliseconds: 120),
                      maxPeriod: const Duration(milliseconds: 120),
                    ),
                    audio.player.durationStream,
                        (p, d) => PositionData(p, d ?? Duration.zero),
                  ),
                  builder: (_, snapshot) {
                    final p = snapshot.data?.position ?? Duration.zero;
                    final d = snapshot.data?.duration ?? Duration.zero;

                    double maxMs = d.inMilliseconds.toDouble();
                    if (maxMs <= 0) maxMs = 1;

                    final positionMs = p.inMilliseconds.toDouble().clamp(0.0, maxMs);

                    // ✅ drag time: local value, otherwise: stream value
                    final targetMs = _isDragging
                        ? (_dragValueMs ?? positionMs)
                        : positionMs;

                    // ✅ keep last value for tween
                    final fromMs = _lastUiValueMs.clamp(0.0, maxMs);
                    final toMs = targetMs.clamp(0.0, maxMs);

                    if (!_isDragging) {
                      _lastUiValueMs = toMs; // update only when not dragging
                    }

                    return Column(
                      children: [
                        // ✅ animate when NOT dragging (jump remove)
                        TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: fromMs, end: toMs),
                          duration: const Duration(milliseconds: 0),
                          curve: Curves.linear,
                          builder: (context, animatedValue, _) {
                            return Slider(
                              value: _isDragging ? toMs : animatedValue,
                              min: 0,
                              max: maxMs,
                              activeColor: Colors.red,
                              inactiveColor: Colors.white24,

                              onChangeStart: (v) {
                                setState(() {
                                  _isDragging = true;
                                  _dragValueMs = v;
                                });
                              },
                              onChanged: (v) {
                                setState(() => _dragValueMs = v);
                              },
                              onChangeEnd: (v) async {
                                setState(() {
                                  _isDragging = false;
                                  _dragValueMs = null;
                                  _lastUiValueMs = v.clamp(0.0, maxMs);
                                });
                                await audio.handler.seek(Duration(milliseconds: v.toInt()));
                              },
                            );
                          },
                        ),

                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [_time(p), _time(d)],
                          ),
                        )
                      ],
                    );
                  },
                ),

                const SizedBox(height: 5),

                // CONTROLS
                Padding(
                  padding: const EdgeInsets.only(bottom: 50, top: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      StreamBuilder<bool>(
                        stream: audio.player.shuffleModeEnabledStream,
                        builder: (_, s) => _iconBtn(
                              () => audio.player.setShuffleModeEnabled(!(s.data ?? false)),
                          Icons.shuffle,
                          active: s.data ?? false,
                        ),
                      ),

                      IconButton(icon: _ic(Icons.skip_previous), onPressed: audio.previous),
                      IconButton(icon: _ic(Icons.replay_10), onPressed: audio.seekBackward),

                      StreamBuilder<PlayerState>(
                        stream: audio.player.playerStateStream,
                        builder: (_, s) {
                          final playing = s.data?.playing ?? false;
                          return IconButton(
                            icon: Icon(
                              playing ? Icons.pause_circle : Icons.play_circle,
                              size: 60,
                              color: Colors.white,
                            ),
                            onPressed: () => playing ? audio.pause() : audio.play(),
                          );
                        },
                      ),

                      IconButton(icon: _ic(Icons.forward_10), onPressed: audio.seekForward),
                      IconButton(icon: _ic(Icons.skip_next), onPressed: audio.next),

                      StreamBuilder<LoopMode>(
                        stream: audio.player.loopModeStream,
                        builder: (_, s) => _iconBtn(() {
                          audio.player.setLoopMode(
                            s.data == LoopMode.one ? LoopMode.off : LoopMode.one,
                          );
                        }, s.data == LoopMode.one ? Icons.repeat_one : Icons.repeat,
                            active: s.data != LoopMode.off),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ---------------- Sleep Timer Sheet ----------------
  void _openSleepTimerSheet(BuildContext context, GlobalAudioController audio) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Color(0xFF0F172A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const Text(
                "Sleep Timer",
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              ListTile(
                leading: const Icon(Icons.timer_off, color: Colors.white70),
                title: Text("Turn Off", style: GoogleFonts.poppins(color: Colors.white)),
                onTap: () async {
                  setState(() => selectedTimer = null);
                  await audio.cancelSleepTimer();
                  Navigator.pop(context);
                },
              ),

              ...timerOptions.map((duration) {
                final minutes = duration.inMinutes;
                final isSelected = duration == selectedTimer;

                return GestureDetector(
                  onTap: () async {
                    setState(() => selectedTimer = duration);
                    await audio.setSleepTimer(duration);
                    Navigator.pop(context);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.blue.withOpacity(0.15) : Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: isSelected ? Colors.blue : Colors.white24),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.timer, color: isSelected ? Colors.blue : Colors.white70),
                        const SizedBox(width: 12),
                        Text(
                          "$minutes minutes",
                          style: TextStyle(
                            color: isSelected ? Colors.blue : Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        if (isSelected) const Icon(Icons.check_circle, color: Colors.blue),
                      ],
                    ),
                  ),
                );
              }),

              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Close", style: TextStyle(color: Colors.white70)),
              ),
            ],
          ),
        );
      },
    );
  }

  // ---------------- Queue Sheet ----------------
  void _openQueue(BuildContext context, GlobalAudioController audio) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return StreamBuilder<List<MediaItem>>(
          stream: audio.handler.queue,
          builder: (context, snapshot) {
            final q = snapshot.data ?? [];

            return ValueListenableBuilder<int>(
              valueListenable: audio.currentIndex,
              builder: (context, playingIndex, _) {
                return Container(
                  height: MediaQuery.of(context).size.height * 0.55,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF121212), Color(0xFF0B0B0B)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 10),

                      /// 🔹 Handle bar
                      Container(
                        width: 45,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),

                      const SizedBox(height: 16),

                      /// 🔹 Header
                      Text(
                        "Now Playing Queue",
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),

                      const SizedBox(height: 16),

                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          itemCount: q.length,
                          separatorBuilder: (_, __) => const Divider(
                            color: Colors.white10,
                            height: 1,
                          ),
                          itemBuilder: (context, index) {
                            final item = q[index];
                            final isPlaying = index == playingIndex;

                            return GestureDetector(
                              onTap: () =>
                                  audio.handler.skipToQueueItem(index),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: isPlaying
                                      ? const Color(0xFF2EDFB4)
                                      .withOpacity(0.08)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(14),
                                  border: isPlaying
                                      ? Border.all(
                                    color: const Color(0xFF2EDFB4)
                                        .withOpacity(0.35),
                                  )
                                      : null,
                                ),
                                child: Row(
                                  children: [
                                    /// 🔹 Accent bar
                                    AnimatedContainer(
                                      duration:
                                      const Duration(milliseconds: 250),
                                      width: 4,
                                      height: 50,
                                      decoration: BoxDecoration(
                                        color: isPlaying
                                            ? const Color(0xFF2EDFB4)
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),

                                    const SizedBox(width: 10),

                                    /// 🎵 Artwork
                                    Container(
                                      decoration: BoxDecoration(
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.4),
                                            blurRadius: 8,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: SongArtwork(
                                        songId:
                                        int.tryParse(item.id) ?? 0,
                                        size: 56,
                                        borderRadius:
                                        BorderRadius.circular(10),
                                      ),
                                    ),

                                    const SizedBox(width: 12),

                                    /// 🎶 Title + Artist
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.title,
                                            maxLines: 1,
                                            overflow:
                                            TextOverflow.ellipsis,
                                            style:
                                            GoogleFonts.poppins(
                                              color: isPlaying
                                                  ? const Color(
                                                  0xFF2EDFB4)
                                                  : Colors.white,
                                              fontSize: 14,
                                              fontWeight:
                                              FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            item.artist ??
                                                "Unknown Artist",
                                            maxLines: 1,
                                            overflow:
                                            TextOverflow.ellipsis,
                                            style:
                                            GoogleFonts.poppins(
                                              color: Colors.white54,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    const SizedBox(width: 8),

                                    /// 🔊 Playing / More
                                    isPlaying
                                        ? const Icon(
                                      Icons.graphic_eq,
                                      color:
                                      Color(0xFF2EDFB4),
                                      size: 22,
                                    )
                                        : GestureDetector(
                                      onTap: () => _openSongOptions(context, audio, item, isPlaying, index),
                                      child: const Icon(
                                        Icons.more_vert,
                                        color:
                                        Colors.white54,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _iconBtn(Function onTap, IconData icon, {bool active = false}) => GestureDetector(
    onTap: () => onTap(),
    child: Icon(icon, size: 26, color: active ? Colors.greenAccent : Colors.white),
  );

  Widget _ic(IconData i) => Icon(i, color: Colors.white, size: 38);

  Text _time(Duration d) => Text(
    "${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}",
    style: const TextStyle(color: Colors.white60, fontSize: 12),
  );




  void _openSongOptions(
      BuildContext context,
      GlobalAudioController audio,
      MediaItem song,
      bool isPlaying,
      int index,
      ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF151515), Color(0xFF0B0B0B)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                /// handle
                Container(
                  width: 46,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),

                /// header (song row)
                Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.45),
                            blurRadius: 10,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: SongArtwork(
                        songId: int.tryParse(song.id) ?? 0,
                        size: 52,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            song.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            song.artist ?? "Unknown Artist",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isPlaying)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2EDFB4).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: const Color(0xFF2EDFB4).withOpacity(0.35),
                          ),
                        ),
                        child: Text(
                          "PLAYING",
                          style: GoogleFonts.poppins(
                            color: const Color(0xFF2EDFB4),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 16),
                const Divider(color: Colors.white10, height: 1),
                const SizedBox(height: 10),

                /// options
                _premiumOptionTile(
                  icon: isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  title: isPlaying ? "Pause" : "Play",
                  subtitle: isPlaying ? "Pause current song" : "Play this song now",
                  color: const Color(0xFF2EDFB4),
                  onTap: () async {
                    if (isPlaying) {
                      await audio.player.pause();
                    } else {
                      await audio.player.seek(Duration.zero, index: index);
                      await audio.player.play();
                      audio.currentIndex.value = index;
                    }
                    if (context.mounted) Navigator.pop(context);
                  },
                ),

                _premiumOptionTile(
                  icon: Icons.share_rounded,
                  title: "Share",
                  subtitle: "Share audio file or song details",
                  onTap: () async {
                    try {
                      final String? filePath = song.extras?['path']?.toString() ?? song.id;

                      if (filePath == null || filePath.isEmpty) {
                        await Share.share(
                          '${song.title}\n${song.artist ?? ""}',
                          subject: song.title,
                        );
                      } else {
                        await Share.shareXFiles(
                          [XFile(filePath)],
                          text: '${song.title}\n${song.artist ?? ""}',
                          subject: song.title,
                        );
                      }
                    } catch (_) {
                      await Share.share('${song.title}\n${song.artist ?? ""}', subject: song.title);
                    }

                    if (context.mounted) Navigator.pop(context);
                  },
                ),

                _premiumOptionTile(
                  icon: Icons.info_outline_rounded,
                  title: "Song Info",
                  subtitle: "View details",
                  onTap: () {
                    Navigator.pop(context);
                    _showSongInfo(context, song);
                  },
                ),

                _premiumOptionTile(
                  icon: Icons.delete_outline_rounded,
                  title: "Delete",
                  subtitle: "Remove from device",
                  color: Colors.redAccent,
                  onTap: () async {
                    Navigator.pop(context);
                    await _confirmAndDeleteSong(context, audio, song, index);
                  },
                ),

                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }
  Widget _premiumOptionTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Color? color,
    required VoidCallback onTap,
  }) {
    final c = color ?? Colors.white;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: c.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: c.withOpacity(0.20)),
              ),
              child: Icon(icon, color: c, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.poppins(
                        color: Colors.white54,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ]
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.white38),
          ],
        ),
      ),
    );
  }
  Future<void> _confirmAndDeleteSong(
      BuildContext context,
      GlobalAudioController audio,
      MediaItem song,
      int index,
      ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF151515),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text(
            "Delete song?",
            style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          content: Text(
            "This will remove the audio file from your device.",
            style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text("Cancel", style: GoogleFonts.poppins(color: Colors.white70)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text("Delete", style: GoogleFonts.poppins(color: Colors.redAccent)),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      final path = song.extras?['path']?.toString() ?? song.id;
      if (path == null || path.isEmpty) throw "No file path";

      // stop if this one is playing
      if (audio.currentIndex.value == index) {
        await audio.player.stop();
      }

      // delete file
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }

      // remove from queue (audio_service queue)
      final q = audio.handler.queue.value;
      final newQ = [...q]..removeAt(index);
      audio.handler.updateQueue(newQ);

      // fix currentIndex
      if (audio.currentIndex.value >= newQ.length) {
        audio.currentIndex.value = (newQ.isEmpty) ? 0 : newQ.length - 1;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Deleted: ${song.title}", style: GoogleFonts.poppins()),
          backgroundColor: const Color(0xFF1E1E1E),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Delete failed", style: GoogleFonts.poppins()),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }




  void _showSongInfo(BuildContext context, MediaItem song) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF121212),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.6),
                blurRadius: 20,
                offset: const Offset(0, 8),
              )
            ],
          ),
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// Header
              Row(
                children: [
                  const Icon(Icons.music_note_rounded,
                      color: Colors.white, size: 26),
                  const SizedBox(width: 10),
                  const Text(
                    "Song Information",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => Navigator.pop(context),
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(Icons.close,
                          color: Colors.white54, size: 20),
                    ),
                  )
                ],
              ),

              const SizedBox(height: 18),

              /// Artwork + Title
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SongArtwork(
                    songId: int.tryParse(song.id) ?? 0,
                    size: 70,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          song.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          song.artist ?? "Unknown Artist",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),
              const Divider(color: Colors.white12),

              /// Info Rows
              _infoRow("Duration", _formatDuration(song.duration)),
              _infoRow("Album", song.album ?? "Unknown"),
              _infoRow("ID", song.id),

              const SizedBox(height: 16),

              /// Close Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.08),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    "Close",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
  Widget _infoRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }



  String _formatDuration(Duration? d) {
    if (d == null) return "--:--";
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }



}




class SongArtwork extends StatelessWidget {
  final int songId;
  final double size;
  final BorderRadius borderRadius;

  const SongArtwork({
    super.key,
    required this.songId,
    this.size = 60,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
  });

  @override
  Widget build(BuildContext context) {
    final audioQuery = OnAudioQuery();

    return ClipRRect(
      borderRadius: borderRadius,
      child: FutureBuilder<Uint8List?>(
        future: audioQuery.queryArtwork(
          songId,
          ArtworkType.AUDIO,
          size: 800,      // quality
          quality: 100,   // 0-100
        ),
        builder: (context, snapshot) {
          final bytes = snapshot.data;

          if (bytes == null || bytes.isEmpty) {
            return _fallback(size);
          }

          return Image.memory(
            bytes,
            width: size,
            height: size,
            fit: BoxFit.fill,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) => _fallback(size),
          );
        },
      ),
    );
  }

  Widget _fallback(double size) {
    return Container(
      width: size,
      height: size,
      color: Colors.white10,
      alignment: Alignment.center,
      child: const Icon(Icons.music_note, size: 28, color: Colors.white),
    );
  }
}


