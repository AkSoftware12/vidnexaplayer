import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:videoplayer/Utils/color.dart';


class ComingSoonScreen extends StatelessWidget {
  final String title;
  const ComingSoonScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.grey[100],
        title: Text('${title}',
          style: GoogleFonts.openSans(
            textStyle: TextStyle(
              color: Colors.black,
              fontSize: 16.sp,
              // Adjust font size as needed
              fontWeight: FontWeight
                  .bold, // Adjust font weight as needed
            ),
          ),),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/coming-soon.png',
              width: 300.sp,
              height: 200.sp,
              fit: BoxFit.contain,
            ),
            SizedBox(height: 30),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Back button functionality
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: ColorSelect.maineColor,

                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              ),
              child: Text(
                'Go Back',
                style: GoogleFonts.openSans(
                  textStyle: TextStyle(
                    color: Colors.white,
                    fontSize: 16.sp,
                    // Adjust font size as needed
                    fontWeight: FontWeight
                        .bold, // Adjust font weight as needed
                  ),
                ),              ),
            ),
          ],
        ),
      ),
    );
  }
}