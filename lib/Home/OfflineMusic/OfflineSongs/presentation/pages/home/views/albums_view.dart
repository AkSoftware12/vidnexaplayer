import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:on_audio_query_forked/on_audio_query.dart';
import '../../album_page.dart';

class AlbumsView extends StatefulWidget {
  final Color color;
  final Color colortext;
  const AlbumsView({super.key, required this.color, required this.colortext});

  @override
  State<AlbumsView> createState() => _AlbumsViewState();
}

class _AlbumsViewState extends State<AlbumsView>
    with SingleTickerProviderStateMixin {


  final audioQuery = OnAudioQuery();
  List<AlbumModel> items = [];

  bool isLoading = true;
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:widget.color,

      body: Center(
        child:  FutureBuilder<List<AlbumModel>>(
          // Default values:
          future: audioQuery.queryAlbums(
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
            List<AlbumModel> songs = item.data!;
            return  GridView.builder(
              padding: const EdgeInsets.all(1),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                // crossAxisSpacing: 8,
                // mainAxisSpacing: 8,
              ),
              itemCount: item.data!.length,
              itemBuilder: (context, index) {
                final album = item.data![index];

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
                              return AlbumPage(album: album,
                                color:  Theme.of(context).colorScheme.background, colortext: Theme.of(context).colorScheme.secondary,
                              );
                            },
                          ),
                        );




                        // Navigator.of(context).pushNamed(
                        //   AppRouter.albumRoute,
                        //   arguments: album,
                        // );
                      },
                      child: Column(
                        children: [
                          QueryArtworkWidget(
                            id: album.id,
                            type: ArtworkType.ALBUM,
                            artworkHeight: 135.sp,
                            artworkWidth: 150.sp,
                            artworkBorder: BorderRadius.circular(10),
                            nullArtworkWidget: Container(
                              width: 150.sp,
                              height: 135.sp,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                color: Colors.orange,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Image.asset(
                                  'assets/music_folder.png', // Replace with your placeholder asset path
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding:  EdgeInsets.only(top: 5.sp),
                            child: Text(
                              album.album,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style:  TextStyle(fontSize: 13.sp,
                                fontWeight: FontWeight.bold,color: widget.colortext
                              ),
                            ),
                          ),
                          Center(
                            child: Text(
                              album.artist ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style:  TextStyle(color: widget.colortext,
                                fontSize:  10.sp,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );





          },
        ),
      ),
    );

  }
}
