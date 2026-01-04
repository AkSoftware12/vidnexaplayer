import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:on_audio_query_forked/on_audio_query.dart';

import '../../../../../LocalMusic/AUDIOCONTROLLER/global_audio_controller.dart';
import '../../../../../Mp3Player/mp3_player.dart';

class GenrePage extends StatefulWidget {
  final GenreModel genre;
  final Color color;
  final Color colortext;

  const GenrePage({Key? key, required this.genre, required this.color, required this.colortext}) : super(key: key);

  @override
  State<GenrePage> createState() => _GenrePageState();
}

class _GenrePageState extends State<GenrePage> {
  late List<SongModel> _songs;
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
      AudiosFromType.GENRE_ID,
      widget.genre.id,
    );

    // remove songs less than 10 seconds long (10,000 milliseconds)
    songs.removeWhere((song) => (song.duration ?? 0) < 10000);

    setState(() {
      _songs = songs;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.color,
      appBar: AppBar(
        backgroundColor: widget.color,
        leading: IconButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          icon:  Icon(
            Icons.arrow_back_ios_rounded,color:widget.colortext,

          ),
        ),
        title: Text(
          widget.genre.genre, style: TextStyle(
          color:widget.colortext,

        ),
        ),
      ),
      body: Ink(
        decoration: BoxDecoration(

          color: widget.color,
          // gradient: Themes.getTheme().linearGradient,
        ),
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: _songs.length,
                    itemBuilder: (context, index) {
                      final SongModel song = _songs[index];

                      return ListTile(
                        onTap: () async {

                          audio.playSongs(_songs, index);

                        },
                        leading:  QueryArtworkWidget(
                          id: _songs[index].id,
                          type: ArtworkType.AUDIO,
                          artworkFit: BoxFit.cover,
                          nullArtworkWidget: Icon(
                            Icons.music_note,
                            size: 48,
                            color: Colors.blue,
                          ),
                          artworkBorder: BorderRadius.circular(8.0),
                        ),

                        // QueryArtworkWidget(
                        //   id: _songs[index].id,
                        //   type: ArtworkType.ALBUM,
                        //   artworkBorder: BorderRadius.circular(10),
                        //   nullArtworkWidget: Container(
                        //     width: 48,
                        //     height: 48,
                        //     decoration: BoxDecoration(
                        //       borderRadius: BorderRadius.circular(10),
                        //       color: Colors.grey.withOpacity(0.1),
                        //     ),
                        //     child: const Icon(
                        //       Icons.music_note_outlined,
                        //     ),
                        //   ),
                        // ),
                        title: Text(
                          _songs[index].title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:  TextStyle(
                              fontWeight: FontWeight.bold,
                            color: widget.colortext,

                          ),
                        ),
                        subtitle: Text(  '${_songs[index].artist}  ${' / '}${_songs[index].album}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:  TextStyle(  color:widget.colortext,
                          ),
                        ),
                        // trailing: IconButton(
                        //   onPressed: () {
                        //     // add to queue, add to playlist, delete, share
                        //     showModalBottomSheet(
                        //       shape: const RoundedRectangleBorder(
                        //         borderRadius: BorderRadius.vertical(
                        //           top: Radius.circular(25),
                        //         ),
                        //       ),
                        //       context: context,
                        //       builder: (context) {
                        //         return Wrap(
                        //           children: [
                        //             ListTile(
                        //               // border radius same as bottom sheet
                        //               shape: const RoundedRectangleBorder(
                        //                 borderRadius: BorderRadius.vertical(
                        //                   top: Radius.circular(25),
                        //                 ),
                        //               ),
                        //               leading: const Icon(Icons.playlist_add),
                        //               title: const Text('Add to queue'),
                        //               onTap: () {
                        //                 Navigator.of(context).pop();
                        //               },
                        //             ),
                        //             ListTile(
                        //               leading: const Icon(Icons.playlist_add),
                        //               title: const Text('Add to playlist'),
                        //               onTap: () {
                        //                 Navigator.of(context).pop();
                        //               },
                        //             ),
                        //             ListTile(
                        //               leading: const Icon(Icons.delete),
                        //               title: const Text('Delete'),
                        //               onTap: () {
                        //                 // Show a confirmation dialog before deleting the song
                        //                 showDialog(
                        //                   context: context,
                        //                   builder: (BuildContext context) {
                        //                     return AlertDialog(
                        //                       title: const Text('Delete Song'),
                        //                       content: const Text(
                        //                           'Are you sure you want to delete this song?'),
                        //                       actions: <Widget>[
                        //                         TextButton(
                        //                           onPressed: () {
                        //                             Navigator.of(context).pop();
                        //                           },
                        //                           child: const Text('Cancel'),
                        //                         ),
                        //                         TextButton(
                        //                           onPressed: () async {
                        //                             // Delete the song from the database
                        //                             final file = File(widget.song.data);
                        //
                        //                             if (await file.exists()) {
                        //                               debugPrint('Deleting ${widget.song.title}');
                        //                               try {
                        //                                 // ask for permission to manage external storage if not granted
                        //                                 if (!await Permission
                        //                                     .manageExternalStorage.isGranted) {
                        //                                   final status = await Permission
                        //                                       .manageExternalStorage
                        //                                       .request();
                        //
                        //                                   if (status.isGranted) {
                        //                                     debugPrint('Permission granted');
                        //                                   } else {
                        //                                     if (mounted) {
                        //                                       ScaffoldMessenger.of(context)
                        //                                           .showSnackBar(
                        //                                         const SnackBar(
                        //                                           content: Text(
                        //                                             'Permission denied',
                        //                                           ),
                        //                                           backgroundColor: Colors.red,
                        //                                         ),
                        //                                       );
                        //                                     }
                        //                                   }
                        //                                 }
                        //                                 await file.delete();
                        //                                 debugPrint(
                        //                                     'Deleted ${widget.song.title}');
                        //                               } catch (e) {
                        //                                 debugPrint(
                        //                                     'Failed to delete ${widget.song.title}');
                        //                               }
                        //                             } else {
                        //                               debugPrint(
                        //                                   'File does not exist ${widget.song.title}');
                        //                             }
                        //
                        //                             // TODO: Remove the song from the list
                        //
                        //                             if (mounted) {
                        //                               Navigator.of(context).pop();
                        //                               Navigator.of(context).pop();
                        //                             }
                        //                           },
                        //                           child: const Text('Delete'),
                        //                         ),
                        //                       ],
                        //                     );
                        //                   },
                        //                 );
                        //               },
                        //             ),
                        //             ListTile(
                        //               leading: const Icon(Icons.share),
                        //               title: const Text('Share'),
                        //               onTap: () async {
                        //                 List<XFile> files = [];
                        //                 // convert song to xfile
                        //                 final songFile = XFile(widget.song.data);
                        //                 files.add(songFile);
                        //                 await Share.shareXFiles(
                        //                   files,
                        //                   text: widget.song.title,
                        //                 );
                        //                 if (mounted) {
                        //                   Navigator.of(context).pop();
                        //                 }
                        //               },
                        //             ),
                        //           ],
                        //         );
                        //       },
                        //     );
                        //   },
                        //   icon: const Icon(Icons.more_vert),
                        // ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
