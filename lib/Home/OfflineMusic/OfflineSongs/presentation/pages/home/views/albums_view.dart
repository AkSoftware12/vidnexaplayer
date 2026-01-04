import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:on_audio_query_forked/on_audio_query.dart';

import '../../album_page.dart';

enum AlbumSortBy { az, za, artistAz, artistZa }

class AlbumsView extends StatefulWidget {
  final Color color;
  final Color colortext;

  const AlbumsView({
    super.key,
    required this.color,
    required this.colortext,
  });

  @override
  State<AlbumsView> createState() => _AlbumsViewState();
}

class _AlbumsViewState extends State<AlbumsView> {
  final OnAudioQuery _audioQuery = OnAudioQuery();

  late Future<List<AlbumModel>> _albumsFuture;
  final TextEditingController _search = TextEditingController();

  Timer? _debounce;
  String _query = "";
  AlbumSortBy _sortBy = AlbumSortBy.az;

  @override
  void initState() {
    super.initState();
    // ✅ Cache future: UI flicker/jump kam hota hai
    _albumsFuture = _audioQuery.queryAlbums(
      orderType: OrderType.ASC_OR_SMALLER,
      uriType: UriType.EXTERNAL,
      ignoreCase: true,
    );

    _search.addListener(() {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 250), () {
        if (!mounted) return;
        setState(() => _query = _search.text.trim().toLowerCase());
      });
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  List<AlbumModel> _applySearchAndSort(List<AlbumModel> list) {
    // Search
    var filtered = list.where((a) {
      final albumName = (a.album).toLowerCase();
      final artistName = (a.artist ?? "").toLowerCase();
      if (_query.isEmpty) return true;
      return albumName.contains(_query) || artistName.contains(_query);
    }).toList();

    // Sort
    int cmpStr(String a, String b) => a.compareTo(b);

    filtered.sort((a, b) {
      final aAlbum = a.album.toLowerCase();
      final bAlbum = b.album.toLowerCase();
      final aArtist = (a.artist ?? "").toLowerCase();
      final bArtist = (b.artist ?? "").toLowerCase();

      switch (_sortBy) {
        case AlbumSortBy.az:
          return cmpStr(aAlbum, bAlbum);
        case AlbumSortBy.za:
          return cmpStr(bAlbum, aAlbum);
        case AlbumSortBy.artistAz:
          final c = cmpStr(aArtist, bArtist);
          return c != 0 ? c : cmpStr(aAlbum, bAlbum);
        case AlbumSortBy.artistZa:
          final c = cmpStr(bArtist, aArtist);
          return c != 0 ? c : cmpStr(aAlbum, bAlbum);
      }
    });

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.color,
      body: SafeArea(
        child: Column(
          children: [
            // ✅ TOP BAR (Search + Sort)
            Padding(
              padding: EdgeInsets.fromLTRB(12.w, 0.h, 12.w, 0.h),
              child: Row(
                children: [
                  Expanded(
                    child: Card(
                      child: Container(
                        height: 30.h,
                        padding: EdgeInsets.symmetric(horizontal: 12.w),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(14.r),
                          border: Border.all(color: Colors.white.withOpacity(0.12)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.search_rounded,
                                color: widget.colortext.withOpacity(0.75), size: 20.sp),
                            SizedBox(width: 8.w),
                            Expanded(
                              child: TextField(
                                controller: _search,
                                style: TextStyle(
                                  color: widget.colortext,
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w500,
                                ),
                                decoration: InputDecoration(
                                  hintText: "Search albums / artist...",
                                  hintStyle: TextStyle(
                                    color: widget.colortext.withOpacity(0.55),
                                    fontSize: 13.sp,
                                  ),
                                  border: InputBorder.none,
                                  isDense: true,
                                ),
                              ),
                            ),
                            if (_search.text.isNotEmpty)
                              InkWell(
                                borderRadius: BorderRadius.circular(10.r),
                                onTap: () {
                                  _search.clear();
                                  FocusScope.of(context).unfocus();
                                  setState(() => _query = "");
                                },
                                child: Padding(
                                  padding: EdgeInsets.all(6.w),
                                  child: Icon(Icons.close_rounded,
                                      color: widget.colortext.withOpacity(0.75), size: 18.sp),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Card(child: _sortButton(context)),
                ],
              ),
            ),

            // ✅ LIST AREA
            Expanded(
              child: FutureBuilder<List<AlbumModel>>(
                future: _albumsFuture,
                builder: (context, snap) {
                  if (snap.hasError) {
                    return Center(
                      child: Text("Error: ${snap.error}",
                          style: TextStyle(color: widget.colortext)),
                    );
                  }
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final base = snap.data!;
                  final albums = _applySearchAndSort(base);

                  if (albums.isEmpty) {
                    return Center(
                      child: Text(
                        "No match found!",
                        style: TextStyle(color: widget.colortext, fontSize: 14.sp),
                      ),
                    );
                  }

                  return AnimationLimiter(
                    child: GridView.builder(
                      padding: EdgeInsets.fromLTRB(12.w, 2.h, 12.w, 14.h),
                      physics: const BouncingScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12.w,
                        mainAxisSpacing: 12.h,
                        // ✅ stable ratio: jumping nahi hoga
                        childAspectRatio: 0.78,
                      ),
                      itemCount: albums.length,
                      itemBuilder: (context, index) {
                        final album = albums[index];

                        return AnimationConfiguration.staggeredGrid(
                          position: index,
                          columnCount: 2,
                          duration: const Duration(milliseconds: 380),
                          child: ScaleAnimation(
                            child: FadeInAnimation(
                              child: _AlbumCard(
                                album: album,
                                textColor: widget.colortext,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => AlbumPage(
                                        album: album,
                                        color: Theme.of(context).colorScheme.background,
                                        colortext: Theme.of(context).colorScheme.secondary,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sortButton(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14.r),
      onTap: () => _openSortSheet(context),
      child: Container(
        height: 30.h,
        padding: EdgeInsets.symmetric(horizontal: 12.w),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
        ),
        child: Row(
          children: [
            Icon(Icons.sort_rounded,
                color: widget.colortext.withOpacity(0.8), size: 20.sp),
            SizedBox(width: 6.w),
            Text(
              "Sort",
              style: TextStyle(
                color: widget.colortext.withOpacity(0.9),
                fontSize: 12.5.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openSortSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Container(
          padding: EdgeInsets.fromLTRB(14.w, 10.h, 14.w, 16.h),
          decoration: BoxDecoration(
            color: const Color(0xFF121212),
            borderRadius: BorderRadius.vertical(top: Radius.circular(22.r)),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42.w,
                height: 4.h,
                margin: EdgeInsets.only(bottom: 10.h),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              _sortTile("Album A → Z", AlbumSortBy.az),
              _sortTile("Album Z → A", AlbumSortBy.za),
              _sortTile("Artist A → Z", AlbumSortBy.artistAz),
              _sortTile("Artist Z → A", AlbumSortBy.artistZa),
            ],
          ),
        );
      },
    );
  }

  Widget _sortTile(String title, AlbumSortBy value) {
    final selected = _sortBy == value;
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.symmetric(horizontal: 8.w),
      onTap: () {
        Navigator.pop(context);
        setState(() => _sortBy = value);
      },
      leading: Icon(
        selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
        color: selected ? const Color(0xFF2EDFB4) : Colors.white54,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: Colors.white,
          fontSize: 13.sp,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _AlbumCard extends StatelessWidget {
  final AlbumModel album;
  final Color textColor;
  final VoidCallback onTap;

  const _AlbumCard({
    required this.album,
    required this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10.r),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10.r),
          color: Colors.white,
        ),
        padding: EdgeInsets.all(0.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✅ Fixed-size artwork => NO JUMP
            ClipRRect(
              borderRadius: BorderRadius.only(topLeft:Radius.circular(10.r),topRight: Radius.circular(10.r)),
              child: SizedBox(
                width: double.infinity,
                height: 130.h, // fixed height
                  child: QueryArtworkWidget(
                    id: album.id,
                    type: ArtworkType.ALBUM,
                    artworkFit: BoxFit.fill,
                    artworkBorder: BorderRadius.zero,

                    nullArtworkWidget: _placeholder(textColor),
                  ),
              ),
            ),

            SizedBox(height: 1.h),

            Padding(
              padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 0.h),
              child: Text(
                album.album,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: textColor,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),


            Padding(
              padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 0.h),
              child: Text(
                album.artist ?? "Unknown Artist",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: textColor.withOpacity(0.75),
                  fontSize: 10.5.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

            const Spacer(),

            Align(
              alignment: Alignment.bottomLeft,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 6.h),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: Colors.white.withOpacity(0.10),
                  border: Border.all(color: Colors.white.withOpacity(0.12)),
                ),
                child: Text(
                  "Album",
                  style: TextStyle(
                    color: textColor.withOpacity(0.85),
                    fontSize: 10.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder(Color textColor) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.10),
            Colors.white.withOpacity(0.03),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.album_rounded,
          size: 38.sp,
          color: textColor.withOpacity(0.65),
        ),
      ),
    );
  }
}
