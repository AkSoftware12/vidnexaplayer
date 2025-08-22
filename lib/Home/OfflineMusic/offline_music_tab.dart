import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:instamusic/Utils/color.dart';
import '../../Utils/textSize.dart';
import 'OfflineSongs/presentation/pages/home/views/albums_view.dart';
import 'OfflineSongs/presentation/pages/home/views/artists_view.dart';
import 'OfflineSongs/presentation/pages/home/views/genres_view.dart';
import 'OfflineSongs/presentation/pages/home/views/songs_view.dart';



class OfflineMusicTabScreen extends StatefulWidget {
  const OfflineMusicTabScreen({super.key});

  @override
  _DashBoardScreenState createState() => _DashBoardScreenState();
}

class _DashBoardScreenState extends State<OfflineMusicTabScreen> with SingleTickerProviderStateMixin {
  PageController _pageController = PageController(initialPage: 0);

  int _selectedIndex = 0;
  bool isLiked = false;
  bool download = false;
  int selectIndex = 0;

  @override
  void initState() {
    super.initState();
  }


  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      _pageController.animateToPage(
        index,
        duration: Duration(milliseconds: 300),
        curve: Curves.ease,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // backgroundColor: const Color(0xFF222B40),
      backgroundColor: Theme.of(context).colorScheme.background,

      appBar: AppBar(
        backgroundColor:  Theme.of(context).colorScheme.background,
        automaticallyImplyLeading: false,
        title: Padding(
          padding: EdgeInsets.all(0.0),
          child: SizedBox(
            height: 40.sp,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: <Widget>[
                GestureDetector(
                  onTap: () {
                    _onItemTapped(0);
                  },
                  child: Card(
                    color: _selectedIndex == 0
                        ? ColorSelect.maineColor
                        : Colors.white,
                    child: SizedBox(
                      width: 80.sp,
                      child: Padding(
                        padding: EdgeInsets.all(8.sp),
                        child: Center(
                          child: Text(
                            'Songs',
                            style: GoogleFonts.poppins(
                              textStyle: TextStyle(
                                  color: _selectedIndex == 0
                                      ? Colors.white
                                      : ColorSelect.maineColor,
                                  fontSize: TextSizes.textmedium,
                                  fontWeight: FontWeight.bold,
                                  overflow: TextOverflow.ellipsis),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    _onItemTapped(1);
                  },
                  child: Card(
                    color: _selectedIndex == 1
                        ? ColorSelect.maineColor
                        : Colors.white,
                    child: SizedBox(
                      width: 80.sp,
                      child: Padding(
                        padding: EdgeInsets.all(8.sp),
                        child: Center(
                          child: Text(
                            'Artists',
                            style: GoogleFonts.poppins(
                              textStyle: TextStyle(
                                  color: _selectedIndex == 1
                                      ? Colors.white
                                      : ColorSelect.maineColor,
                                  fontSize: TextSizes.textmedium,
                                  fontWeight: FontWeight.bold,
                                  overflow: TextOverflow.ellipsis),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    _onItemTapped(2);
                  },
                  child: Card(
                    color: _selectedIndex == 2
                        ? ColorSelect.maineColor
                        : Colors.white,
                    child: SizedBox(
                      width: 80.sp,
                      child: Padding(
                        padding: EdgeInsets.all(8.sp),
                        child: Center(
                          child: Text(
                            'Albums',
                            style: GoogleFonts.poppins(
                              textStyle: TextStyle(
                                  color: _selectedIndex == 2
                                      ? Colors.white
                                      : ColorSelect.maineColor,
                                  fontSize: TextSizes.textmedium,
                                  fontWeight: FontWeight.bold,
                                  overflow: TextOverflow.ellipsis),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    _onItemTapped(3);
                  },
                  child: Card(
                    color: _selectedIndex == 3
                        ? ColorSelect.maineColor
                        : Colors.white,
                    child: SizedBox(
                      width: 80.sp,
                      child: Padding(
                        padding: EdgeInsets.all(8.sp),
                        child: Center(
                          child: Text(
                            'Genres',
                            style: GoogleFonts.poppins(
                              textStyle: TextStyle(
                                  color: _selectedIndex == 3
                                      ? Colors.white
                                      : ColorSelect.maineColor,
                                  fontSize: TextSizes.textmedium,
                                  fontWeight: FontWeight.bold,
                                  overflow: TextOverflow.ellipsis),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Add this line to remove the back button
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        children: [
          SongsView(color:  Theme.of(context).colorScheme.background, colortext: Theme.of(context).colorScheme.secondary,),
          ArtistsView(color:  Theme.of(context).colorScheme.background, colortext: Theme.of(context).colorScheme.secondary,),
          AlbumsView(color:  Theme.of(context).colorScheme.background, colortext: Theme.of(context).colorScheme.secondary,),
          GenresView(color:  Theme.of(context).colorScheme.background, colortext: Theme.of(context).colorScheme.secondary,),
        ],
      ),
    );
  }
}




class ConstantScrollBehavior extends ScrollBehavior {
  const ConstantScrollBehavior();

  @override
  Widget buildScrollbar(
      BuildContext context, Widget child, ScrollableDetails details) =>
      child;

  @override
  Widget buildOverscrollIndicator(
      BuildContext context, Widget child, ScrollableDetails details) =>
      child;

  @override
  TargetPlatform getPlatform(BuildContext context) => TargetPlatform.android;

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
}
