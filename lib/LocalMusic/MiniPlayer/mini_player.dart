import 'dart:io';
import 'dart:ui';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:on_audio_query_forked/on_audio_query.dart';
import 'package:path_provider/path_provider.dart';
import 'package:rxdart/rxdart.dart';
import 'package:videoplayer/Utils/color.dart';

import '../AUDIOCONTROLLER/global_audio_controller.dart';
import '../FullScreenPlayer/full_player_screen.dart';


/// ================= POSITION DATA =================
class PositionData {
  final Duration position;
  final Duration duration;

  PositionData(this.position, this.duration);
}

/// ================= MINI PLAYER ===================
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final audio = GlobalAudioController();

    return ValueListenableBuilder<bool>(
      valueListenable: audio.hasPlayedOnce,
      builder: (context, hasPlayed, _) {
        if (!hasPlayed) return const SizedBox();

        return StreamBuilder<PlayerState>(
          stream: audio.player.playerStateStream,
          builder: (context, snapshot) {
            final sequenceState = audio.player.sequenceState;
            if (sequenceState == null || sequenceState.sequence.isEmpty) {
              return const SizedBox();
            }

            final state = snapshot.data;
            final mediaItem =
            sequenceState.currentSource!.tag as MediaItem;

            return Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: ClipRRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                    child: GestureDetector(
                      onTap: (){
                        Navigator.push(
                          context,
                          PageRouteBuilder(
                            transitionDuration: const Duration(milliseconds: 1000),
                            reverseTransitionDuration: const Duration(milliseconds: 800),
                            pageBuilder: (context, animation, secondaryAnimation) {
                              return const FullPlayerScreen();
                            },
                            transitionsBuilder:
                                (context, animation, secondaryAnimation, child) {
                              final tween = Tween<Offset>(
                                begin: const Offset(0, 1), // 👇 bottom
                                end: Offset.zero,          // 👆 top
                              ).chain(
                                CurveTween(curve: Curves.easeOutCubic),
                              );

                              return SlideTransition(
                                position: animation.drive(tween),
                                child: child,
                              );
                            },
                          ),
                        );

                      },
                      child: Container(
                        color: ColorSelect.maineColor2,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [

                            // ================= PLAYER ROW =================
                            SizedBox(
                              height: 60,
                              child: Row(
                                children: [
                                  QueryArtworkWidget(
                                    id: int.parse(mediaItem.id),
                                    type: ArtworkType.AUDIO,
                                    artworkBorder: BorderRadius.circular(0),
                                    artworkWidth: 60,
                                    artworkHeight: 60,
                                    artworkFit: BoxFit.cover,
                                    nullArtworkWidget: Container(
                                      width: 60,
                                      height: 60,
                                      alignment: Alignment.center,
                                      color: Colors.white.withOpacity(.15),
                                      child: const Icon(
                                        Icons.music_note_rounded,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),

                                  const SizedBox(width: 10),

                                  Expanded(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          mediaItem.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 15,
                                          ),
                                        ),
                                        Text(
                                          mediaItem.artist ?? '',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white60,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  IconButton(
                                    icon: const Icon(
                                      Icons.skip_previous_rounded,
                                      color: Colors.white,
                                      size: 32,
                                    ),
                                    onPressed: audio.previous,
                                  ),

                                  IconButton(
                                    icon: Icon(
                                      state?.playing == true
                                          ? Icons.pause_circle_filled_rounded
                                          : Icons.play_circle_fill_rounded,
                                      color: Colors.white,
                                      size: 38,
                                    ),
                                    onPressed: () {
                                      state?.playing == true
                                          ? audio.pause()
                                          : audio.play();
                                    },
                                  ),

                                  IconButton(
                                    icon: const Icon(
                                      Icons.skip_next_rounded,
                                      color: Colors.white,
                                      size: 32,
                                    ),
                                    onPressed: audio.next,
                                  ),

                                  IconButton(
                                    icon: const Icon(
                                      Icons.close_rounded,
                                      color: Colors.white70,
                                    ),
                                    onPressed: audio.closeMiniPlayer,
                                  ),
                                ],
                              ),
                            ),

                            // ================= SEEK BAR =================
                            StreamBuilder<PositionData>(
                              stream: Rx.combineLatest2<Duration, Duration?,
                                  PositionData>(
                                audio.player.positionStream,
                                audio.player.durationStream,
                                    (position, duration) =>
                                    PositionData(position,
                                        duration ?? Duration.zero),
                              ),
                              builder: (context, snapshot) {
                                final positionData = snapshot.data;
                                final position =
                                    positionData?.position ?? Duration.zero;
                                final duration =
                                    positionData?.duration ?? Duration.zero;

                                return SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    trackHeight: 2,
                                    thumbShape:
                                    const RoundSliderThumbShape(
                                        enabledThumbRadius: 0),
                                    overlayShape:
                                    SliderComponentShape.noOverlay,
                                  ),
                                  child: Slider(
                                    min: 0,
                                    max: duration.inMilliseconds.toDouble(),
                                    value: position.inMilliseconds
                                        .clamp(
                                        0, duration.inMilliseconds)
                                        .toDouble(),
                                    activeColor: Colors.red,
                                    inactiveColor: Colors.white24,
                                    onChanged: (value) {
                                      audio.player.seek(
                                        Duration(
                                            milliseconds: value.toInt()),
                                      );
                                    },
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}