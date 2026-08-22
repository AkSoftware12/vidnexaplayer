import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:on_audio_query_forked/on_audio_query.dart';
import 'package:provider/provider.dart';
import '../../../../../../../LocalMusic/AUDIOCONTROLLER/global_audio_controller.dart';
import '../../../../../../../NotifyListeners/LanguageProvider/language_provider.dart';
import '../../../../../../../NotifyListeners/LanguageProvider/music_strings.dart';



class SongsView extends StatefulWidget {

  final Color color;
  final Color colortext;

  const SongsView({super.key, required this.color, required this.colortext});

  @override
  State<SongsView> createState() => _SongsViewState();
}

class _SongsViewState extends State<SongsView> with SingleTickerProviderStateMixin {
  final audioQuery = OnAudioQuery();

  List<SongModel> items = [];

  final audio = GlobalAudioController();

  late Future<List<SongModel>> _songsFuture;

  bool isLoading = true;
  // List<SongModel> filteredItems = [];
  @override
  void initState() {
    super.initState();
    // Cached once instead of being rebuilt in build(): a new Future every
    // rebuild (e.g. switching tabs) made FutureBuilder drop back to its
    // loading state and re-scan the entire on-device audio library.
    _songsFuture = audioQuery.querySongs(
      sortType: null,
      orderType: OrderType.ASC_OR_SMALLER,
      uriType: UriType.EXTERNAL,
      ignoreCase: true,
    );
  }


  void _showBottomSheet(BuildContext context) {
    final lang = Provider.of<LocaleProvider>(context, listen: false).locale.languageCode;
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              leading: Icon(Icons.play_arrow),
              title: Text(MusicStrings.t(lang, 'music_play')),
              onTap: () {
                Navigator.pop(context);
                // Add action for 'Play'
              },
            ),
            ListTile(
              leading: Icon(Icons.playlist_play),
              title: Text(MusicStrings.t(lang, 'music_play_next')),
              onTap: () {
                Navigator.pop(context);
                // Add action for 'Play Next'
              },
            ),
            ListTile(
              leading: Icon(Icons.library_music),
              title: Text(MusicStrings.t(lang, 'music_lyrics')),
              onTap: () {
                Navigator.pop(context);
                // Add action for 'Lyrics'
              },
            ),
            ListTile(
              leading: Icon(Icons.cut),
              title: Text(MusicStrings.t(lang, 'music_ringtone_maker')),
              trailing: Icon(Icons.circle, color: Colors.red, size: 10),
              onTap: () {
                Navigator.pop(context);
                // Add action for 'Ringtone Maker'
              },
            ),
            ListTile(
              leading: Icon(Icons.playlist_add),
              title: Text(MusicStrings.t(lang, 'music_add_to_playlist')),
              onTap: () {
                Navigator.pop(context);
                // Add action for 'Add to playlist'
              },
            ),
            ListTile(
              leading: Icon(Icons.lock),
              title: Text(MusicStrings.t(lang, 'music_lock')),
              onTap: () {
                Navigator.pop(context);
                // Add action for 'Lock'
              },
            ),
            ListTile(
              leading: Icon(Icons.share),
              title: Text(MusicStrings.t(lang, 'music_share')),
              onTap: () {
                Navigator.pop(context);
                // Add action for 'Share'
              },
            ),
            ListTile(
              leading: Icon(Icons.queue_music),
              title: Text(MusicStrings.t(lang, 'music_add_to_queue')),
              onTap: () {
                Navigator.pop(context);
                // Add action for 'Add to Queue'
              },
            ),
            ListTile(
              leading: Icon(Icons.notifications),
              title: Text(MusicStrings.t(lang, 'music_set_as_ringtone')),
              onTap: () {
                Navigator.pop(context);
                // Add action for 'Set as ringtone'
              },
            ),
            ListTile(
              leading: Icon(Icons.delete),
              title: Text(MusicStrings.t(lang, 'music_delete')),
              onTap: () {
                Navigator.pop(context);
                // Add action for 'Delete'
              },
            ),
            ListTile(
              leading: Icon(Icons.info),
              title: Text(MusicStrings.t(lang, 'music_properties')),
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
    final lang = context.watch<LocaleProvider>().locale.languageCode;

    return Scaffold(
      body: Container(
        color: widget.color,
        child: FutureBuilder<List<SongModel>>(
          future: _songsFuture,
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
              return Text(MusicStrings.t(lang, 'music_nothing_found'));
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
                          openElevation: 0.0,
                          transitionDuration: Duration(milliseconds: 800),
                          openBuilder: (BuildContext context, VoidCallback _) =>SizedBox(),
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
                                item.data![index].artist ??
                                    MusicStrings.t(lang, 'music_no_artist'),
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
                              ),

                              onTap: (){
                                audio.playSongs(songs, index);

                              },
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
