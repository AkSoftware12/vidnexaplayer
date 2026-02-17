import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:videoplayer/HexColorCode/HexColor.dart';
import 'package:videoplayer/OnboardScreen/size_config.dart';
import 'package:videoplayer/Utils/color.dart';
import 'package:animate_do/animate_do.dart';
import '../Permission/permission_page.dart';
import 'onboarding_contents.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({Key? key}) : super(key: key);

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late PageController _controller;
  int _currentPage = 0;
  static const String _adUnitId =
      'ca-app-pub-6478840988045325/7764390357'; // ✅ TEST ID
  List colors = [HexColor('#081740'), HexColor('#081740'), HexColor('#081740')];

  @override
  void initState() {
    super.initState();
    _controller = PageController();
  }

  BannerAd banner = BannerAd(
    adUnitId: _adUnitId, // TEST BANNER
    size: AdSize.banner,
    request: const AdRequest(),
    listener: BannerAdListener(
      onAdLoaded: (ad) {
        debugPrint('✅ Banner loaded');
        debugPrint('✅ bannerId $_adUnitId');
      },
      onAdFailedToLoad: (ad, error) {
        debugPrint('❌ Banner failed: $error');
      },
    ),
  )..load();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  AnimatedContainer _buildDots({int? index}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.all(Radius.circular(50)),
        color:
            _currentPage == index
                ? ColorSelect.maineColor
                : const Color(0xFFBDBDBD),
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

    return Scaffold(
      backgroundColor: colors[_currentPage],
      body: Column(
        children: [
          SizedBox(height: 20.sp),
          Container(
            color: HexColor('#081740'),
            child: Padding(
              padding: EdgeInsets.all(10.sp),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'All Features',
                    style: GoogleFonts.poppins(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 1.2,
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(8.sp),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10.r),
                      onTap: () {
                        _controller.jumpToPage(contents.length - 1);
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10.w,
                          vertical: 3.h,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10.r),
                          border: Border.all(
                            color: Colors.blue.shade200,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          'Skip',
                          style: GoogleFonts.openSans(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  )
                ],
              ),
            ),
          ),


          // Onboarding Pages
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
                            child: Image.asset(content.image,),
                          ),
                        ),
                      ),
                      SizedBox(height: 10.sp),
                      Center(
                        child: Padding(
                          padding: EdgeInsets.all(0.sp),
                          child: Container(
                            margin: EdgeInsets.zero,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Colors.blue, Colors.blue],
                              ),
                              borderRadius: BorderRadius.circular(5),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 10,
                                  offset: Offset(4, 4),
                                ),
                              ],
                            ),
                            padding: EdgeInsets.all(3.sp),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.safety_check_rounded,
                                  color: Colors.white,
                                  size: 13.sp,
                                ),
                                SizedBox(width: 2.sp),
                                Text(
                                  'Your data is safe with us.',
                                  style: TextStyle(
                                    fontSize: 10.sp,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 10.sp),

                      // Features List
                      ...List.generate(content.list.length, (index) {
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
                              padding: EdgeInsets.all(3.sp),
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          feature.title,
                                          style: GoogleFonts.poppins(
                                            fontSize: 13.sp,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.white,
                                          ),
                                        ),
                                        SizedBox(height: 4.sp),
                                        Text(
                                          feature.description,
                                          style: GoogleFonts.poppins(
                                            fontSize: 10.sp,
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
                      }),
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
                    ? Padding(
                      padding: EdgeInsets.all(10.sp),
                      child: SizedBox(
                        width: double.infinity,
                        height: 40.sp,
                        child: TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const PermissionPage(),
                              ),
                            );
                          },
                          style: TextButton.styleFrom(
                            backgroundColor: HexColor('#008000'),
                            padding: EdgeInsets.symmetric(
                              horizontal: 10.w,
                              vertical: 5.h,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20.sp),
                              side: const BorderSide(
                                color: Colors.white,
                                width: 1,
                              ),
                            ),
                          ),
                          child: Text(
                            "Get Started",
                            style: GoogleFonts.openSans(
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                      ),
                    )
                    : Padding(
                      padding: EdgeInsets.all(10.sp),
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
                            padding: EdgeInsets.symmetric(
                              horizontal: 10.w,
                              vertical: 5.h,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20.sp),
                              side: const BorderSide(
                                color: Colors.white,
                                width: 1,
                              ),
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
                              SizedBox(width: 5.sp),
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

          SizedBox(height: 50.sp,
              child: AdWidget(ad: banner)),
        ],
      ),
    );
  }
}
