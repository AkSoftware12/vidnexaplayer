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
import '../TextScroll/text_scroll.dart';
import '../Utils/common.dart';
import '../Utils/textSize.dart';

class Mp3Player extends StatefulWidget {
  final List<SongModel> songs;
  final int initialIndex;
  final AudioPlayer audioPlayer;


  const Mp3Player({Key? key, required this.songs, required this.initialIndex, required this.audioPlayer})
      : super(key: key);

  @override
  MyAppState createState() => MyAppState();
}

class MyAppState extends State<Mp3Player> {
  late final AudioPlayer _player;
  late int _currentIndex;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isPlaying = false;
  bool _isRepeat = false;
  bool _isShuffle = false;

  Timer? _timer;

  bool lightTheme = true;
  Color currentColor = Colors.black;
  List<Color> currentColors = [Colors.yellow, Colors.green];
  List<Color> colorHistory = [];
  bool _enableAlpha2 = false;
  bool _displayThumbColor2 = true;
  void changeColor(Color color) => setState(() => currentColor = color);
  void changeColors(List<Color> colors) => setState(() => currentColors = colors);
  @override
  void initState() {
    super.initState();

    _player = AudioPlayer();
    _currentIndex = widget.initialIndex;

    _player.play();

    _player.positionStream.listen((position) {
      setState(() {
        _position = position;
      });

      if (selectedTimer != null && _position >= selectedTimer!) {
        _player.pause();
        setState(() {
          selectedTimer = null;
        });
      }
    });
    _player.durationStream.listen((duration) {
      setState(() {
        _duration = duration ?? Duration.zero;
      });
    });
    _player.playerStateStream.listen((playerState) {
      setState(() {
        _isPlaying = playerState.playing;
      });
    });


    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _playNext();
      }
    });
    _setAudioSource();
    // Load the initial audio source
  }




  void _setAudioSource([int? index]) {
    final player = _player;
    if (player == null) {
      print("Audio player is not initialized");
      return;
    }
    player
        .setAudioSource(AudioSource.uri(
            Uri.parse(widget.songs[index ?? _currentIndex].uri.toString())))
        .catchError((error) {
      print("An error occurred $error");
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _player.dispose();
    super.dispose();
  }



  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  void _playNext() {
    if (_isShuffle) {
      _currentIndex = (widget.songs.length *
              (DateTime.now().millisecondsSinceEpoch % 1000) ~/
              1000) %
          widget.songs.length;
    } else {
      if (_currentIndex < widget.songs.length - 1) {
        _currentIndex++;
      } else if (_isRepeat) {
        _currentIndex = 0;
      } else {
        return;
      }
    }
    _setAudioSource();
    _player.play();
    setState(() {
      _isPlaying = true;
    });
  }

  void _playPrevious() {
    if (_currentIndex > 0) {
      _currentIndex--;
    } else if (_isRepeat) {
      _currentIndex = widget.songs.length - 1;
    } else {
      return;
    }
    _setAudioSource();
    _player.play();
    setState(() {
      _isPlaying = true;
    });
  }

  // void _playPrevious() {
  //   if (_currentIndex > 0) {
  //     setState(() {
  //       _currentIndex--;
  //     });
  //   } else if (_isRepeat) {
  //     _currentIndex = widget.songs.length - 1;
  //   } else {
  //     return;
  //   }
  //   _setAudioSource();
  //   _player.play();
  //   setState(() {
  //     _isPlaying = true;
  //   });
  // }

  void _togglePlayPause() {
    setState(() {
      if (_isPlaying) {
        _player.pause();
      } else {
        _player.play();
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
  Timer? countdownTimer;

  void setTimer(Duration duration) {
    setState(() {
      selectedTimer = duration;
      if (duration == Duration.zero) {
        _player.pause(); // Pause the player if the selected timer is 0
      }
      Navigator.pop(context);
    });
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: currentColor,
      body: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Padding(
            padding: EdgeInsets.all(15.sp),
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
                            showDialog(
                              context: context,
                              builder: (BuildContext context) {
                                return AlertDialog(
                                  titlePadding: const EdgeInsets.all(0),
                                  contentPadding: const EdgeInsets.all(0),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: MediaQuery.of(context).orientation == Orientation.portrait
                                        ? const BorderRadius.vertical(
                                      top: Radius.circular(500),
                                      bottom: Radius.circular(100),
                                    )
                                        : const BorderRadius.horizontal(right: Radius.circular(500)),
                                  ),
                                  content: SingleChildScrollView(
                                    child: HueRingPicker(
                                      pickerColor: currentColor,
                                      onColorChanged: changeColor,
                                      enableAlpha: _enableAlpha2,
                                      displayThumbColor: _displayThumbColor2,
                                    ),
                                  ),
                                );
                              },
                            );
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
                              '${widget.songs[_currentIndex].title}\n${widget.songs[_currentIndex].artist}\n ${widget.songs[ _currentIndex].uri.toString()}',
                              subject: '${widget.songs[_currentIndex].title}',
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
          Padding(
            padding: EdgeInsets.all(15.sp),
            child: Column(
              children: [
                Container(
                  height: 300,
                  width: double.infinity,
                  child: QueryArtworkWidget(
                    id: widget.songs[_currentIndex].id,
                    type: ArtworkType.AUDIO,
                    artworkFit: BoxFit.cover,
                    nullArtworkWidget: Icon(
                      Icons.music_note,
                      size: 100,
                      color: Colors.blue,
                    ),
                    artworkBorder: BorderRadius.circular(8.0),
                  ),
                ),

                // Text(
                //   '${widget.songs[_currentIndex].title}',
                //   style: GoogleFonts.poppins(
                //     textStyle: TextStyle(
                //       color: Colors.white,
                //       fontSize: TextSizes.textlarge,
                //       fontWeight: FontWeight.bold,
                //     ),
                //   ),
                // ),
                // Text(
                //   '${widget.songs[_currentIndex].artist}',
                //   style: GoogleFonts.poppins(
                //     textStyle: TextStyle(
                //       color: Colors.grey,
                //       fontSize: TextSizes.textmedium,
                //       fontWeight: FontWeight.normal,
                //     ),
                //   ),
                // ),
              ],
            ),
          ),
          Container(
            child: Container(
              child: Column(
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width),
                      child: Column(
                        children: <Widget>[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Flexible(
                                child: TextScroll(
                                  '${widget.songs[_currentIndex].title}',
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
                              SizedBox(width: 4),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  Text(
                    '${widget.songs[_currentIndex].artist}',
                    style: GoogleFonts.poppins(
                      textStyle: TextStyle(
                        color: Colors.grey,
                        fontSize: TextSizes.textmedium,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ),
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
                                stream: _player.volumeStream,
                                onChanged: _player.setVolume,
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
                                        bool isCurrentlyPlaying = _currentIndex ==
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
                                              _currentIndex = index;
                                              _setAudioSource(index);
                                              _player.play();
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
                                  '${'${widget.songs[_currentIndex].title}'}');
                            },
                            child: SizedBox(
                                height: 20.sp,
                                width: 20.sp,
                                child: Image.asset('assets/video.png',color:Colors.white,))
                        ),

                        GestureDetector(
                          onTap: () async {
                            _launchGoogleSearch(
                                '${'lyrics ${widget.songs[_currentIndex].title}'}');
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
                  Slider(
                    value: _position.inSeconds.toDouble(),
                    onChanged: (value) {
                      setState(() {
                        _player.seek(Duration(seconds: value.toInt()));
                      });
                    },
                    min: 0.0,
                    max: _duration.inSeconds.toDouble(),
                    activeColor: Colors.orangeAccent,
                    inactiveColor: Colors.grey,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDuration(_position),
                          style: GoogleFonts.poppins(
                            textStyle: TextStyle(
                              color: Colors.white,
                              fontSize: TextSizes.textmedium,
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                        ),
                        Text(
                          _formatDuration(_duration),
                          style: GoogleFonts.poppins(
                            textStyle: TextStyle(
                              color: Colors.white,
                              fontSize: TextSizes.textmedium,
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 20),
                  Container(
                    child: Column(
                      children: [
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
                ],
              ),
            ),
          ),

          SizedBox(
            height: 10.sp,
          )
          // Container(
          //   height: 50.sp,
          //   child: Column(
          //     mainAxisAlignment: MainAxisAlignment.end,
          //     children: [
          //       GestureDetector(
          //         onTap: () {
          //           showModalBottomSheet(
          //             context: context,
          //             isScrollControlled: true,
          //             builder: (BuildContext context) {
          //               return Container(
          //                 decoration: const BoxDecoration(
          //                   color: Colors.black,
          //                   borderRadius: BorderRadius.only(
          //                     topLeft: Radius.circular(30),
          //                     topRight: Radius.circular(30),
          //                   ),
          //                   border: Border(
          //                     left: BorderSide(
          //                       color: Colors.grey,
          //                       width: 1.0,
          //                     ),
          //                     top: BorderSide(
          //                       color: Colors.grey,
          //                       width: 1.0,
          //                     ),
          //                     right: BorderSide(
          //                       color: Colors.grey,
          //                       width: 1.0,
          //                     ),
          //                   ),
          //                 ),
          //                 height: MediaQuery.of(context).size.height * 0.5,
          //                 child: ListView.builder(
          //                   shrinkWrap: true,
          //                   itemCount: widget.songs.length,
          //                   itemBuilder: (context, index) {
          //                     bool isCurrentlyPlaying = _currentIndex ==
          //                         index; // Check if this is the currently playing song
          //                     return ListTile(
          //                       title: Stack(
          //                         children: [
          //                           Text(
          //                             widget.songs[index].title,
          //                             style: GoogleFonts.poppins(
          //                               textStyle: TextStyle(
          //                                 color: Colors.white,
          //                                 fontSize: 15,
          //                                 fontWeight: FontWeight.normal,
          //                               ),
          //                             ),
          //                           ),
          //                           if (isCurrentlyPlaying)
          //                             Text(
          //                               widget.songs[index].title,
          //                               style: GoogleFonts.poppins(
          //                                 textStyle: TextStyle(
          //                                   color: HexColor('#2edfb4'),
          //                                   fontSize: 15,
          //                                   fontWeight: FontWeight.normal,
          //                                 ),
          //                               ),
          //                             ),
          //                         ],
          //                       ),
          //                       subtitle: Stack(
          //                         children: [
          //                           Text(
          //                             widget.songs[index].artist ?? "No Artist",
          //                             style: GoogleFonts.poppins(
          //                               textStyle: TextStyle(
          //                                 color: Colors.grey,
          //                                 fontSize: 13,
          //                                 fontWeight: FontWeight.normal,
          //                               ),
          //                             ),
          //                           ),
          //                           if (isCurrentlyPlaying)
          //                             Text(
          //                               widget.songs[index].artist ??
          //                                   "No Artist",
          //                               style: GoogleFonts.poppins(
          //                                 textStyle: TextStyle(
          //                                   color: HexColor('#2edfb4'),
          //                                   fontSize: 13,
          //                                   fontWeight: FontWeight.normal,
          //                                 ),
          //                               ),
          //                             ),
          //                         ],
          //                       ),
          //                       trailing: SizedBox(
          //                         width: 50.sp,
          //                         child: Row(
          //                           mainAxisAlignment:
          //                               MainAxisAlignment.spaceBetween,
          //                           children: [
          //                             if (isCurrentlyPlaying)
          //                               SizedBox(
          //                                   height: 20.sp,
          //                                   width: 20.sp,
          //                                   child: Image.asset(
          //                                     'assets/currentsong.png',
          //                                     color: HexColor('#2edfb4'),
          //                                   )),
          //                             Container(
          //                               width: 10,
          //                               height: 10,
          //                             ),
          //                             Icon(
          //                               Icons.more_vert,
          //                               color: isCurrentlyPlaying
          //                                   ? HexColor('#2edfb4')
          //                                   : Colors.white,
          //                               size: 20,
          //                             ),
          //                           ],
          //                         ),
          //                       ),
          //                       leading: Stack(
          //                         children: [
          //                           QueryArtworkWidget(
          //                             id: widget.songs[index].id,
          //                             type: ArtworkType.AUDIO,
          //                           ),
          //                         ],
          //                       ),
          //                       onTap: () {
          //                         setState(() {
          //                           _currentIndex = index;
          //                           _setAudioSource(index);
          //                           _player.play();
          //                           _isPlaying = true;
          //                         });
          //                         Navigator.pop(context);
          //                       },
          //                     );
          //                   },
          //                 ),
          //               );
          //             },
          //           );
          //         },
          //         child: Container(
          //           height: 50.sp,
          //           width: 200.sp,
          //           child: Column(
          //             children: [
          //               Icon(
          //                 Icons.horizontal_rule_rounded,
          //                 color: Colors.white,
          //                 size: 20.sp,
          //               ),
          //               Text(
          //                 'Up Next',
          //                 style: GoogleFonts.poppins(
          //                   textStyle: TextStyle(
          //                     color: Colors.white,
          //                     fontSize: 14.sp,
          //                     fontWeight: FontWeight.bold,
          //                   ),
          //                 ),
          //               ),
          //             ],
          //           ),
          //         ),
          //       )
          //     ],
          //   ),
          // ),
        ],
      ),
    );
  }
}
