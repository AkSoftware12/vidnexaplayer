import 'package:flutter/material.dart';
import 'package:on_audio_query_forked/on_audio_query.dart' show SongModel, AlbumModel, OnAudioQuery, AudiosFromType, ArtworkType, QueryArtworkWidget;
import '../../../../../Mp3Player/mp3_player.dart';
import '../../song_repository.dart';

class AlbumPage extends StatefulWidget {
  final AlbumModel album;
  final Color color;
  final Color colortext;

  const AlbumPage({Key? key, required this.album, required this.color, required this.colortext}) : super(key: key);

  @override
  State<AlbumPage> createState() => _AlbumPageState();
}

class _AlbumPageState extends State<AlbumPage> {
  late List<SongModel> _songs;
  late final SongRepository songRepository;

  @override
  void initState() {
    super.initState();
    // songRepository = context.read<SongRepository>();
    _songs = [];
    _getSongs();
  }

  Future<void> _getSongs() async {
    final OnAudioQuery audioQuery = OnAudioQuery();

    final List<SongModel> songs = await audioQuery.queryAudiosFrom(
      AudiosFromType.ALBUM_ID,
      widget.album.id,
    );

    // remove songs less than 10 seconds long (10,000 milliseconds)
    songs.removeWhere((song) => (song.duration ?? 0) < 10000);

    // await songRepository.addSongsToQueue(songs);
    setState(() {
      _songs = songs;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      backgroundColor: widget.color,
      body: Ink(
        padding: EdgeInsets.fromLTRB(
          24,
          MediaQuery.of(context).padding.top + 16,
          24,
          16,
        ),
        decoration: BoxDecoration(
          // gradient: Themes.getTheme().linearGradient,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // back button
            Row(
              children: [
                IconButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  icon:  Icon(
                    Icons.arrow_back_ios_rounded,color:widget.colortext,
                  ),
                ),
              ],
            ),
            // album artwork
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: QueryArtworkWidget(
                  id: widget.album.id,
                  type: ArtworkType.ALBUM,
                  artworkQuality: FilterQuality.high,
                  nullArtworkWidget: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.music_note_outlined,
                      size: 100,
                    ),
                  ),
                  artworkBorder: BorderRadius.circular(10),
                  artworkWidth: double.infinity,
                  artworkHeight: double.infinity,
                  artworkFit: BoxFit.fill,
                ),
              ),
            ),
            const SizedBox(height: 16),
            // album name
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                widget.album.album,
                style:  TextStyle(
                  fontSize: 24,
                  color:widget.colortext,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            // artist name
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                widget.album.artist ?? 'Unknown',
                style: const TextStyle(
                  fontSize: 18,
                  color: Colors.grey,
                ),
              ),
            ),
            const SizedBox(height: 16),
            // songs
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: _songs.length,
                itemBuilder: (context, index) {
                  final SongModel song = _songs[index];
                  return ListTile(
                    onTap: () async {

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) {
                            return  Mp3Player(
                              songs: _songs,
                              initialIndex: index,
                            );
                          },
                        ),
                      );

                      // musicService.playSong(
                      //   widget.song.id.toString(),
                      //   widget.song.uri.toString(),
                      //   widget.song.album.toString(),
                      //   widget.song.title,
                      //   widget.song.artist.toString(),
                      // );
                      // (context as Element).findAncestorStateOfType<BottomNavBarDemoState>()?.toggleMiniPlayerVisibility(true);

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
                        color:widget.colortext,
                      ),
                    ),
                    subtitle: Text(  '${_songs[index].artist}  ${' / '}${_songs[index].album}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:  TextStyle(  color:widget.colortext,
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
                  )
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
