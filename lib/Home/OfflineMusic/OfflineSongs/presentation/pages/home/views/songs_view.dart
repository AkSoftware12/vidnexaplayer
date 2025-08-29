import 'package:animations/animations.dart';
// import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:on_audio_query_forked/on_audio_query.dart';
import '../../../../../../../Mp3Player/mp3_player.dart';



class SongsView extends StatefulWidget {

  final Color color;
  final Color colortext;

  const SongsView({super.key, required this.color, required this.colortext});

  @override
  State<SongsView> createState() => _SongsViewState();
}

class _SongsViewState extends State<SongsView> with SingleTickerProviderStateMixin {
  final audioQuery = OnAudioQuery();
  final audioPlayer = AudioPlayer();

  List<SongModel> items = [];

  bool isLoading = true;
  // List<SongModel> filteredItems = [];
  @override
  void initState() {
    super.initState();
  }


  void _showBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              leading: Icon(Icons.play_arrow),
              title: Text('Play'),
              onTap: () {
                Navigator.pop(context);
                // Add action for 'Play'
              },
            ),
            ListTile(
              leading: Icon(Icons.playlist_play),
              title: Text('Play Next'),
              onTap: () {
                Navigator.pop(context);
                // Add action for 'Play Next'
              },
            ),
            ListTile(
              leading: Icon(Icons.library_music),
              title: Text('Lyrics'),
              onTap: () {
                Navigator.pop(context);
                // Add action for 'Lyrics'
              },
            ),
            ListTile(
              leading: Icon(Icons.cut),
              title: Text('Ringtone Maker'),
              trailing: Icon(Icons.circle, color: Colors.red, size: 10),
              onTap: () {
                Navigator.pop(context);
                // Add action for 'Ringtone Maker'
              },
            ),
            ListTile(
              leading: Icon(Icons.playlist_add),
              title: Text('Add to playlist'),
              onTap: () {
                Navigator.pop(context);
                // Add action for 'Add to playlist'
              },
            ),
            ListTile(
              leading: Icon(Icons.lock),
              title: Text('Lock'),
              onTap: () {
                Navigator.pop(context);
                // Add action for 'Lock'
              },
            ),
            ListTile(
              leading: Icon(Icons.share),
              title: Text('Share'),
              onTap: () {
                Navigator.pop(context);
                // Add action for 'Share'
              },
            ),
            ListTile(
              leading: Icon(Icons.queue_music),
              title: Text('Add to Queue'),
              onTap: () {
                Navigator.pop(context);
                // Add action for 'Add to Queue'
              },
            ),
            ListTile(
              leading: Icon(Icons.notifications),
              title: Text('Set as ringtone'),
              onTap: () {
                Navigator.pop(context);
                // Add action for 'Set as ringtone'
              },
            ),
            ListTile(
              leading: Icon(Icons.delete),
              title: Text('Delete'),
              onTap: () {
                Navigator.pop(context);
                // Add action for 'Delete'
              },
            ),
            ListTile(
              leading: Icon(Icons.info),
              title: Text('Properties'),
              onTap: () {
                Navigator.pop(context);
                // Add action for 'Properties'
              },
            ),
          ],
        );
      },
    );
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: widget.color,
        child: FutureBuilder<List<SongModel>>(
          // Default values:
          future: audioQuery.querySongs(
            sortType: null,
            orderType: OrderType.ASC_OR_SMALLER,
            uriType: UriType.EXTERNAL,
            ignoreCase: true,
          ),
          builder: (context, item) {
            // Display error, if any.
            if (item.hasError) {
              return Text(item.error.toString());
            }

            // Waiting content.
            if (item.data == null) {
              return const CircularProgressIndicator();
            }

            // 'Library' is empty.
            if (item.data!.isEmpty) {
              return const Text("Nothing found!");
            }

            // You can use [item.data!] direct or you can create a:
            List<SongModel> songs = item.data!;
            return ListView.builder(
              itemCount: item.data!.length,
              itemBuilder: (context, index) {
                return Stack(
                  children: [
                    Column(
                      children: [

                OpenContainer(
                transitionType: ContainerTransitionType.fadeThrough,
                  closedColor: Theme.of(context).cardColor,
                  closedElevation: 0.0,
                  openElevation: 4.0,
                  transitionDuration: Duration(milliseconds: 1000),
                  openBuilder: (BuildContext context, VoidCallback _) =>
                      // PlayerScreen(
                      //   songs: songs,
                      //   initialIndex: index,
                      // ),

                  Mp3Player(
                      songs: songs,
                      initialIndex: index,
                    ),
                  closedBuilder: (BuildContext _, VoidCallback openContainer) {
                    return  ListTile(
                      title: Text(
                        item.data![index].title,
                        style: GoogleFonts.openSans(
                          textStyle: TextStyle(
                            color:widget.colortext,
                            fontSize: 13.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      subtitle: Text(
                        item.data![index].artist ?? "No Artist",
                        style: GoogleFonts.poppins(
                          textStyle: TextStyle(
                            color: Colors.grey,
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      trailing:  GestureDetector(
                          onTap: () {
                            _showBottomSheet(context);

                          },
                          child: Container(
                            height: 40.sp,
                            width: 50.sp,
                            child: Icon(
                              Icons.more_vert,
                              size: 20.sp,
                              color: Colors.black54,
                            ),
                          )),

                      leading: QueryArtworkWidget(
                        controller: audioQuery,
                        id: item.data![index].id,
                        type: ArtworkType.AUDIO,
                        artworkBorder: BorderRadius.circular(8),
                        nullArtworkWidget: Padding(
                          padding: const EdgeInsets.all(0.0),
                          child:

                          Image.asset(
                            'assets/music_folder.png', // Replace with your placeholder asset path
                            fit: BoxFit.cover,
                            width: 50,
                            height: 50,
                          ),
                        ),
                      ),                      // onTap: () async {
                      //
                      //   Navigator.push(
                      //     context,
                      //     MaterialPageRoute(
                      //       builder: (context) => PlayerScreen(
                      //         songs: songs,
                      //         initialIndex: index,
                      //       ),
                      //     ),
                      //   );
                      //
                      // },
                    );
                  },
                ),


                        // Add a Divider after each ListTile, except for the last one
                        if (index < item.data!.length - 1) Divider(color: Colors.white10),

                      ],
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}
