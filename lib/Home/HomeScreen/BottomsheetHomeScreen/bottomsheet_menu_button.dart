import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:photo_manager/photo_manager.dart';
import '../../../VideoPLayer/VideoList/video_list.dart';
import '../DialogHomeScreen/FolderInfoDialog/folder_info_dialog.dart';


class FolderBottomSheet {
  static void show(
      BuildContext context, {
        required String folderName,
        required final AssetPathEntity videos,
        required String formattedSize,
        required String location,
        required String date,
      }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30.0)),
      ),
      sheetAnimationStyle: const AnimationStyle(
        duration: Duration(milliseconds: 700),
        reverseDuration: Duration(milliseconds: 500),
      ),
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F5),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30.0)),
            boxShadow: const [
              BoxShadow(color: Colors.black12, blurRadius: 15, spreadRadius: 5),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Header ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(2.sp),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(color: Colors.blue),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: SizedBox(
                          height: 25.sp,
                          width: 25.sp,
                          child: Image.asset('assets/appblue.png'),
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Vidnexa Player',
                            style: GoogleFonts.poppins(
                              textStyle: TextStyle(
                                color: Colors.blue,
                                fontSize: 16.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Text(
                            '($folderName)',
                            style: GoogleFonts.poppins(
                              textStyle: TextStyle(
                                color: Colors.purple,
                                fontSize: 10.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.close_outlined, color: Colors.blue, size: 25.sp),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              SizedBox(height: 16.h),

              // --- Divider ---
              Container(
                height: 4,
                margin: EdgeInsets.only(bottom: 16.0),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),

              // --- Grid Options ---
              GridView.count(
                crossAxisCount: 4,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1,
                children: [
                  _buildOptionCard(
                    context,
                    Icons.folder,
                    'Open',
                    Colors.blue,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => VideoFolderScreen(
                            folderName: folderName,
                            videos: videos,
                          ),
                        ),
                      );
                    },
                  ),
                  _buildOptionCard(
                    context,
                    Icons.delete,
                    'Delete',
                    Theme.of(context).colorScheme.error,
                    onTap: () {
                      Navigator.pop(context);
                      // handle delete here
                    },
                  ),
                  _buildOptionCard(
                    context,
                    Icons.info_outline,
                    'Info',
                    Theme.of(context).colorScheme.secondary,
                    onTap: () {
                      Navigator.pop(context);
                      FolderInfoDialog.show(
                        context,
                        folderName: folderName,
                        size: formattedSize,
                        location: location,
                        modifiedDate: date,
                        videos: videos,
                      );
                    },
                  ),
                  _buildOptionCard(
                    context,
                    Icons.copy,
                    'Copy',
                    Theme.of(context).colorScheme.secondary,
                    onTap: () {},
                  ),
                  _buildOptionCard(
                    context,
                    Icons.visibility_off,
                    'Hide',
                    Theme.of(context).colorScheme.secondary,
                    onTap: () {},
                  ),
                ],
              ),
              SizedBox(height: 24.h),
            ],
          ),
        );
      },
    );
  }

  static Widget _buildOptionCard(
      BuildContext context,
      IconData icon,
      String label,
      Color color, {
        required Function() onTap,
      }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(5.sp),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(5),
              ),
              child: Icon(icon, color: color, size: 22.sp),
            ),
            SizedBox(height: 6.h),
            Text(
              label,
              style: GoogleFonts.openSans(
                textStyle: TextStyle(
                  color: color,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
