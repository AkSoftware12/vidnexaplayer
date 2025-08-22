import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'dart:ui';

import 'package:flutter_screenutil/flutter_screenutil.dart'; // For backdrop filter

class CustomVideoAppBar extends StatelessWidget {
  final String title;
  final VoidCallback onBackPressed;

  const CustomVideoAppBar({
    required this.title,
    required this.onBackPressed,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 90.sp, // Fixed height for consistency
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical:0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.black.withOpacity(0.8),
            Colors.black.withOpacity(0.6),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            spreadRadius: 2,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: ClipRRect(
          // Apply blur effect
          child: Row(
            children: [
              // Back Button with animation
              _buildIconButton(
                icon: Icons.arrow_back,
                onPressed: onBackPressed,
                tooltip: 'Back',
              ),
              SizedBox(width: 2.sp,),
              // Title
              Expanded(
                child: Text(
                  title,
                  style:  TextStyle(
                    color: Colors.white,
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(width: 2.sp,),
              // CC Button
              _buildIconButton(
                icon: Icons.closed_caption,
                onPressed: () => print('CC toggled'),
                tooltip: 'Toggle Captions',
              ),
              SizedBox(width: 2.sp,),
              // Music Button
              _buildIconButton(
                icon: Icons.music_note,
                onPressed: () => print('Music toggled'),
                tooltip: 'Toggle Music',
              ),
              SizedBox(width: 2.sp,),
              // Settings Button
              _buildIconButton(
                icon: Icons.playlist_play_sharp,
                onPressed: () => print('Settings'),
                tooltip: 'Settings',
              ),
              SizedBox(width: 2.sp,),
              // Settings Button
              _buildIconButton(
                icon: Icons.arrow_drop_down_circle_rounded,
                onPressed: () => print('Settings'),
                tooltip: 'Settings',
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Reusable IconButton with hover effect and tooltip
  Widget _buildIconButton({
    required IconData icon,
    required VoidCallback onPressed,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.1), // Subtle background for icons
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 24,
          ),
        ),
      ),
    );
  }
}