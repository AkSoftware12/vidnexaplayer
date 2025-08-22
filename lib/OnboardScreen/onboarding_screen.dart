import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:instamusic/HexColorCode/HexColor.dart';
import 'package:instamusic/OnboardScreen/size_config.dart';
import 'package:instamusic/Utils/color.dart';

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
  List colors = const [

    Colors.white,
    Colors.white,
    Colors.white,
    // Color(0xffDAD3C8),
    // Color(0xffFFE5DE),
    // Color(0xffDCF6E6),
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

    return Scaffold(

      backgroundColor: colors[_currentPage],
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              flex: 3,
              child: PageView.builder(
                physics: const BouncingScrollPhysics(),
                controller: _controller,
                onPageChanged: (value) => setState(() => _currentPage = value),
                itemCount: contents.length,
                itemBuilder: (context, i) {
                  return Padding(
                    padding:  EdgeInsets.all(0.0),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,

                          children: [

                            TextButton(
                              onPressed: () {
                                _controller.jumpToPage(2);
                              },
                              style: TextButton.styleFrom(
                                elevation: 0,
                                textStyle: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: (width <= 550) ? 13 : 17,
                                ),
                              ),
                              child:  Text(
                                "Skip",
                                style: GoogleFonts.openSans(
                                  fontSize: 15.sp,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey,

                                ),
                              ),
                            ),
                          ],
                        ),
                        Image.asset(
                          contents[i].image,
                          height: SizeConfig.blockV! * 35,
                        ),
                         SizedBox(height: 30.sp),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            contents.length,
                                (int index) => _buildDots(
                              index: index,
                            ),
                          ),
                        ),

                        SizedBox(
                          height: (height >= 840) ? 60 : 30,
                        ),
                        Text(
                          contents[i].title,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.openSans(
                            fontSize: (width <= 550) ? 25.sp : 30.sp,
                            fontWeight: FontWeight.w700,
                            color: ColorSelect.titletextColor,

                          ),

                        ),
                        const SizedBox(height: 15),
                        Padding(
                          padding:  EdgeInsets.only(left: 20.sp,right: 20.sp),
                          child: Text(
                            contents[i].desc,
                            style: GoogleFonts.openSans(
                              fontSize: (width <= 550) ? 17.sp : 25.sp,
                              fontWeight: FontWeight.w500,
                              color: ColorSelect.subtextColor,
                            ),

                            textAlign: TextAlign.center,
                          ),
                        )
                      ],
                    ),
                  );
                },
              ),
            ),
            Expanded(
              flex: 1,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _currentPage + 1 == contents.length
                      ? Padding(
                          padding: const EdgeInsets.all(30),
                          child: ElevatedButton(
                            onPressed: () {

                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => PermissionPage()),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor:ColorSelect.maineColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(13),
                              ),
                              padding: (width <= 550)
                                  ? const EdgeInsets.symmetric(horizontal: 100, vertical: 12)
                                  : const EdgeInsets.symmetric(horizontal: 100, vertical: 12),
                              textStyle: TextStyle(fontSize: (width <= 550) ? 13 : 17),
                            ),
                            child:  Text("Get Started",
                              style: GoogleFonts.openSans(
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,

                            ),


                          ),
                          ),
                        )
                      : Padding(
                          padding: const EdgeInsets.all(30),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [

                              ElevatedButton(
                                onPressed: () {
                                  _controller.nextPage(
                                    duration: const Duration(milliseconds: 200),
                                    curve: Curves.easeIn,
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: ColorSelect.maineColor,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  elevation: 0,
                                  padding: (width <= 550)
                                      ? const EdgeInsets.symmetric(horizontal: 20, vertical: 12)
                                      : const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                  textStyle: TextStyle(fontSize: (width <= 550) ? 13 : 17),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      "Next",
                                      style: GoogleFonts.openSans(
                                        fontSize: 15.sp,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                        letterSpacing: 1.0,
                                        shadows: [
                                          const Shadow(
                                            blurRadius: 3.0,
                                            color: Colors.black54,
                                            offset: Offset(1.0, 1.0),
                                          ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(width: 8.w),
                                    SvgPicture.asset(
                                      'assets/svgviewer-output.svg',
                                      color: Colors.white, // Sets the SVG fill color to white
                                      width: 20.sp, // Matches the size of 18.sp
                                      height: 20.sp,
                                    ),
                                  ],
                                ),
                              )
                            ],
                          ),
                        )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
