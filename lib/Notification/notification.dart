import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:videoplayer/Utils/color.dart';


class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.grey[100],
        title: Text('Notifications',
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
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.notifications,
                size: 80,
                color: ColorSelect.maineColor,
              ),
            ),
            SizedBox(height: 20),
            Text(
              'No Notifications Yet',
              style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                "You're all caught up! We'll notify you when there's something new",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14.sp, color: Colors.grey[600]),
              ),
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