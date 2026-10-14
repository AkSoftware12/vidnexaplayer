import 'package:animations/animations.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:on_audio_query_forked/on_audio_query.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../../../../LocalMusic/AUDIOCONTROLLER/global_audio_controller.dart';
import '../../../../../../../Utils/app_palette.dart';
import '../../../../../../../NotifyListeners/LanguageProvider/language_provider.dart';
import '../../../../../../../NotifyListeners/LanguageProvider/music_strings.dart';
import 'package:videoplayer/ads/ads_manager.dart';



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


  /// Only actions that work. The menu used to list eleven entries (lyrics,
  /// ringtone maker, lock, …) that all just closed the sheet — dead UI that
  /// Play's minimum-functionality review treats as broken.
  void _showBottomSheet(BuildContext context, List<SongModel> songs, int index) {
    final lang = Provider.of<LocaleProvider>(context, listen: false).locale.languageCode;
    final song = songs[index];
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              leading: const Icon(Icons.play_arrow),
              title: Text(MusicStrings.t(lang, 'music_play')),
              onTap: () {
                Navigator.pop(context);
                audio.playSongs(songs, index);
              },
            ),
            ListTile(
              leading: const Icon(Icons.playlist_play),
              title: Text(MusicStrings.t(lang, 'music_play_next')),
              onTap: () {
                Navigator.pop(context);
                audio.enqueue(song, next: true);
              },
            ),
            ListTile(
              leading: const Icon(Icons.queue_music),
              title: Text(MusicStrings.t(lang, 'music_add_to_queue')),
              onTap: () {
                Navigator.pop(context);
                audio.enqueue(song, next: false);
              },
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: Text(MusicStrings.t(lang, 'music_share')),
              onTap: () {
                Navigator.pop(context);
                _share(song);
              },
            ),
          ],
        );
      },
    );
  }

  /// Shares the audio file itself, falling back to the title if the file
  /// can't be attached — same behaviour as the full player's Share.
  Future<void> _share(SongModel song) async {
    final text = '${song.title}\n${song.artist ?? ""}';
    try {
      if (song.data.isNotEmpty) {
        AdsManager.skipNextAppOpen();
        await SharePlus.instance.share(
          ShareParams(files: [XFile(song.data)], text: text, subject: song.title),
        );
        return;
      }
    } catch (_) {}
    AdsManager.skipNextAppOpen();
    await SharePlus.instance.share(ShareParams(text: text, subject: song.title));
  }
  @override
  Widget build(BuildContext context) {
    AppPalette.sync(context);
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
                          transitionDuration: const Duration(milliseconds: 800),
                          openBuilder: (BuildContext context, VoidCallback _) =>const SizedBox(),
                          closedBuilder: (BuildContext _, VoidCallback openContainer) {
                            return  ListTile(
                              title: Text(
                                item.data![index].title,
                                style: (TextStyle(
                                    color:widget.colortext,
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.bold,
                                  )).copyWith(fontFamily: 'OpenSans'),
                              ),
                              subtitle: Text(
                                item.data![index].artist ??
                                    MusicStrings.t(lang, 'music_no_artist'),
                                style: (TextStyle(
                                    color: Colors.grey,
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.w600,
                                  )).copyWith(fontFamily: 'Poppins'),
                              ),
                              trailing:  GestureDetector(
                                  onTap: () {
                                    _showBottomSheet(context, songs, index);

                                  },
                                  child: SizedBox(
                                    height: 40.sp,
                                    width: 50.sp,
                                    child: Icon(
                                      Icons.more_vert,
                                      size: 20.sp,
                                      color: AppPalette.textB,
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
                        if (index < item.data!.length - 1) Divider(color: AppPalette.border),

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
