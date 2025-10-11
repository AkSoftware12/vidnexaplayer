import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:on_audio_query_forked/on_audio_query.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../HexColorCode/HexColor.dart';
import '../Utils/common.dart';

class DemMp3Player extends StatefulWidget {
  final List<SongModel> songs;
  final int initialIndex;
  final AudioPlayer audioPlayer;

  const DemMp3Player({
    super.key,
    required this.songs,
    required this.initialIndex,
    required this.audioPlayer,
  });

  @override
  State<DemMp3Player> createState() => _Mp3PlayerState();
}

class _Mp3PlayerState extends State<DemMp3Player> {
  late int currentIndex;
  bool _isPlaying = false;
  bool _isRepeat = false;
  bool _isShuffle = false;


  void _setAudioSource([int? index]) {
    final player = widget.audioPlayer;
    if (player == null) {
      print("Audio player is not initialized");
      return;
    }
    player
        .setAudioSource(AudioSource.uri(
        Uri.parse(widget.songs[index ?? currentIndex].uri.toString())))
        .catchError((error) {
      print("An error occurred $error");
    });
  }
  void _playNext() {
    if (_isShuffle) {
      currentIndex = (widget.songs.length *
          (DateTime.now().millisecondsSinceEpoch % 1000) ~/
          1000) %
          widget.songs.length;
    } else {
      if (currentIndex < widget.songs.length - 1) {
        currentIndex++;
      } else if (_isRepeat) {
        currentIndex = 0;
      } else {
        return;
      }
    }
    _setAudioSource();
    widget.audioPlayer.play();
    setState(() {
      _isPlaying = true;
    });
  }

  void _playPrevious() {
    if (currentIndex > 0) {
      currentIndex--;
    } else if (_isRepeat) {
      currentIndex = widget.songs.length - 1;
    } else {
      return;
    }
    _setAudioSource();
    widget.audioPlayer.play();
    setState(() {
      _isPlaying = true;
    });
  }
  Duration? selectedTimer;
  final List<Duration> timerOptions = [
    Duration(minutes: 1),
    Duration(minutes: 10),
    Duration(minutes: 15),
    Duration(minutes: 20),
    Duration(minutes: 25),
    Duration(minutes: 30),
    Duration(minutes: 35),
    Duration(minutes: 40),
    Duration(minutes: 45),
    Duration(minutes: 50),
    Duration(minutes: 55),
    Duration(minutes: 60),
    Duration(minutes: 90),
    Duration(minutes: 120),
  ];
  void _togglePlayPause() {
    setState(() {
      if (_isPlaying) {
        widget.audioPlayer.pause();
      } else {
        widget.audioPlayer.play();
      }
      _isPlaying = !_isPlaying;
    });
  }

  Future<void> _launchGoogleSearch(String query) async {
    final Uri url = Uri.parse('https://www.google.com/search?q=$query');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      throw 'Could not launch $url';
    }
  }

  Future<void> _launchYoutubeSearch(String query) async {
    final Uri url = Uri.parse('https://www.youtube.com/search?q=$query');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      throw 'Could not launch $url';
    }
  }

  Timer? countdownTimer;

  void setTimer(Duration duration) {
    setState(() {
      selectedTimer = duration;
      if (duration == Duration.zero) {
        widget.audioPlayer.pause(); // Pause the player if the selected timer is 0
      }
      Navigator.pop(context);
    });
  }
  @override
  void initState() {
    super.initState();
    currentIndex = widget.initialIndex;

  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title:  Padding(
          padding: EdgeInsets.all(10.sp),
          child: Padding(
            padding: EdgeInsets.only(top: 28.sp),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                  },
                  child: Icon(
                    Icons.arrow_back_ios,
                    color: Colors.white,
                    size: 20.sp,
                  ),
                ),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: GestureDetector(
                        onTap: () {
                          // Navigator.pop(context);
                        },
                        child: Icon(
                          Icons.info,
                          color: Colors.white,
                          size: 20.sp,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: GestureDetector(
                        onTap: () {
                          // showDialog(
                          //   context: context,
                          //   builder: (BuildContext context) {
                          //     return AlertDialog(
                          //       titlePadding: const EdgeInsets.all(0),
                          //       contentPadding: const EdgeInsets.all(0),
                          //       shape: RoundedRectangleBorder(
                          //         borderRadius: MediaQuery.of(context).orientation == Orientation.portrait
                          //             ? const BorderRadius.vertical(
                          //           top: Radius.circular(500),
                          //           bottom: Radius.circular(100),
                          //         )
                          //             : const BorderRadius.horizontal(right: Radius.circular(500)),
                          //       ),
                          //       content: SingleChildScrollView(
                          //         child: HueRingPicker(
                          //           pickerColor: currentColor,
                          //           onColorChanged: changeColor,
                          //           enableAlpha: _enableAlpha2,
                          //           displayThumbColor: _displayThumbColor2,
                          //         ),
                          //       ),
                          //     );
                          //   },
                          // );
                        },
                        child: Icon(
                          Icons.color_lens,
                          color: Colors.white,
                          size: 20.sp,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: GestureDetector(
                        onTap: () {
                          Share.share(
                            '${widget.songs[currentIndex].title}\n${widget.songs[currentIndex].artist}\n ${widget.songs[ currentIndex].uri.toString()}',
                            subject: '${widget.songs[currentIndex].title}',
                            sharePositionOrigin: Rect.fromCircle(
                              center: Offset(0, 0),
                              radius: 100,
                            ),
                          );
                        },
                        child: Icon(
                          Icons.share,
                          color: Colors.white,
                          size: 20.sp,
                        ),
                      ),
                    ),
                  ],
                )

              ],
            ),
          ),
        ),
        backgroundColor: Colors.black87,
      ),
      body: Container(
        color: Colors.black87,
        padding: EdgeInsets.all(10.sp),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [

            SizedBox(height: 10.h),

            QueryArtworkWidget(
              controller: OnAudioQuery(),
              id: widget.songs[currentIndex].id,
              type: ArtworkType.AUDIO,
              artworkBorder: BorderRadius.circular(8),
              artworkWidth: 300.sp,
              artworkHeight: 300.sp,
              nullArtworkWidget: Image.asset(
                'assets/music_folder.png',
                width: 200.w,
                height: 200.h,
              ),
            ),
            SizedBox(height: 20.h),
            Text(
              widget.songs[currentIndex].title,
              style: GoogleFonts.openSans(
                textStyle: TextStyle(
                  color: Colors.white,
                  fontSize: 20.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              widget.songs[currentIndex].artist ?? "No Artist",
              style: GoogleFonts.poppins(
                textStyle: TextStyle(
                  color: Colors.grey,
                  fontSize: 14.sp,
                ),
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 20.h),
            SizedBox(height: 40.sp),
            Padding(
              padding:  EdgeInsets.only(left: 18.sp,right: 18.sp),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [

                  GestureDetector(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              title: Text('Sleep Timer'),
                              content: Container(
                                height: 200,
                                width: 200,
                                child: ListView.builder(
                                  itemCount: timerOptions.length,
                                  itemBuilder: (BuildContext context, int index) {
                                    final duration = timerOptions[index];
                                    final minutes = duration.inMinutes;
                                    bool isSelected = duration == selectedTimer;
                                    return ListTile(
                                      title: Text(
                                        '$minutes minutes',
                                        style: TextStyle(
                                          color: isSelected
                                              ? Colors
                                              .blue // Customize the selected option's text color
                                              : null,
                                        ),
                                      ),
                                      onTap: () {
                                        setTimer(
                                            duration); // Set the selected timer
                                      },
                                    );
                                  },
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      selectedTimer = null;
                                      Navigator.pop(context);
                                    });
                                  },
                                  child: Text('Cancel'),
                                ),
                              ],
                            );
                          },
                        );
                      },
                      child: SizedBox(
                          height: 20.sp,
                          width: 20.sp,
                          child: Image.asset('assets/snooze.png',color:Colors.white,))
                  ),

                  // GestureDetector(
                  //     onTap: () async {
                  //       showSliderDialog(
                  //         context: context,
                  //         title: "Adjust volume",
                  //         divisions: 10,
                  //         min: 0.0,
                  //         max: 1.0,
                  //         stream: _player.volumeStream,
                  //         onChanged: _player.setVolume,
                  //       );
                  //     },
                  //     child: SizedBox(
                  //         height: 20.sp,
                  //         width: 20.sp,
                  //         child: Image.asset('assets/snooze.png'))
                  // ),
                  GestureDetector(
                      onTap: () async {
                        showSliderDialog(
                          context: context,
                          title: "Adjust volume",
                          divisions: 10,
                          min: 0.0,
                          max: 1.0,
                          stream: widget.audioPlayer.volumeStream,
                          onChanged: widget.audioPlayer.setVolume,
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
                      onTap: () async {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          builder: (BuildContext context) {
                            return Container(
                              decoration: const BoxDecoration(
                                color: Colors.black,
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(30),
                                  topRight: Radius.circular(30),
                                ),
                                border: Border(
                                  left: BorderSide(
                                    color: Colors.grey,
                                    width: 1.0,
                                  ),
                                  top: BorderSide(
                                    color: Colors.grey,
                                    width: 1.0,
                                  ),
                                  right: BorderSide(
                                    color: Colors.grey,
                                    width: 1.0,
                                  ),
                                ),
                              ),
                              height: MediaQuery.of(context).size.height * 0.5,
                              child: ListView.builder(
                                shrinkWrap: true,
                                itemCount: widget.songs.length,
                                itemBuilder: (context, index) {
                                  bool isCurrentlyPlaying = currentIndex ==
                                      index; // Check if this is the currently playing song
                                  return ListTile(
                                    title: Stack(
                                      children: [
                                        Text(
                                          widget.songs[index].title,
                                          style: GoogleFonts.poppins(
                                            textStyle: TextStyle(
                                              color: Colors.white,
                                              fontSize: 15,
                                              fontWeight: FontWeight.normal,
                                            ),
                                          ),
                                        ),
                                        if (isCurrentlyPlaying)
                                          Text(
                                            widget.songs[index].title,
                                            style: GoogleFonts.poppins(
                                              textStyle: TextStyle(
                                                color: HexColor('#2edfb4'),
                                                fontSize: 15,
                                                fontWeight: FontWeight.normal,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    subtitle: Stack(
                                      children: [
                                        Text(
                                          widget.songs[index].artist ?? "No Artist",
                                          style: GoogleFonts.poppins(
                                            textStyle: TextStyle(
                                              color: Colors.grey,
                                              fontSize: 13,
                                              fontWeight: FontWeight.normal,
                                            ),
                                          ),
                                        ),
                                        if (isCurrentlyPlaying)
                                          Text(
                                            widget.songs[index].artist ??
                                                "No Artist",
                                            style: GoogleFonts.poppins(
                                              textStyle: TextStyle(
                                                color: HexColor('#2edfb4'),
                                                fontSize: 13,
                                                fontWeight: FontWeight.normal,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    trailing: SizedBox(
                                      width: 50.sp,
                                      child: Row(
                                        mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                        children: [
                                          if (isCurrentlyPlaying)
                                            SizedBox(
                                                height: 20.sp,
                                                width: 20.sp,
                                                child: Image.asset(
                                                  'assets/currentsong.png',
                                                  color: HexColor('#2edfb4'),
                                                )),
                                          Container(
                                            width: 10,
                                            height: 10,
                                          ),
                                          Icon(
                                            Icons.more_vert,
                                            color: isCurrentlyPlaying
                                                ? HexColor('#2edfb4')
                                                : Colors.white,
                                            size: 20,
                                          ),
                                        ],
                                      ),
                                    ),
                                    leading: Stack(
                                      children: [
                                        QueryArtworkWidget(
                                          id: widget.songs[index].id,
                                          type: ArtworkType.AUDIO,
                                        ),
                                      ],
                                    ),
                                    onTap: () {
                                      setState(() {
                                        currentIndex = index;
                                        // _setAudioSource(index);
                                        widget.audioPlayer.play();
                                        _isPlaying = true;
                                      });
                                      Navigator.pop(context);
                                    },
                                  );
                                },
                              ),
                            );
                          },
                        );
                      },
                      child: SizedBox(
                          height: 20.sp,
                          width: 20.sp,
                          child: Image.asset('assets/multimedia.png',color:Colors.white,))
                  ),
                  GestureDetector(
                      onTap: () async {
                        _launchYoutubeSearch(
                            '${'${widget.songs[currentIndex].title}'}');
                      },
                      child: SizedBox(
                          height: 20.sp,
                          width: 20.sp,
                          child: Image.asset('assets/video.png',color:Colors.white,))
                  ),

                  GestureDetector(
                      onTap: () async {
                        _launchGoogleSearch(
                            '${'lyrics ${widget.songs[currentIndex].title}'}');
                      },
                      child: SizedBox(
                          height: 20.sp,
                          width: 20.sp,
                          child: Image.asset('assets/song_lyrics.png'))
                  ),
                ],
              ),
            ),
            SizedBox(height: 20.sp),
            StreamBuilder<Duration?>(
              stream: widget.audioPlayer.positionStream,
              builder: (context, snapshot) {
                final position = snapshot.data ?? Duration.zero;
                final duration = widget.audioPlayer.duration ?? Duration.zero;
                return Column(
                  children: [
                    Slider(
                      value: position.inSeconds.toDouble(),
                      max: duration.inSeconds.toDouble(),
                      onChanged: (value) {
                        widget.audioPlayer.seek(Duration(seconds: value.toInt()));
                      },
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDuration(position),
                          style: TextStyle(color: Colors.white, fontSize: 12.sp),
                        ),
                        Text(
                          _formatDuration(duration),
                          style: TextStyle(color: Colors.white, fontSize: 12.sp),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
            SizedBox(height: 20.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: Icon(Icons.shuffle,
                      color: _isShuffle
                          ? Colors.orange
                          : Colors.white),
                  iconSize: 20.sp,
                  onPressed: () {
                    setState(() {
                      _isShuffle = !_isShuffle;
                    });
                  },
                ),
                SizedBox(
                  width: 20.sp,
                ),
                IconButton(
                  icon: Icon(Icons.skip_previous,
                      color: Colors.white),
                  iconSize: 35.sp,
                  onPressed: _playPrevious,
                ),
                IconButton(
                  icon: Icon(
                      _isPlaying
                          ? Icons.pause_circle_outline_sharp
                          : Icons.play_circle_outline_sharp,
                      color: Colors.white),
                  iconSize: 60.sp,
                  onPressed: _togglePlayPause,
                ),
                IconButton(
                  icon: Icon(Icons.skip_next, color: Colors.white),
                  iconSize: 35.sp,
                  onPressed: _playNext,
                ),
                SizedBox(
                  width: 20.sp,
                ),
                IconButton(
                  icon: Icon(Icons.repeat,
                      color:
                      _isRepeat ? Colors.orange : Colors.white),
                  iconSize: 20.sp,
                  onPressed: () {
                    setState(() {
                      _isRepeat = !_isRepeat;
                    });
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}