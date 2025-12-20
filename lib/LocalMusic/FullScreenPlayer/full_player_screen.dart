import 'dart:ui';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:on_audio_query_forked/on_audio_query.dart';
import 'package:rxdart/rxdart.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:videoplayer/Utils/color.dart';

import '../../HexColorCode/HexColor.dart';
import '../../TextScroll/text_scroll.dart';
import '../../Utils/common.dart';
import '../../Utils/textSize.dart';
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


  Future<void> _launchYoutubeSearch(String query) async {
    final Uri url = Uri.parse('https://www.youtube.com/search?q=$query');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      throw 'Could not launch $url';
    }
  }

  Future<void> _launchGoogleSearch(String query) async {
    final Uri url = Uri.parse('https://www.google.com/search?q=$query');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      throw 'Could not launch $url';
    }
  }
  @override
  Widget build(BuildContext context) {
    final audio = GlobalAudioController();

    return StreamBuilder<SequenceState?>(
      stream: audio.player.sequenceStateStream,
      builder: (context, snapshot) {
        final sequenceState = snapshot.data;

        if (sequenceState == null ||
            sequenceState.sequence.isEmpty ||
            sequenceState.currentSource == null) {
          return const Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          );
        }

        final mediaItem =
        sequenceState.currentSource!.tag as MediaItem;

        return Scaffold(
          backgroundColor: ColorSelect.maineColor2,
          body: Stack(
            children: [
              /// 🔥 BACKGROUND ART
              QueryArtworkWidget(
                id: int.tryParse(mediaItem.id) ?? 0,
                type: ArtworkType.AUDIO,
                artworkFit: BoxFit.cover,
                size: 1000,
                nullArtworkWidget:
                Container(color: Colors.black),
              ),

              /// 🔥 BLUR
              BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                child: Container(
                  color: Colors.black.withOpacity(.75),
                ),
              ),

              SafeArea(
                child: Column(
                  children: [
                    /// 🔝 TOP BAR
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.keyboard_arrow_down,
                              color: Colors.white,
                              size: 30,
                            ),
                            onPressed: () =>
                                Navigator.pop(context),
                          ),
                          const Spacer(),
                          const Icon(Icons.more_vert,
                              color: Colors.white),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    /// 🎨 ALBUM ART
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(0),
                        child: QueryArtworkWidget(
                          id: int.tryParse(mediaItem.id) ?? 0,
                          type: ArtworkType.AUDIO,
                          artworkFit: BoxFit.cover,
                          quality: 100, // 👈 max quality (0–100)
                          artworkHeight: MediaQuery.of(context).size.height*.35,
                          artworkWidth: MediaQuery.of(context).size.width,
                          artworkBorder: BorderRadius.circular(15),
                          nullArtworkWidget: Container(
                            height:  MediaQuery.of(context).size.height*.35,
                            width: MediaQuery.of(context).size.width,
                            color: Colors.white10,
                            child: const Icon(
                              Icons.music_note,
                              color: Colors.white,
                              size: 80,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 30),
                    Center(
                      child:Flexible(
                        child: TextScroll(
                          mediaItem.title,
                          style: GoogleFonts.poppins(
                            textStyle: TextStyle(
                              color: Colors.white,
                              fontSize: 25.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          intervalSpaces: 10,
                          velocity:
                          Velocity(pixelsPerSecond: Offset(50, 0)),
                          fadedBorder: true,
                          fadeBorderVisibility:
                          FadeBorderVisibility.auto,
                          fadeBorderSide: FadeBorderSide.both,
                        ),
                      ),

                    ),
                    Text(
                      mediaItem.artist ?? 'Unknown Artist',
                      style: GoogleFonts.poppins(
                        textStyle: TextStyle(
                          color: Colors.grey,
                          fontSize: TextSizes.textmedium,
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                    ),
                    const Spacer(),

                    SizedBox(height: 40.sp),
                    Padding(
                      padding:  EdgeInsets.only(left: 18.sp,right: 18.sp),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [

                          GestureDetector(
                              onTap: () {
                                // showDialog(
                                //   context: context,
                                //   builder: (BuildContext context) {
                                //     return AlertDialog(
                                //       title: Text('Sleep Timer'),
                                //       content: Container(
                                //         height: 200,
                                //         width: 200,
                                //         child: ListView.builder(
                                //           itemCount: timerOptions.length,
                                //           itemBuilder: (BuildContext context, int index) {
                                //             final duration = timerOptions[index];
                                //             final minutes = duration.inMinutes;
                                //             bool isSelected = duration == selectedTimer;
                                //             return ListTile(
                                //               title: Text(
                                //                 '$minutes minutes',
                                //                 style: TextStyle(
                                //                   color: isSelected
                                //                       ? Colors
                                //                       .blue // Customize the selected option's text color
                                //                       : null,
                                //                 ),
                                //               ),
                                //               onTap: () {
                                //                 setTimer(
                                //                     duration); // Set the selected timer
                                //               },
                                //             );
                                //           },
                                //         ),
                                //       ),
                                //       actions: [
                                //         TextButton(
                                //           onPressed: () {
                                //             setState(() {
                                //               selectedTimer = null;
                                //               Navigator.pop(context);
                                //             });
                                //           },
                                //           child: Text('Cancel'),
                                //         ),
                                //       ],
                                //     );
                                //   },
                                // );
                              },
                              child: SizedBox(
                                  height: 20.sp,
                                  width: 20.sp,
                                  child: Image.asset('assets/snooze.png',color:Colors.white,))
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
                              child: SizedBox(
                                  height: 20.sp,
                                  width: 20.sp,
                                  child: Image.asset('assets/volume.png',color:Colors.white,))
                          ),



                          GestureDetector(
                            onTap: () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (_) {
                                  return ValueListenableBuilder<List<SongModel>>(
                                    valueListenable: audio.currentSongs,
                                    builder: (context, songs, _) {
                                      return ValueListenableBuilder<int>(
                                        valueListenable: audio.currentIndex,
                                        builder: (context, playingIndex, _) {
                                          return Container(
                                            height: MediaQuery.of(context).size.height * 0.5,
                                            decoration: const BoxDecoration(
                                              color: Color(0xFF0E0E0E),
                                              borderRadius:
                                              BorderRadius.vertical(top: Radius.circular(28)),
                                            ),
                                            child: Column(
                                              children: [
                                                const SizedBox(height: 12),

                                                /// drag handle
                                                Container(
                                                  width: 40,
                                                  height: 4,
                                                  decoration: BoxDecoration(
                                                    color: Colors.grey.shade700,
                                                    borderRadius: BorderRadius.circular(10),
                                                  ),
                                                ),

                                                const SizedBox(height: 16),

                                                Text(
                                                  "Now Playing Queue",
                                                  style: GoogleFonts.poppins(
                                                    color: Colors.white,
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                const SizedBox(height: 12),
                                                Container(
                                                  width: double.infinity,
                                                  height: 1,
                                                  decoration: BoxDecoration(
                                                    color: Colors.grey.shade700,
                                                    borderRadius: BorderRadius.circular(10),
                                                  ),
                                                ),

                                                const SizedBox(height: 12),

                                                Expanded(
                                                  child: ListView.builder(
                                                    itemCount: songs.length,
                                                    padding: const EdgeInsets.only(bottom: 20),
                                                    itemBuilder: (context, index) {
                                                      final song = songs[index];
                                                      final isPlaying = index == playingIndex;

                                                      return AnimatedContainer(
                                                        duration: const Duration(milliseconds: 300),
                                                        margin: const EdgeInsets.symmetric(
                                                            horizontal: 14, vertical: 6),
                                                        decoration: BoxDecoration(
                                                          color: isPlaying
                                                              ? const Color(0xFF2EDF)
                                                              .withOpacity(0.12)
                                                              : Colors.white.withOpacity(0.04),
                                                          borderRadius: BorderRadius.circular(16),
                                                          border: isPlaying
                                                              ? Border.all(
                                                              color: const Color(0xFF2EDFB4),
                                                              width: 0.6)
                                                              : null,
                                                        ),
                                                        child: ListTile(
                                                          contentPadding: const EdgeInsets.symmetric(
                                                              horizontal: 0, vertical: 0),

                                                          /// 🎵 ARTWORK + PLAY ICON
                                                          leading: Stack(
                                                            alignment: Alignment.center,
                                                            children: [
                                                              ClipRRect(
                                                                borderRadius: BorderRadius.circular(12),
                                                                child: QueryArtworkWidget(
                                                                  id: song.id,
                                                                  type: ArtworkType.AUDIO,
                                                                  size: 200,
                                                                  artworkBorder:
                                                                  BorderRadius.circular(12),
                                                                  nullArtworkWidget: Container(
                                                                    width: 50,
                                                                    height: 50,
                                                                    decoration: BoxDecoration(
                                                                      color: Colors.grey.shade900,
                                                                      borderRadius:
                                                                      BorderRadius.circular(12),
                                                                    ),
                                                                    child: const Icon(
                                                                      Icons.music_note_rounded,
                                                                      color: Colors.white70,
                                                                    ),
                                                                  ),
                                                                ),
                                                              ),


                                                            ],
                                                          ),

                                                          title: Row(
                                                            mainAxisAlignment: MainAxisAlignment.start,
                                                            crossAxisAlignment: CrossAxisAlignment.start,
                                                            children: [
                                                              Expanded(
                                                                child: Column(
                                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                                  children: [
                                                                    Text(
                                                                      song.title,
                                                                      maxLines: 1,
                                                                      overflow: TextOverflow.ellipsis,
                                                                      style: GoogleFonts.poppins(
                                                                        color: isPlaying
                                                                            ? const Color(0xFF2EDFB4)
                                                                            : Colors.white,
                                                                        fontSize: 14,
                                                                        fontWeight: FontWeight.w500,
                                                                      ),
                                                                    ),
                                                                    Text(
                                                                      song.artist ?? "Unknown Artist",
                                                                      maxLines: 1,
                                                                      overflow: TextOverflow.ellipsis,
                                                                      style: GoogleFonts.poppins(
                                                                        fontSize: 12,
                                                                        color: isPlaying
                                                                            ? const Color(0xFF2EDFB4)
                                                                            : Colors.grey,
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),

                                                              GestureDetector(
                                                                onTap: (){
                                                                  if( isPlaying){

                                                                  }else{
                                                                    audio.player
                                                                        .seek(Duration.zero, index: index);
                                                                    audio.player.play();
                                                                    audio.currentIndex.value = index;

                                                                  }

                                                                },
                                                                child: Container(
                                                                  width: 40,
                                                                  height: 40,
                                                                  decoration: BoxDecoration(
                                                                    color:
                                                                    Colors.black.withOpacity(0.35),
                                                                    borderRadius:
                                                                    BorderRadius.circular(12),
                                                                  ),
                                                                  child:    isPlaying? const Icon(
                                                                    Icons.pause,
                                                                    color: Colors.white,
                                                                    size: 30,
                                                                  ): const Icon(
                                                                    Icons.play_arrow_rounded,
                                                                    color: Colors.white,
                                                                    size: 30,
                                                                  ),
                                                                ),
                                                              ),

                                                            ],
                                                          ),



                                                          /// 3 DOT MENU
                                                          trailing: GestureDetector(
                                                            onTap: () =>
                                                                _openSongOptions(context, song,isPlaying,index),
                                                            child: const Icon(Icons.more_vert,
                                                                color: Colors.white70),
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
                            },
                            child: SizedBox(
                              height: 22,
                              width: 22,
                              child: Image.asset(
                                'assets/multimedia.png',
                                color: Colors.white,
                              ),
                            ),
                          ),


                          GestureDetector(
                              onTap: () async {
                                _launchYoutubeSearch(mediaItem.title);
                              },
                              child: SizedBox(
                                  height: 20.sp,
                                  width: 20.sp,
                                  child: Image.asset('assets/video.png',color:Colors.white,))
                          ),

                          GestureDetector(
                              onTap: () async {
                                _launchGoogleSearch(
                                    'lyrics ${mediaItem.title}');
                              },
                              child: SizedBox(
                                  height: 20.sp,
                                  width: 20.sp,
                                  child: Image.asset('assets/song_lyrics.png',))
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 20.sp),

                    const SizedBox(height: 20),

                    /// ⏱ SEEK BAR
                    StreamBuilder<PositionData>(
                      stream: Rx.combineLatest2<
                          Duration,
                          Duration?,
                          PositionData>(
                        audio.player.positionStream,
                        audio.player.durationStream,
                            (p, d) =>
                            PositionData(p, d ?? Duration.zero),
                      ),
                      builder: (context, snapshot) {
                        final position =
                            snapshot.data?.position ??
                                Duration.zero;
                        final duration =
                            snapshot.data?.duration ??
                                Duration.zero;

                        return Column(
                          children: [
                            Slider(
                              min: 0,
                              max: duration.inMilliseconds
                                  .toDouble()
                                  .clamp(1, double.infinity),
                              value: position
                                  .inMilliseconds
                                  .clamp(
                                  0,
                                  duration.inMilliseconds
                                      .clamp(1, double.infinity))
                                  .toDouble(),
                              activeColor: Colors.white,
                              inactiveColor: Colors.white24,
                              onChanged: (value) {
                                audio.player.seek(
                                  Duration(
                                      milliseconds:
                                      value.toInt()),
                                );
                              },
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24),
                              child: Row(
                                mainAxisAlignment:
                                MainAxisAlignment
                                    .spaceBetween,
                                children: [
                                  Text(
                                    _format(position),
                                    style: const TextStyle(
                                        color: Colors.white60,
                                        fontSize: 12),
                                  ),
                                  Text(
                                    _format(duration),
                                    style: const TextStyle(
                                        color: Colors.white60,
                                        fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 20),

                    /// 🎛 CONTROLS
                    Padding(
                      padding:
                      const EdgeInsets.only(bottom: 51),
                      child: Row(
                        mainAxisAlignment:
                        MainAxisAlignment.spaceEvenly,
                        children: [
                          /// 🔀 SHUFFLE
                          StreamBuilder<bool>(
                            stream: audio.player
                                .shuffleModeEnabledStream,
                            builder: (context, snapshot) {
                              final enabled =
                                  snapshot.data ?? false;
                              return IconButton(
                                icon: Icon(
                                  Icons.shuffle,
                                  color: enabled
                                      ? Colors.green
                                      : Colors.white,
                                ),
                                onPressed: () => audio.player
                                    .setShuffleModeEnabled(
                                    !enabled),
                              );
                            },
                          ),

                          /// ⏮
                          IconButton(
                            icon: const Icon(
                              Icons.skip_previous,
                              color: Colors.white,
                              size: 40,
                            ),
                            onPressed: audio.previous,
                          ),

                          /// ▶️ / ⏸
                          StreamBuilder<PlayerState>(
                            stream:
                            audio.player.playerStateStream,
                            builder: (context, snapshot) {
                              final playing =
                                  snapshot.data?.playing ??
                                      false;
                              return IconButton(
                                icon: Icon(
                                  playing
                                      ? Icons
                                      .pause_circle_filled
                                      : Icons
                                      .play_circle_filled,
                                  color: Colors.white,
                                  size: 70,
                                ),
                                onPressed: () {
                                  playing
                                      ? audio.pause()
                                      : audio.play();
                                },
                              );
                            },
                          ),

                          /// ⏭
                          IconButton(
                            icon: const Icon(
                              Icons.skip_next,
                              color: Colors.white,
                              size: 40,
                            ),
                            onPressed: audio.next,
                          ),

                          /// 🔁 LOOP
                          StreamBuilder<LoopMode>(
                            stream:
                            audio.player.loopModeStream,
                            builder: (context, snapshot) {
                              final mode =
                                  snapshot.data ?? LoopMode.off;
                              return IconButton(
                                icon: Icon(
                                  mode == LoopMode.one
                                      ? Icons.repeat_one
                                      : Icons.repeat,
                                  color: mode == LoopMode.off
                                      ? Colors.white
                                      : Colors.green,
                                ),
                                onPressed: () {
                                  audio.player.setLoopMode(
                                    mode == LoopMode.one
                                        ? LoopMode.off
                                        : LoopMode.one,
                                  );
                                },
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _format(Duration d) {
    final m =
    d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s =
    d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$m:$s";
  }

  void _openSongOptions(BuildContext context, SongModel song,bool isPlaying,int index ) {
    final audio = GlobalAudioController();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Color(0xFF121212),
            borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade700,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),

              _optionTile(
                icon: Icons.play_arrow_rounded,
                title: "Play",
                color: const Color(0xFF2EDFB4),
                onTap: () {
                if( isPlaying){

                  }else{
                    audio.player
                        .seek(Duration.zero, index: index);
                    audio.player.play();
                    audio.currentIndex.value = index;

                  }

                  Navigator.pop(context);
                },
              ),

              _optionTile(
                icon: Icons.share_rounded,
                title: "Share",
                onTap: () {
                  Share.share(
                    '${song.title}\n${song.artist}\n ${song.uri.toString()}',
                    subject: song.title,
                    sharePositionOrigin: Rect.fromCircle(
                      center: Offset(0, 0),
                      radius: 100,
                    ),
                  );
                  Navigator.pop(context);
                },
              ),

              _optionTile(
                icon: Icons.info_outline_rounded,
                title: "Song Info",
                onTap: () {
                  Navigator.pop(context);
                  _showSongInfo(context, song);
                },
              ),

              _optionTile(
                icon: Icons.delete_outline_rounded,
                title: "Delete",
                color: Colors.redAccent,
                onTap: () {
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }
  Widget _optionTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color color = Colors.white,
  }) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(
        title,
        style: GoogleFonts.poppins(
          color: color,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
    );
  }
  void _showSongInfo(BuildContext context, SongModel song) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF121212),
        title: const Text("Song Info",
            style: TextStyle(color: Colors.white)),
        content: Text(
          "Title: ${song.title}\n"
              "Artist: ${song.artist}\n"
              "Duration: ${song.duration}",
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          )
        ],
      ),
    );
  }

}
