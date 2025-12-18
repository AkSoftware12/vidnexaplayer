import 'dart:ui';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:on_audio_query_forked/on_audio_query.dart';
import 'package:rxdart/rxdart.dart';
import 'package:videoplayer/Utils/color.dart';

import '../AUDIOCONTROLLER/global_audio_controller.dart';

class PositionData {
  final Duration position;
  final Duration duration;

  PositionData(this.position, this.duration);
}

class FullPlayerScreen extends StatelessWidget {
  const FullPlayerScreen({super.key});

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
                    QueryArtworkWidget(
                      id: int.tryParse(mediaItem.id) ?? 0,
                      type: ArtworkType.AUDIO,
                      artworkFit: BoxFit.cover,
                      artworkHeight: 280,
                      artworkWidth: 280,
                      nullArtworkWidget: Container(
                        height: 280,
                        width: 280,
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius:
                          BorderRadius.circular(20),
                        ),
                        child: const Icon(
                          Icons.music_note,
                          color: Colors.white,
                          size: 80,
                        ),
                      ),
                    ),

                    const SizedBox(height: 30),
                    const Spacer(),

                    /// 🎵 TITLE + ARTIST
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Text(
                                  mediaItem.title,
                                  maxLines: 1,
                                  overflow:
                                  TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  mediaItem.artist ?? 'Unknown Artist',
                                  maxLines: 1,
                                  overflow:
                                  TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white60,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.add_circle_outline,
                            color: Colors.white,
                          ),
                        ],
                      ),
                    ),

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

                    /// 🎛 CONTROLS
                    Padding(
                      padding:
                      const EdgeInsets.only(bottom: 30),
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
}
