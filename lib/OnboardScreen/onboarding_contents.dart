import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class OnboardingContents {
  final String image;
  final List<CounsellingToolFeature> list;

  OnboardingContents( {
    required this.image,
    required this.list,
  });
}
class CounsellingToolFeature {
  final String title;
  final String description;
  final IconData icon;

  CounsellingToolFeature({
    required this.title,
    required this.description,
    required this.icon,
  });
}

List<OnboardingContents> contents = [


   OnboardingContents(
    image: "assets/landing_one.png",
     list:  [
       CounsellingToolFeature(
         title: "Playback Controls",
         description: "Play, pause, rewind, fast-forward, and frame-by-frame navigation.",
         icon: Icons.play_arrow,
       ),
       CounsellingToolFeature(
         title: "Volume and Brightness Gestures",
         description: "Swipe to adjust volume and screen brightness easily.",
         icon: Icons.volume_up,
       ),
       CounsellingToolFeature(
         title: "Subtitle Support",
         description: "Easy loading and customization of subtitles for accessibility.",
         icon: Icons.closed_caption,
       ),
       CounsellingToolFeature(
         title: "Quality Selection",
         description: "Choose video quality from SD to 8K based on your connection.",
         icon: Icons.settings,
       ),
       CounsellingToolFeature(
         title: "Adaptive Streaming",
         description: "Automatically adjusts video quality for smooth playback.",
         icon: Icons.autorenew,
       ),
     ],
  ),
  OnboardingContents(
    image: "assets/landing_two.png",
    list: [

      CounsellingToolFeature(
        title: "Offline Downloads",
        description: "Download videos for offline viewing anytime.",
        icon: Icons.download,
      ),
      CounsellingToolFeature(
        title: "Casting Support",
        description: "Cast videos to TV or other devices via Chromecast or AirPlay.",
        icon: Icons.cast,
      ),
      CounsellingToolFeature(
        title: "Playlist Management",
        description: "Create, edit, and manage playlists for organized viewing.",
        icon: Icons.playlist_add,
      ),
      CounsellingToolFeature(
        title: "Resume Playback",
        description: "Automatically resume videos from where you left off.",
        icon: Icons.history,
      ),
      CounsellingToolFeature(
        title: "Playback Speed Control",
        description: "Adjust playback speed from 0.5x to 2x for flexible viewing.",
        icon: Icons.speed,
      ),

    ],
  ),
  OnboardingContents(
    image: "assets/landing_tree.png",
    list:  [
      CounsellingToolFeature(
        title: "Picture-in-Picture Mode",
        description: "Watch videos in a floating window while multitasking.",
        icon: Icons.picture_in_picture,
      ),
      CounsellingToolFeature(
        title: "Dark Mode",
        description: "Switch to dark theme for comfortable night viewing.",
        icon: Icons.dark_mode,
      ),
      CounsellingToolFeature(
        title: "Wide Format Support",
        description: "Play all formats including MP4, MKV, AVI, and more.",
        icon: Icons.movie,
      ),
      CounsellingToolFeature(
        title: "Voice Controls",
        description: "Use voice commands for hands-free playback control.",
        icon: Icons.mic,
      ),
      CounsellingToolFeature(
        title: "Gallery",
        description: "View and manage your favorite photos and videos easily.",
        icon: Icons.photo_library,
      ),

    ],
  ),
];
