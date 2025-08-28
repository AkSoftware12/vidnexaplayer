import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:instamusic/Utils/color.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import '../../ComingSoon/coming_soon.dart' show ComingSoonPage, ComingSoonScreen;
import '../../DarkMode/dark_mode.dart';
import '../../DarkMode/styles/theme_data_style.dart';
import '../../DeviceSpace/device_space.dart';
import '../../HexColorCode/HexColor.dart';
import '../../Model/property_type.dart';
import '../../Notification/notification.dart';
import '../../NotifyListeners/AppBar/app_bar_color.dart';
import '../../NotifyListeners/AppBar/colorList.dart';
import '../../Photo/photo.dart';
import '../../Utils/textSize.dart';
import '../../VideoPLayer/AllVideo/all_videos.dart';
import '../../app_store/app_store.dart';
import '../HomeBottomnavigation/home_bottomNavigation.dart';

class UserProfilePage extends StatefulWidget {
  const UserProfilePage({super.key});

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  final int _sizePerPage = 50;
  final TextEditingController _controller = TextEditingController();
  String userName = "";
  String userImage = "";
  File? file;

  AssetPathEntity? _path;
  List<AssetEntity>? _entities;
  int _totalEntitiesCount = 0;

  int _page = 0;

  // bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMoreToLoad = true;
  bool _isLoading = true;
  bool _loading = false;

  Future<void> _requestAssets() async {
    setState(() {
      _isLoading = true;
    });
    // Request permissions.
    final PermissionState ps = await PhotoManager.requestPermissionExtend();
    if (!mounted) {
      return;
    }
    // Further requests can be only proceed with authorized or limited.
    if (!ps.hasAccess) {
      setState(() {
        _isLoading = false;
      });
      // showToast('Permission is not accessible.');
      return;
    }
    // Customize your own filter options.
    final PMFilter filter = FilterOptionGroup(
      imageOption: const FilterOption(
        sizeConstraint: SizeConstraint(ignoreSize: true),
      ),
    );
    // Obtain assets using the path entity.
    final List<AssetPathEntity> paths = await PhotoManager.getAssetPathList(
      onlyAll: true,
      filterOption: filter,
    );
    if (!mounted) {
      return;
    }
    // Return if not paths found.
    if (paths.isEmpty) {
      setState(() {
        _isLoading = false;
      });
      // showToast('No paths found.');
      return;
    }
    setState(() {
      _path = paths.first;
    });
    _totalEntitiesCount = await _path!.assetCountAsync;
    final List<AssetEntity> entities = await _path!.getAssetListPaged(
      page: 0,
      size: _sizePerPage,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _entities = entities;
      _isLoading = false;
      _hasMoreToLoad = _entities!.length < _totalEntitiesCount;
    });
  }

  Future<void> _loadMoreAsset() async {
    final List<AssetEntity> entities = await _path!.getAssetListPaged(
      page: _page + 1,
      size: _sizePerPage,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _entities!.addAll(entities);
      _page++;
      _hasMoreToLoad = _entities!.length < _totalEntitiesCount;
      _isLoadingMore = false;
    });
  }

  void _loadData() async {
    // Simulate a network call
    await Future.delayed(Duration(seconds: 3));
    setState(() {
      // _totalEntitiesCount = 100; // Example count
      _isLoading = false;
    });
  }

  @override
  void initState() {
    super.initState();
    _requestAssets();
    _loadData();
    _getUsername();
    _getUserimage();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _getUsername() async {
    AppStore appStore = AppStore();
    String name = await appStore.getUserName();
    setState(() {
      userName = name;
    });
  }

  void _getUserimage() async {
    AppStore appStore = AppStore();
    String image = await appStore.getUserImage();
    setState(() {
      userImage = image;
    });
  }

  void _updateText() {
    setState(() {
      userName = _controller.text;
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AppBarColorProvider>(context, listen: false).loadColor();
    });
    return Scaffold(
      backgroundColor: Colors.grey[100],

      // backgroundColor: Colors.grey.shade50,
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(10.sp),
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.all(0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile Section
                    Padding(
                      padding: EdgeInsets.only(top: 0.sp),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: ColorSelect.maineColor.withOpacity(0.3),
                              // Shadow color
                              spreadRadius: 2,
                              blurRadius: 10,
                              offset: Offset(
                                  0, -4), // Upar shadow ke liye negative Y
                            ),
                            BoxShadow(
                              color: ColorSelect.maineColor.withOpacity(0.3),
                              spreadRadius: 2,
                              blurRadius: 10,
                              offset: Offset(
                                  0, 4), // Niche shadow ke liye positive Y
                            ),
                          ],
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          child: Column(
                            children: [
                              SizedBox(height: 15.sp),
                              Stack(
                                children: [
                                  ClipOval(
                                    child: Container(
                                      width: 70.sp,
                                      height: 70.sp,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                      ),
                                      child: file != null
                                          ? Image.file(file!)
                                          : Image.asset('assets/avtar.jpg'),
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 2,
                                    right: 1,
                                    child: GestureDetector(
                                      onTap: () {
                                        showModalBottomSheet(
                                          context: context,
                                          isScrollControlled: true,
                                          builder: (BuildContext context) {
                                            return Container(
                                              padding: EdgeInsets.all(16.0),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius:
                                                    BorderRadius.vertical(
                                                        top: Radius.circular(
                                                            25.sp)),
                                              ),
                                              child: SingleChildScrollView(
                                                child: Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: <Widget>[
                                                    Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .start,
                                                      children: [
                                                        Padding(
                                                          padding:
                                                              EdgeInsets.all(
                                                                  12.sp),
                                                          child: Text.rich(
                                                            TextSpan(
                                                              text:
                                                                  "Edit Profile",
                                                              style: GoogleFonts
                                                                  .radioCanada(
                                                                textStyle:
                                                                    TextStyle(
                                                                  color: Colors
                                                                      .black,
                                                                  fontSize:
                                                                      15.sp,
                                                                  // Adjust font size as needed
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold, // Adjust font weight as needed
                                                                ),
                                                              ),
                                                            ),
                                                            textAlign: TextAlign
                                                                .start, // Ensure text starts at the beginning
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    SizedBox(
                                                      height: 20.sp,
                                                    ),
                                                    Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .start,
                                                      children: [
                                                        Padding(
                                                          padding:
                                                              EdgeInsets.all(
                                                                  12.sp),
                                                          child: SizedBox(
                                                            height: 20.sp,
                                                            width: 20.sp,
                                                            child: Icon(
                                                                Icons
                                                                    .camera_alt_outlined,
                                                                color: Colors
                                                                    .black),
                                                          ),
                                                        ),
                                                        Padding(
                                                          padding:
                                                              EdgeInsets.all(
                                                                  5.sp),
                                                          child: Text.rich(
                                                            TextSpan(
                                                              text:
                                                                  "Take a photo",
                                                              style: GoogleFonts
                                                                  .radioCanada(
                                                                textStyle:
                                                                    TextStyle(
                                                                  color: Colors
                                                                      .black,
                                                                  fontSize:
                                                                      15.sp,
                                                                  // Adjust font size as needed
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .normal, // Adjust font weight as needed
                                                                ),
                                                              ),
                                                            ),
                                                            textAlign: TextAlign
                                                                .start, // Ensure text starts at the beginning
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    GestureDetector(
                                                      onTap: () {
                                                        // getImage(ImageSource.gallery);
                                                        // Navigator.pop(context);
                                                      },
                                                      child: Row(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .start,
                                                        children: [
                                                          Padding(
                                                            padding:
                                                                EdgeInsets.all(
                                                                    12.sp),
                                                            child: SizedBox(
                                                              height: 20.sp,
                                                              width: 20.sp,
                                                              child: Icon(
                                                                  Icons.photo,
                                                                  color: Colors
                                                                      .black),
                                                            ),
                                                          ),
                                                          Padding(
                                                            padding:
                                                                EdgeInsets.all(
                                                                    5.sp),
                                                            child: Text.rich(
                                                              TextSpan(
                                                                text: "Gallery",
                                                                style: GoogleFonts
                                                                    .radioCanada(
                                                                  textStyle:
                                                                      TextStyle(
                                                                    color: Colors
                                                                        .black,
                                                                    fontSize:
                                                                        15.sp,
                                                                    // Adjust font size as needed
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .normal, // Adjust font weight as needed
                                                                  ),
                                                                ),
                                                              ),
                                                              textAlign: TextAlign
                                                                  .start, // Ensure text starts at the beginning
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    SizedBox(
                                                      height: 30.sp,
                                                    ),
                                                    Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .start,
                                                      children: [
                                                        Padding(
                                                          padding:
                                                              EdgeInsets.all(
                                                                  12.sp),
                                                          child: Text.rich(
                                                            TextSpan(
                                                              text:
                                                                  "Profile Name",
                                                              style: GoogleFonts
                                                                  .radioCanada(
                                                                textStyle:
                                                                    TextStyle(
                                                                  color: Colors
                                                                      .black,
                                                                  fontSize:
                                                                      15.sp,
                                                                  // Adjust font size as needed
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold, // Adjust font weight as needed
                                                                ),
                                                              ),
                                                            ),
                                                            textAlign: TextAlign
                                                                .start, // Ensure text starts at the beginning
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    SizedBox(
                                                      height: 20.sp,
                                                    ),
                                                    Padding(
                                                      padding:
                                                          EdgeInsets.all(12.sp),
                                                      child: TextFormField(
                                                        controller: _controller,
                                                        decoration:
                                                            InputDecoration(
                                                          labelText:
                                                              'Profile Name',
                                                          suffixIcon:
                                                              IconButton(
                                                            icon: Icon(
                                                                Icons.clear,
                                                                size: 15.sp),
                                                            onPressed: () {
                                                              _controller
                                                                  .clear();
                                                            },
                                                          ),
                                                        ),
                                                        style: TextStyle(
                                                            color:
                                                                Colors.black),
                                                      ),
                                                    ),
                                                    SizedBox(
                                                      height: 40.sp,
                                                    ),
                                                    ElevatedButton(
                                                      style: ElevatedButton
                                                          .styleFrom(
                                                        backgroundColor: Colors
                                                            .green, // Replace 'Colors.blue' with your desired color
                                                      ),
                                                      onPressed: () {
                                                        String name =
                                                            _controller.text;

                                                        AppStore()
                                                            .setUserName(name);
                                                        _updateText();

                                                        Navigator.pop(context);
                                                      },
                                                      child: Text('Save',
                                                          style: TextStyle(
                                                              color: Colors
                                                                  .white)),
                                                    ),
                                                    SizedBox(
                                                      height: 30.sp,
                                                    ),
                                                    Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .center,
                                                      children: [
                                                        Padding(
                                                          padding:
                                                              EdgeInsets.all(
                                                                  12.sp),
                                                          child:
                                                              GestureDetector(
                                                            onTap: () {
                                                              Navigator.pop(
                                                                  context);
                                                            },
                                                            child: Text.rich(
                                                              TextSpan(
                                                                text:
                                                                    "Back to home",
                                                                style: GoogleFonts
                                                                    .radioCanada(
                                                                  textStyle:
                                                                      TextStyle(
                                                                    color: Colors
                                                                        .black,
                                                                    fontSize:
                                                                        15.sp,
                                                                    // Adjust font size as needed
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold, // Adjust font weight as needed
                                                                  ),
                                                                ),
                                                              ),
                                                              textAlign: TextAlign
                                                                  .start, // Ensure text starts at the beginning
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    SizedBox(
                                                      height: 10.sp,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          },
                                        );
                                      },
                                      child: Container(
                                        width: 20.sp,
                                        height: 20.sp,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: ColorSelect.maineColor
                                                  .withOpacity(0.6),
                                              // Shadow color
                                              spreadRadius: 2,
                                              blurRadius: 10,
                                              offset: Offset(0,
                                                  -4), // Upar shadow ke liye negative Y
                                            ),
                                            BoxShadow(
                                              color: ColorSelect.maineColor
                                                  .withOpacity(0.6),
                                              spreadRadius: 2,
                                              blurRadius: 10,
                                              offset: Offset(0,
                                                  4), // Niche shadow ke liye positive Y
                                            ),
                                          ],
                                        ),
                                        child: Icon(
                                          Icons.edit,
                                          size: 15.sp,
                                          color: ColorSelect.maineColor,
                                        ),
                                      ),
                                    ),
                                  )
                                ],
                              ),
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    height: 5.sp,
                                  ),
                                  Text.rich(
                                    TextSpan(
                                      text: "${userName}",
                                      style: GoogleFonts.radioCanada(
                                        textStyle: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .secondary,
                                          fontSize: 17.sp,
                                          // Adjust font size as needed
                                          fontWeight: FontWeight
                                              .bold, // Adjust font weight as needed
                                        ),
                                      ),
                                    ),
                                    textAlign: TextAlign
                                        .start, // Ensure text starts at the beginning
                                  ),
                                  Text.rich(
                                    TextSpan(
                                      text: "demo1234@gmail.com",
                                      style: GoogleFonts.openSans(
                                        textStyle: TextStyle(
                                          color: Colors.grey,
                                          fontSize: 11.sp,
                                          // Adjust font size as needed
                                          fontWeight: FontWeight
                                              .w600, // Adjust font weight as needed
                                        ),
                                      ),
                                    ),
                                    textAlign: TextAlign
                                        .start, // Ensure text starts at the beginning
                                  ),
                                  Padding(
                                    padding: EdgeInsets.only(
                                        left: 50.sp, right: 50.sp, top: 10.sp),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(15),
                                        gradient: LinearGradient(
                                          colors: [
                                            ColorSelect.maineColor,
                                            // HexColor('#fb923c'), // Purple
                                            HexColor('#f87171'), // Purple
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                      ),
                                      padding: EdgeInsets.all(3.sp),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.star,
                                            color: Colors.white,
                                            size: 20.sp,
                                          ),
                                          SizedBox(width: 10.sp),
                                          Text.rich(
                                            TextSpan(
                                              text: "Premium Member",
                                              style: GoogleFonts.radioCanada(
                                                textStyle: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 13.sp,
                                                  // Adjust font size as needed
                                                  fontWeight: FontWeight
                                                      .bold, // Adjust font weight as needed
                                                ),
                                              ),
                                            ),
                                            textAlign: TextAlign
                                                .start, // Ensure text starts at the beginning
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: 15.sp),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // child: ListTile(
                        //   leading: CircleAvatar(
                        //     backgroundImage: NetworkImage('https://via.placeholder.com/150'),
                        //     radius: 30,
                        //   ),
                        //   title: Text('Parves Ahamad'),
                        //   subtitle: Text('@parvesahamad984'),
                        //   trailing: Chip(
                        //     label: Text('Premium Member '),
                        //     backgroundColor: Colors.orange,
                        //     labelStyle: TextStyle(color: Colors.white),
                        //   ),
                        // ),
                      ),
                    ),
                    SizedBox(height: 16),
                    // Storage Overview
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Storage Overview',
                          style: GoogleFonts.openSans(
                            textStyle: TextStyle(
                              color: Colors.black,
                              fontSize: 16.sp,
                              // Adjust font size as needed
                              fontWeight: FontWeight
                                  .bold, // Adjust font weight as needed
                            ),
                          ),
                        ),
                        Text(
                          '591 MB total',
                          style: GoogleFonts.openSans(
                            textStyle: TextStyle(
                              color: Colors.grey,
                              fontSize: 12.sp,
                              // Adjust font size as needed
                              fontWeight: FontWeight
                                  .w700, // Adjust font weight as needed
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    SizedBox(
                      height: 100.sp,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => DeviceSpaceScreen(),
                                ),
                              );
                            },
                            child: Container(
                                width: MediaQuery.of(context).size.width *
                                    0.3, // Adjust width as needed
                                padding: EdgeInsets.all(3.sp),
                                child: Container(
                                  height: 25.sp,
                                  width:
                                      MediaQuery.of(context).size.width * 0.35,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        HexColor('#2563eb'),
                                        HexColor('#3b82f6'), // ending color
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(10.sp),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Container(
                                        width: 30.sp,
                                        height: 30.sp,
                                        decoration: BoxDecoration(
                                          color: Colors.white24,
                                          borderRadius:
                                              BorderRadius.circular(10.sp),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Image.asset(
                                            'assets/files.png',
                                            color: Colors.white,
                                            height: 25.sp,
                                            width: 25.sp,
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: EdgeInsets.only(
                                            bottom: 0.sp, top: 3.sp),
                                        child: Text(
                                          '3.2 GB',
                                          style: GoogleFonts.poppins(
                                            textStyle: TextStyle(
                                              fontSize: 12.sp,
                                              fontWeight: FontWeight.w800,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: EdgeInsets.only(
                                            bottom: 0.sp, top: 0.sp),
                                        child: Text(
                                          'File Manager',
                                          style: GoogleFonts.poppins(
                                            textStyle: TextStyle(
                                              fontSize: 12.sp,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                )),
                          ),
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => AllVideosScreen(),
                                ),
                              );
                            },
                            child: Container(
                                width: MediaQuery.of(context).size.width *
                                    0.3, // Adjust width as needed
                                padding: EdgeInsets.all(3.sp),
                                child: Container(
                                  height: 25.sp,
                                  width:
                                      MediaQuery.of(context).size.width * 0.35,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        HexColor('#f97316'),
                                        HexColor('#eab308'),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(10.sp),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Container(
                                        width: 30.sp,
                                        height: 30.sp,
                                        decoration: BoxDecoration(
                                          color: Colors.white24,
                                          borderRadius:
                                              BorderRadius.circular(10.sp),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Image.asset(
                                            'assets/videos.png',
                                            color: Colors.white,
                                            height: 25.sp,
                                            width: 25.sp,
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: EdgeInsets.only(
                                            bottom: 0.sp, top: 3.sp),
                                        child: Text(
                                          '3.2 GB',
                                          style: GoogleFonts.poppins(
                                            textStyle: TextStyle(
                                              fontSize: 12.sp,
                                              fontWeight: FontWeight.w800,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: EdgeInsets.only(
                                            bottom: 0.sp, top: 0.sp),
                                        child: Text(
                                          'Videos',
                                          style: GoogleFonts.poppins(
                                            textStyle: TextStyle(
                                              fontSize: 12.sp,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                )),
                          ),
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => SimpleExamplePage(),
                                ),
                              );
                            },
                            child: Container(
                                width: MediaQuery.of(context).size.width *
                                    0.3, // Adjust width as needed
                                padding: EdgeInsets.all(3.sp),
                                child: Container(
                                  height: 25.sp,
                                  width:
                                      MediaQuery.of(context).size.width * 0.35,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        HexColor('#dc2626'),
                                        HexColor('#ef4444'),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(10.sp),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Container(
                                        width: 30.sp,
                                        height: 30.sp,
                                        decoration: BoxDecoration(
                                          color: Colors.white24,
                                          borderRadius:
                                              BorderRadius.circular(10.sp),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Image.asset(
                                            'assets/image.png',
                                            color: Colors.white,
                                            height: 25.sp,
                                            width: 25.sp,
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: EdgeInsets.only(
                                            bottom: 0.sp, top: 3.sp),
                                        child: _isLoading
                                            ? SizedBox(
                                                height: 10.sp,
                                                width: 10.sp,
                                                child: Center(
                                                    child:
                                                        CupertinoActivityIndicator(
                                                  radius: 10,
                                                  color: ColorSelect.maineColor,
                                                  animating: true,
                                                )))
                                            : Text(
                                                _totalEntitiesCount.toString(),
                                                style: GoogleFonts.poppins(
                                                  textStyle: TextStyle(
                                                    fontSize: 12.sp,
                                                    fontWeight: FontWeight.w800,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                      ),
                                      Padding(
                                        padding: EdgeInsets.only(
                                            bottom: 0.sp, top: 0.sp),
                                        child: Text(
                                          'Images',
                                          style: GoogleFonts.poppins(
                                            textStyle: TextStyle(
                                              fontSize: 12.sp,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                )),
                          ),
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) =>
                                        const HomeBottomNavigation(
                                          bottomIndex: 1,
                                        )),
                              );
                            },
                            child: Container(
                                width: MediaQuery.of(context).size.width *
                                    0.3, // Adjust width as needed
                                padding: EdgeInsets.all(3.sp),
                                child: Container(
                                  height: 25.sp,
                                  width:
                                      MediaQuery.of(context).size.width * 0.35,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        HexColor('#7e22ce'),
                                        HexColor('#9333ea'),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(10.sp),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Container(
                                        width: 30.sp,
                                        height: 30.sp,
                                        decoration: BoxDecoration(
                                          color: Colors.white24,
                                          borderRadius:
                                              BorderRadius.circular(10.sp),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Image.asset(
                                            'assets/musics.png',
                                            color: Colors.white,
                                            height: 25.sp,
                                            width: 25.sp,
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: EdgeInsets.only(
                                            bottom: 0.sp, top: 3.sp),
                                        child: Text(
                                          '3.2 GB',
                                          style: GoogleFonts.poppins(
                                            textStyle: TextStyle(
                                              fontSize: 12.sp,
                                              fontWeight: FontWeight.w800,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: EdgeInsets.only(
                                            bottom: 0.sp, top: 0.sp),
                                        child: Text(
                                          'Music',
                                          style: GoogleFonts.poppins(
                                            textStyle: TextStyle(
                                              fontSize: 12.sp,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                )),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 16),
                    // Quick Actions
                    Text(
                      'Quick Actions',
                      style: GoogleFonts.openSans(
                        textStyle: TextStyle(
                          color: Colors.black,
                          fontSize: 16.sp,
                          // Adjust font size as needed
                          fontWeight:
                              FontWeight.bold, // Adjust font weight as needed
                        ),
                      ),
                    ),
                    SizedBox(height: 8),
                    ProfileQuickActionList(),
                    SizedBox(height: 8),

                    // Padding(
                    //   padding: EdgeInsets.only(top: 0.sp),
                    //   child: Container(
                    //     decoration: BoxDecoration(
                    //       borderRadius: BorderRadius.circular(15),
                    //       gradient: LinearGradient(
                    //         colors: [
                    //           HexColor('#6663f2'), // Purple
                    //           Colors.purple // Purple
                    //         ],
                    //         begin: Alignment.topLeft,
                    //         end: Alignment.bottomRight,
                    //       ),
                    //     ),
                    //     child: SizedBox(
                    //       width: double.infinity,
                    //       child: Padding(
                    //         padding: EdgeInsets.all(15.sp),
                    //         child: Row(
                    //           children: [
                    //             Container(
                    //                 width: 70.sp,
                    //                 height: 70.sp,
                    //                 decoration: BoxDecoration(
                    //                   color: Colors.white24,
                    //                   borderRadius: BorderRadius.circular(15),
                    //                 ),
                    //                 child: Icon(
                    //                   AntDesign.play_circle_fill,
                    //                   size: 50.sp,
                    //                   color: Colors.white,
                    //                 )),
                    //             SizedBox(
                    //               width: 20.sp,
                    //             ),
                    //             Column(
                    //               mainAxisAlignment: MainAxisAlignment.start,
                    //               crossAxisAlignment: CrossAxisAlignment.start,
                    //               children: [
                    //                 Text.rich(
                    //                   TextSpan(
                    //                     text: AppConstants.appName,
                    //                     style: GoogleFonts.openSans(
                    //                       textStyle: TextStyle(
                    //                         color: Colors.white,
                    //                         fontSize: 20.sp,
                    //                         // Adjust font size as needed
                    //                         fontWeight: FontWeight
                    //                             .bold, // Adjust font weight as needed
                    //                       ),
                    //                     ),
                    //                   ),
                    //                   textAlign: TextAlign
                    //                       .start, // Ensure text starts at the beginning
                    //                 ),
                    //                 Text.rich(
                    //                   TextSpan(
                    //                     text:
                    //                         "Now Aaviailable on iOS & Android",
                    //                     style: GoogleFonts.openSans(
                    //                       textStyle: TextStyle(
                    //                         color: Colors.white70,
                    //                         fontSize: 12.sp,
                    //                         // Adjust font size as needed
                    //                         fontWeight: FontWeight
                    //                             .w600, // Adjust font weight as needed
                    //                       ),
                    //                     ),
                    //                   ),
                    //                   textAlign: TextAlign
                    //                       .start, // Ensure text starts at the beginning
                    //                 ),
                    //                 Padding(
                    //                   padding: EdgeInsets.only(
                    //                       left: 00.sp,
                    //                       right: 00.sp,
                    //                       top: 10.sp),
                    //                   child: Container(
                    //                     decoration: BoxDecoration(
                    //                       borderRadius:
                    //                           BorderRadius.circular(10),
                    //                       color: Colors.white24,
                    //                     ),
                    //                     padding: EdgeInsets.all(3.sp),
                    //                     child: Padding(
                    //                       padding: EdgeInsets.all(5.sp),
                    //                       child: Text.rich(
                    //                         TextSpan(
                    //                           text: "Install Now",
                    //                           style: GoogleFonts.openSans(
                    //                             textStyle: TextStyle(
                    //                               color: Colors.white,
                    //                               fontSize: 13.sp,
                    //                               // Adjust font size as needed
                    //                               fontWeight: FontWeight
                    //                                   .bold, // Adjust font weight as needed
                    //                             ),
                    //                           ),
                    //                         ),
                    //                         textAlign: TextAlign
                    //                             .start, // Ensure text starts at the beginning
                    //                       ),
                    //                     ),
                    //                   ),
                    //                 ),
                    //               ],
                    //             ),
                    //           ],
                    //         ),
                    //       ),
                    //     ),
                    //   ),
                    // ),

                    SizedBox(height: 16),
                    // Quick Actions
                    Text(
                      'Settings & More',
                      style: GoogleFonts.openSans(
                        textStyle: TextStyle(
                          color: Colors.black,
                          fontSize: 16.sp,
                          // Adjust font size as needed
                          fontWeight:
                              FontWeight.bold, // Adjust font weight as needed
                        ),
                      ),
                    ),
                    SizedBox(height: 8),
                    Padding(
                      padding: EdgeInsets.only(top: 0.sp),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          // gradient: LinearGradient(
                          //   colors: [
                          //     HexColor('#6663f2'), // Purple
                          //     Colors.purple // Purple
                          //   ],
                          //   begin: Alignment.topLeft,
                          //   end: Alignment.bottomRight,
                          // ),
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          child: Padding(
                            padding: EdgeInsets.all(0.sp),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  height: 5.sp,
                                ),
                                // ListTile(
                                //   trailing: Icon(
                                //     Icons.arrow_forward_ios,
                                //     color: Colors.grey,
                                //     size: 17.sp,
                                //   ),
                                //   leading: Container(
                                //     height: 35.sp,
                                //     width: 35.sp,
                                //     decoration: BoxDecoration(
                                //         borderRadius: BorderRadius.circular(12),
                                //         color: Colors.purple.shade100
                                //         // gradient: LinearGradient(
                                //         //   colors: [
                                //         //     HexColor('#ca8a04'),
                                //         //     HexColor('#ca8a04'),
                                //         //   ],
                                //         //   begin: Alignment.topLeft,
                                //         //   end: Alignment.bottomRight,
                                //         // ),
                                //         ),
                                //     padding: EdgeInsets.all(8.sp),
                                //     child: SvgPicture.asset(
                                //       'assets/theme.svg',
                                //       color: Colors.purple,
                                //     ),
                                //   ),
                                //   title: Column(
                                //     mainAxisAlignment: MainAxisAlignment.start,
                                //     crossAxisAlignment:
                                //         CrossAxisAlignment.start,
                                //     children: [
                                //       Text(
                                //         'Themes',
                                //         style: GoogleFonts.openSans(
                                //           textStyle: TextStyle(
                                //             color: Colors.black,
                                //             fontSize: TextSizes.textmedium14,
                                //             fontWeight: FontWeight.bold,
                                //           ),
                                //         ),
                                //       ),
                                //       Text(
                                //         'Customize appearance',
                                //         style: GoogleFonts.openSans(
                                //           textStyle: TextStyle(
                                //             color: Colors.grey,
                                //             fontSize: 9.sp,
                                //             fontWeight: FontWeight.bold,
                                //           ),
                                //         ),
                                //       ),
                                //     ],
                                //   ),
                                //   onTap: () {},
                                // ),
                                // Divider(
                                //   thickness: 1.sp,
                                //   color: Colors.grey.shade100,
                                // ),
                                // ListTile(
                                //   trailing: Icon(
                                //     Icons.arrow_forward_ios,
                                //     color: Colors.grey,
                                //     size: 17.sp,
                                //   ),
                                //   leading: Container(
                                //     height: 35.sp,
                                //     width: 35.sp,
                                //     decoration: BoxDecoration(
                                //         borderRadius: BorderRadius.circular(12),
                                //         color: Colors.blue.shade50),
                                //     padding: EdgeInsets.all(8.sp),
                                //     child: SvgPicture.asset(
                                //       'assets/languge.svg',
                                //       color: Colors.blue,
                                //     ),
                                //   ),
                                //   title: Column(
                                //     mainAxisAlignment: MainAxisAlignment.start,
                                //     crossAxisAlignment:
                                //         CrossAxisAlignment.start,
                                //     children: [
                                //       Text(
                                //         'Language',
                                //         style: GoogleFonts.openSans(
                                //           textStyle: TextStyle(
                                //             color: Colors.black,
                                //             fontSize: TextSizes.textmedium14,
                                //             fontWeight: FontWeight.bold,
                                //           ),
                                //         ),
                                //       ),
                                //       Text(
                                //         'Change app language',
                                //         style: GoogleFonts.openSans(
                                //           textStyle: TextStyle(
                                //             color: Colors.grey,
                                //             fontSize: 9.sp,
                                //             fontWeight: FontWeight.bold,
                                //           ),
                                //         ),
                                //       ),
                                //     ],
                                //   ),
                                //   onTap: () {},
                                // ),
                                // Divider(
                                //   thickness: 1.sp,
                                //   color: Colors.grey.shade100,
                                // ),
                                // ListTile(
                                //   trailing: Icon(
                                //     Icons.arrow_forward_ios,
                                //     color: Colors.grey,
                                //     size: 17.sp,
                                //   ),
                                //   leading: Container(
                                //       height: 35.sp,
                                //       width: 35.sp,
                                //       decoration: BoxDecoration(
                                //           borderRadius:
                                //               BorderRadius.circular(12),
                                //           color: Colors.green.shade50),
                                //       padding: EdgeInsets.all(10.sp),
                                //       child: Icon(
                                //         FontAwesome.memory_solid,
                                //         color: Colors.green,
                                //         size: 17.sp,
                                //       )
                                //
                                //       // child: Image.asset(
                                //       //   'assets/storage.png',
                                //       //   color: Colors.green,
                                //       // ),
                                //       ),
                                //   title: Column(
                                //     mainAxisAlignment: MainAxisAlignment.start,
                                //     crossAxisAlignment:
                                //         CrossAxisAlignment.start,
                                //     children: [
                                //       Text(
                                //         'Storage Management',
                                //         style: GoogleFonts.openSans(
                                //           textStyle: TextStyle(
                                //             color: Colors.black,
                                //             fontSize: TextSizes.textmedium14,
                                //             fontWeight: FontWeight.bold,
                                //           ),
                                //         ),
                                //       ),
                                //       Text(
                                //         '89 GB of 128 GB used',
                                //         style: GoogleFonts.openSans(
                                //           textStyle: TextStyle(
                                //             color: Colors.grey,
                                //             fontSize: 9.sp,
                                //             fontWeight: FontWeight.bold,
                                //           ),
                                //         ),
                                //       ),
                                //     ],
                                //   ),
                                //   onTap: () {},
                                // ),
                                // Divider(
                                //   thickness: 1.sp,
                                //   color: Colors.grey.shade100,
                                // ),
                                // ListTile(
                                //   trailing: Icon(
                                //     Icons.arrow_forward_ios,
                                //     color: Colors.grey,
                                //     size: 17.sp,
                                //   ),
                                //   leading: Container(
                                //       height: 35.sp,
                                //       width: 35.sp,
                                //       decoration: BoxDecoration(
                                //           borderRadius:
                                //               BorderRadius.circular(12),
                                //           color: Colors.orange.shade50),
                                //       padding: EdgeInsets.all(10.sp),
                                //       child: Icon(
                                //         FontAwesome.question_solid,
                                //         color: Colors.orange,
                                //         size: 17.sp,
                                //       )),
                                //   title: Column(
                                //     mainAxisAlignment: MainAxisAlignment.start,
                                //     crossAxisAlignment:
                                //         CrossAxisAlignment.start,
                                //     children: [
                                //       Text(
                                //         'Help & Support ',
                                //         style: GoogleFonts.openSans(
                                //           textStyle: TextStyle(
                                //             color: Colors.black,
                                //             fontSize: TextSizes.textmedium14,
                                //             fontWeight: FontWeight.bold,
                                //           ),
                                //         ),
                                //       ),
                                //       Text(
                                //         'Get assistance',
                                //         style: GoogleFonts.openSans(
                                //           textStyle: TextStyle(
                                //             color: Colors.grey,
                                //             fontSize: 9.sp,
                                //             fontWeight: FontWeight.bold,
                                //           ),
                                //         ),
                                //       ),
                                //     ],
                                //   ),
                                //   onTap: () {},
                                // ),
                                // Divider(
                                //   thickness: 1.sp,
                                //   color: Colors.grey.shade100,
                                // ),
                                // ListTile(
                                //   trailing: Icon(
                                //     Icons.arrow_forward_ios,
                                //     color: Colors.grey,
                                //     size: 17.sp,
                                //   ),
                                //   leading: Container(
                                //       height: 35.sp,
                                //       width: 35.sp,
                                //       decoration: BoxDecoration(
                                //           borderRadius:
                                //               BorderRadius.circular(12),
                                //           color: Colors.pink.shade50),
                                //       padding: EdgeInsets.all(10.sp),
                                //       child: Icon(
                                //         Icons.settings,
                                //         color: Colors.pink,
                                //         size: 17.sp,
                                //       )),
                                //   title: Column(
                                //     mainAxisAlignment: MainAxisAlignment.start,
                                //     crossAxisAlignment:
                                //         CrossAxisAlignment.start,
                                //     children: [
                                //       Text(
                                //         'Settings',
                                //         style: GoogleFonts.openSans(
                                //           textStyle: TextStyle(
                                //             color: Colors.black,
                                //             fontSize: TextSizes.textmedium14,
                                //             fontWeight: FontWeight.bold,
                                //           ),
                                //         ),
                                //       ),
                                //       Text(
                                //         'Customize your experience',
                                //         style: GoogleFonts.openSans(
                                //           textStyle: TextStyle(
                                //             color: Colors.grey,
                                //             fontSize: 9.sp,
                                //             fontWeight: FontWeight.bold,
                                //           ),
                                //         ),
                                //       ),
                                //     ],
                                //   ),
                                //   onTap: () {
                                //     Navigator.push(
                                //         context,
                                //         MaterialPageRoute(
                                //           builder: (context) => SettingsPage(),
                                //         ));
                                //   },
                                // ),
                                // Divider(
                                //   thickness: 1.sp,
                                //   color: Colors.grey.shade100,
                                // ),


                                ListTile(
                                  trailing: Icon(Icons.arrow_forward_ios,
                                      color: Colors.grey, size: 17.sp),
                                  leading: Container(
                                    height: 35.sp,
                                    width: 35.sp,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      gradient: LinearGradient(
                                        colors: [
                                          HexColor('#dcbeff'),
                                          HexColor('#dcbeff'),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                    ),
                                    padding: EdgeInsets.all(0.sp),
                                    child: Icon(Icons.notifications_none, color: Colors.white),
                                  ),
                                  title: Column(
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Notifications',
                                        style: GoogleFonts.openSans(
                                          textStyle: TextStyle(
                                            color: Colors.black,
                                            fontSize: TextSizes.textmedium14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        'Stay Updated, Never Miss Out ',
                                        style: GoogleFonts.openSans(
                                          textStyle: TextStyle(
                                            color: Colors.grey,
                                            fontSize: 9.sp,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => NotificationScreen(),
                                      ),
                                    );
                                  },
                                ),







                                Divider(
                                  thickness: 1.sp,
                                  color: Colors.grey.shade100,
                                ),
                                ListTile(
                                  trailing: Icon(Icons.arrow_forward_ios,
                                      color: Colors.grey, size: 17.sp),
                                  leading: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      gradient: LinearGradient(
                                        colors: [
                                          HexColor('#334155'),
                                          HexColor('#334155'),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                    ),
                                    padding: EdgeInsets.all(10.sp),
                                    child: SvgPicture.asset(
                                      'assets/privacy.svg',
                                      color: Colors.white,
                                    ),
                                  ),
                                  title: Column(
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Privacy',
                                        style: GoogleFonts.openSans(
                                          textStyle: TextStyle(
                                            color: Colors.black,
                                            fontSize: TextSizes.textmedium14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        'Privacy & security',
                                        style: GoogleFonts.openSans(
                                          textStyle: TextStyle(
                                            color: Colors.grey,
                                            fontSize: 9.sp,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  onTap: () async {
                                    final Uri _url = Uri.parse('https://www.freeprivacypolicy.com/live/3a47e749-0364-44f5-8cc3-559f2cd90336');
                                    if (!await launchUrl(_url, mode: LaunchMode.externalApplication)) {
                                      throw 'Could not launch $_url';
                                    }
                                  },
                                ),
                                Divider(
                                  thickness: 1.sp,
                                  color: Colors.grey.shade100,
                                ),


                                ListTile(
                                  trailing: Icon(Icons.arrow_forward_ios,
                                      color: Colors.grey, size: 17.sp),
                                  leading: Container(
                                    height: 35.sp,
                                    width: 35.sp,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      color: Colors.blue.shade50,
                                    ),
                                    padding: EdgeInsets.all(10.sp),
                                    child: Icon(Icons.share,
                                        color: Colors.blue, size: 17.sp),
                                  ),
                                  title: Column(
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Share App',
                                        style: GoogleFonts.openSans(
                                          textStyle: TextStyle(
                                            color: Colors.black,
                                            fontSize: TextSizes.textmedium14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        'Invite your friends',
                                        style: GoogleFonts.openSans(
                                          textStyle: TextStyle(
                                            color: Colors.grey,
                                            fontSize: 9.sp,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  onTap: () {
                                    Share.share(
                                      'Check out this Vidnexa Video Player App: https://play.google.com/store/apps/details?id=com.vidnexa.videoplayer&pcampaignid=web_share',
                                      subject: 'Download this App',
                                    );
                                  },
                                ),
                                Divider(
                                  thickness: 1.sp,
                                  color: Colors.grey.shade100,
                                ),

                                ListTile(
                                  trailing: Icon(Icons.arrow_forward_ios,
                                      color: Colors.grey, size: 17.sp),
                                  leading: Container(
                                    height: 35.sp,
                                    width: 35.sp,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      color: Colors.red.shade50,
                                    ),
                                    padding: EdgeInsets.all(10.sp),
                                    child: Icon(HeroIcons.paint_brush,
                                        color: Colors.red, size: 17.sp),
                                  ),
                                  title: Column(
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'ToolBar Change',
                                        style: GoogleFonts.openSans(
                                          textStyle: TextStyle(
                                            color: Colors.black,
                                            fontSize: TextSizes.textmedium14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        'Manage your preferences',
                                        style: GoogleFonts.openSans(
                                          textStyle: TextStyle(
                                            color: Colors.grey,
                                            fontSize: 9.sp,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  onTap: () {
                                    showModalBottomSheet(
                                      context: context,
                                      shape: const RoundedRectangleBorder(
                                        borderRadius: BorderRadius.vertical(
                                            top: Radius.circular(20)),
                                      ),
                                      builder: (context) =>
                                          const ColorPickerBottomSheet(),
                                    );
                                  },
                                ),
                                Divider(
                                  thickness: 1.sp,
                                  color: Colors.grey.shade100,
                                ),
                                ListTile(
                                  trailing: Transform.scale(
                                    scale: 0.8,
                                    child: Switch(
                                      value: themeProvider.themeDataStyle == ThemeDataStyle.dark ? true : false,
                                      activeColor: ColorSelect.maineColor,          // ON hone par thumb ka color
                                      activeTrackColor: ColorSelect.maineColor.withOpacity(0.6), // ON hone par track ka color
                                      inactiveThumbColor: Colors.black,  // OFF hone par thumb ka color
                                      inactiveTrackColor: Colors.black26, // OFF hone par track ka halka color
                                      onChanged: (isOn) {
                                        themeProvider.changeTheme();
                                      },
                                    ),
                                  ),
                                  leading: Container(
                                    height: 35.sp,
                                    width: 35.sp,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      color: Colors.blueGrey.shade50,
                                    ),
                                    padding: EdgeInsets.all(10.sp),
                                    child: Icon(Icons.nightlight_round,
                                        color: Colors.blueGrey, size: 17.sp),
                                  ),
                                  title: Column(
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Night Mode',
                                        style: GoogleFonts.openSans(
                                          textStyle: TextStyle(
                                            color: Colors.black,
                                            fontSize: TextSizes.textmedium14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        'Enable dark theme',
                                        style: GoogleFonts.openSans(
                                          textStyle: TextStyle(
                                            color: Colors.grey,
                                            fontSize: 9.sp,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  onTap: () {
                                    showModalBottomSheet(
                                      context: context,
                                      shape: const RoundedRectangleBorder(
                                        borderRadius: BorderRadius.vertical(
                                            top: Radius.circular(20)),
                                      ),
                                      builder: (context) =>
                                          const ColorPickerBottomSheet(),
                                    );
                                  },
                                ),
                                SizedBox(
                                  height: 5.sp,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 80.sp),

            ],
          ),
        ),
      ),
    );
  }

  Future getImage(
    ImageSource img,
  ) async {
    setState(() {
      _loading = true; // Show progress indicator
    });

    ImagePicker imagePicker = ImagePicker();
    XFile? pickedFile = await imagePicker
        .pickImage(source: ImageSource.gallery)
        .catchError((err) {
      Fluttertoast.showToast(msg: err.toString());
      setState(() {
        _loading = false; // Hide progress indicator
      });
      return null;
    });
    File? image;
    if (pickedFile != null) {
      image = File(pickedFile.path);
    }
    if (image != null) {
      setState(() {
        file = image;
        AppStore().setUserImage(file.toString());
      });

      // uploadFile();
    }

    setState(() {
      _loading = false; // Hide progress indicator
    });
  }
}

class ProfileQuickActionList extends StatefulWidget {
  const ProfileQuickActionList({super.key});

  @override
  State<ProfileQuickActionList> createState() => _ProfileQuickActionListState();
}

class _ProfileQuickActionListState extends State<ProfileQuickActionList> {
  List<PropertyTypeModel> items = [
    PropertyTypeModel(
      imageUrl: 'assets/files.png',
      text: ' Folders ',
      color: HexColor('#122620'),
      color2: HexColor('#122620'),
      mb: '3.2 GB',
    ),
    PropertyTypeModel(
      // imageUrl: 'assets/customImages/play.png',
      imageUrl: 'assets/videos.png',
      text: 'Downloads',
      color: HexColor('#18a74f'),
      color2: HexColor('#18a74f'),
      mb: '124 GB',
    ),
    PropertyTypeModel(
      imageUrl: 'assets/image.png',
      text: 'Private',
      color: HexColor('#b570f1'),
      color2: HexColor('#b570f1'),
      mb: '5.6 GB',
    ),
    PropertyTypeModel(
      imageUrl: 'assets/musics.png',
      text: 'Add New ',
      color: HexColor('#f66e7a'),
      color2: HexColor('#f66e7a'),
      mb: '2.2 GB',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(1.sp),
      child: SizedBox(
        height: 95.sp, // Adjust height as needed
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: items.length,
          itemBuilder: (context, index) {
            return GestureDetector(
              onTap: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ComingSoonScreen(title: items[index].text.toString(),),
                    ));
              },
              child: Container(
                  width: MediaQuery.of(context).size.width *
                      0.25, // Adjust width as needed
                  padding: EdgeInsets.all(3.sp),
                  child: Container(
                    height: 25.sp,
                    width: MediaQuery.of(context).size.width * 0.25,
                    // decoration: BoxDecoration(
                    //   gradient: LinearGradient(
                    //     colors: [
                    //       items[index].color, // starting color
                    //       items[index].color2, // ending color
                    //     ],
                    //     begin: Alignment.topLeft,
                    //     end: Alignment.bottomRight,
                    //   ),
                    //   borderRadius: BorderRadius.circular(10.sp),
                    //
                    // ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 50.sp,
                          height: 50.sp,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                items[index].color, // starting color
                                items[index].color2, // ending color
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(10.sp),
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(12.sp),
                            child: Image.asset(
                              items[index].imageUrl,
                              color: Colors.white,
                              height: 25.sp,
                              width: 25.sp,
                            ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.only(bottom: 0.sp, top: 10.sp),
                          child: Text(
                            items[index].text,
                            style: GoogleFonts.poppins(
                              textStyle: TextStyle(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
            );
          },
        ),
      ),
    );
  }
}
