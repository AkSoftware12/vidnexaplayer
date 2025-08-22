import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:on_audio_query_forked/on_audio_query.dart';
import '../../artist_page.dart';

class ArtistsView extends StatefulWidget {

  final Color color;
  final Color colortext;
  const ArtistsView({super.key, required this.color, required this.colortext});


  @override
  State<ArtistsView> createState() => _ArtistsViewState();
}

class _ArtistsViewState extends State<ArtistsView>
    with SingleTickerProviderStateMixin {
  // bool get wantKeepAlive => true;

  final audioQuery = OnAudioQuery();
  List<ArtistModel> items = [];

  bool isLoading = true;
  @override
  void initState() {
    super.initState();
    // context.read<HomeBloc>().add(GetArtistsEvent());
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: widget.color,
      child:  FutureBuilder<List<ArtistModel>>(
        // Default values:
        future: audioQuery.queryArtists(
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
          if (item.data!.isEmpty)
            return const Text("Nothing found!");

          // You can use [item.data!] direct or you can create a:
          List<ArtistModel> songs = item.data!;
          return  Container(color:  widget.color,
            child: GridView.builder(
              padding: const EdgeInsets.all(8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 0,
                mainAxisSpacing: 0,
              ),
              itemCount: item.data!.length,
              itemBuilder: (context, index) {
                final artist = item.data![index];

                return AnimationConfiguration.staggeredGrid(
                  position: index,
                  duration: const Duration(milliseconds: 500),
                  columnCount: 2,
                  child: FlipAnimation(
                    child: GestureDetector(
                      onTap: () {

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) {
                              return ArtistPage(artist: artist,
                                color:  Theme.of(context).colorScheme.background, colortext: Theme.of(context).colorScheme.secondary,
                              );
                            },
                          ),
                        );



                        // Navigator.of(context).pushNamed(
                        //   AppRouter.artistRoute,
                        //   arguments: artist,
                        // );
                      },
                      child: Column(
                        children: [
                          QueryArtworkWidget(
                            id: artist.id,
                            type: ArtworkType.ARTIST,
                            artworkHeight: 136,
                            artworkWidth: 136,
                            artworkBorder: BorderRadius.circular(100),
                            nullArtworkWidget:  SizedBox(
                              width: 136,
                              height: 136,
                              child: Image.asset(
                                'assets/music_folder.png', // Replace with your placeholder asset path
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 10.0),
                            child: Text(
                              artist.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style:  TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color:  widget.colortext,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );





        },
      ),
    );

  }
}
