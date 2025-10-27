import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:videoplayer/HexColorCode/HexColor.dart';
import 'package:videoplayer/OnboardScreen/size_config.dart';
import 'package:videoplayer/Utils/color.dart';
import 'package:animate_do/animate_do.dart'; // Added for animations if needed
import '../Permission/permission_page.dart';
import 'onboarding_contents.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({Key? key}) : super(key: key);

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late PageController _controller;

  @override
  void initState() {
    _controller = PageController();
    super.initState();
  }

  int _currentPage = 0;
  List colors = [
    HexColor('#081740'),
    HexColor('#081740'),
    HexColor('#081740'),
  ];

  AnimatedContainer _buildDots({
    int? index,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.all(
          Radius.circular(50),
        ),
        color: _currentPage == index ? ColorSelect.maineColor : const Color(0xFFBDBDBD),
      ),
      margin: const EdgeInsets.only(right: 5),
      height: 10,
      curve: Curves.easeIn,
      width: _currentPage == index ? 40 : 10,
    );
  }

  @override
  Widget build(BuildContext context) {
    SizeConfig().init(context);
    double width = SizeConfig.screenW!;
    double height = SizeConfig.screenH!;

    return SafeArea(
      child: Scaffold(
        backgroundColor: colors[_currentPage],
        body: Column(
          children: [
            SizedBox(
              height: 20.sp,
            ),

            Container(
              // height: 50.sp,
              color: HexColor('#081740'),
              child: Padding(
                padding:  EdgeInsets.all(10.sp),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'All Features',
                      style: GoogleFonts.poppins(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 1.2,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: TextButton(
                        onPressed: () {
                          _controller.jumpToPage(contents.length - 1);

                        },

                        style: TextButton.styleFrom(
                          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 0.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.r),
                            side: BorderSide(color: Colors.blue.shade200, width: 1),
                          ),
                        ),
                        child: Text(
                          'Skip',
                          style: GoogleFonts.openSans(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),

                  ],
                ),
              ),
            ),

            Expanded(
              flex: 8,
              child: PageView.builder(
                physics: const BouncingScrollPhysics(),
                controller: _controller,
                onPageChanged: (value) => setState(() => _currentPage = value),
                itemCount: contents.length,
                itemBuilder: (context, i) {
                  final content = contents[i];
                  return SingleChildScrollView(
                    padding: EdgeInsets.all(5.sp),
                    child: Column(
                      children: [
                        FadeInDown(
                          duration: const Duration(milliseconds: 800),
                          child: Container(
                            height: 180.sp,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20.sp),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20.sp),
                              child: Image.asset(content.image),
                            ),
                          ),
                        ),
                        SizedBox(height: 5.sp),
                        Center(
                          child: Padding(
                            padding:  EdgeInsets.all(0.sp),
                            child: Container(
                              margin: EdgeInsets.zero,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    // HexColor('#c30917'),
                                    // Colors.purple,
                                    Colors.blue,
                                    Colors.blue,
                                    // Colors.purple,
                                    // HexColor('#c30917'),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(5),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 10,
                                    offset: Offset(4, 4),
                                  ),
                                ],
                              ),
                              padding: EdgeInsets.all(3.sp),
                              child: Center(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                         Icon(
                                          Icons.safety_check_rounded,
                                          color: Colors.white,
                                          size: 15.sp,
                                        ),
                                        SizedBox(width: 5.sp),
                                        Text(
                                          'Your data is safe with us.',
                                          style: TextStyle(
                                            fontSize: 12.sp,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Features List
                        ...List.generate(
                          content.list.length,
                              (index) {
                            final feature = content.list[index];
                            return FadeInUp(
                              duration: Duration(milliseconds: 300 + (index * 100)),
                              child: Card(
                                elevation: 0,
                                color: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15.sp),
                                ),
                                margin: EdgeInsets.symmetric(vertical: 5.sp),
                                child: Padding(
                                  padding: EdgeInsets.all(5.sp),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: EdgeInsets.all(5.sp),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade100,
                                          borderRadius: BorderRadius.circular(8.sp),
                                        ),
                                        child: Icon(
                                          feature.icon,
                                          color: HexColor('#7209B7'),
                                          size: 20.sp,
                                        ),
                                      ),
                                      SizedBox(width: 16.sp),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              feature.title,
                                              style: GoogleFonts.poppins(
                                                fontSize: 14.sp,
                                                fontWeight: FontWeight.w500,
                                                color: Colors.white,
                                              ),
                                            ),
                                            SizedBox(height: 4.sp),
                                            Text(
                                              feature.description,
                                              style: GoogleFonts.poppins(
                                                fontSize: 11.sp,
                                                fontWeight: FontWeight.w300,
                                                color: Colors.grey.shade100,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            // Bottom Navigation
            Expanded(
              flex: 1,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _currentPage + 1 == contents.length
                      ?
                  Padding(
                    padding:  EdgeInsets.all(10.sp),
                    child: SizedBox(
                      width: double.infinity,
                      height: 40.sp,

                      child: TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const PermissionPage()),
                          );
                        },

                        style: TextButton.styleFrom(
                          backgroundColor: HexColor('#008000'),
                          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20.sp),
                            side: const BorderSide(color: Colors.white, width: 1),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // SvgPicture.asset(
                            //   'assets/svgviewer-output.svg',
                            //   color: Colors.white,
                            //   width: 25.sp,
                            //   height: 25.sp,
                            // ),
                            // SizedBox(
                            //   width: 5.sp,
                            // ),
                            Text(
                              "Get Started",
                              style: GoogleFonts.openSans(
                                fontSize: 15.sp,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )



                      :

                  Padding(
                    padding:  EdgeInsets.all(10.sp),
                    child: SizedBox(
                      width: double.infinity,
                      height: 40.sp,

                      child: TextButton(
                        onPressed: () {
                          _controller.nextPage(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeIn,
                          );
                        },

                        style: TextButton.styleFrom(
                          backgroundColor: HexColor('#008000'),
                          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20.sp),
                            side: const BorderSide(color: Colors.white, width: 1),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SvgPicture.asset(
                              'assets/svgviewer-output.svg',
                              color: Colors.white,
                              width: 25.sp,
                              height: 25.sp,
                            ),
                            SizedBox(
                              width: 5.sp,
                            ),
                            Text(
                              "Next",
                              style: GoogleFonts.openSans(
                                fontSize: 15.sp,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),



                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}