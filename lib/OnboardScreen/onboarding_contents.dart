import 'package:material_ui/material_ui.dart';

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

// Only features the app actually has. An onboarding screen that promises
// 8K, downloads or Chromecast the app does not ship is a misleading-claims
// risk under Play policy, so check the code before adding a line here.
List<OnboardingContents> contents = [
   OnboardingContents(
    image: "assets/landing_one.png",
     list:  [
       CounsellingToolFeature(
         title: "Playback Controls",
         description: "Play, pause, seek, rotate and lock the screen while you watch.",
         icon: Icons.play_arrow,
       ),
       CounsellingToolFeature(
         title: "Volume and Brightness Gestures",
         description: "Swipe to adjust volume and screen brightness easily.",
         icon: Icons.volume_up,
       ),
       CounsellingToolFeature(
         title: "Volume Boost",
         description: "Go past 100% when a video is too quiet.",
         icon: Icons.volume_up_rounded,
       ),
       CounsellingToolFeature(
         title: "Playback Speed Control",
         description: "Adjust playback speed from 0.5x to 3x.",
         icon: Icons.speed,
       ),
       CounsellingToolFeature(
         title: "Resume Playback",
         description: "Pick up videos from where you left off.",
         icon: Icons.history,
       ),
     ],
  ),
  OnboardingContents(
    image: "assets/landing_two.png",
    list: [
      CounsellingToolFeature(
        title: "Picture-in-Picture Mode",
        description: "Watch videos in a floating window while multitasking.",
        icon: Icons.picture_in_picture,
      ),
      CounsellingToolFeature(
        title: "Equalizer",
        description: "Presets, bass boost and dialogue clarity for music and video.",
        icon: Icons.equalizer,
      ),
      CounsellingToolFeature(
        title: "Offline Music",
        description: "Play your songs in the background with notification controls.",
        icon: Icons.music_note,
      ),
      CounsellingToolFeature(
        title: "Private Vault",
        description: "Keep photos, videos and files behind a PIN or fingerprint.",
        icon: Icons.lock,
      ),
      CounsellingToolFeature(
        title: "File Manager",
        description: "Browse, copy, move and zip the files on your phone.",
        icon: Icons.folder,
      ),
    ],
  ),
  OnboardingContents(
    image: "assets/landing_tree.png",
    list:  [
      CounsellingToolFeature(
        title: "Dark Mode",
        description: "Switch to dark theme for comfortable night viewing.",
        icon: Icons.dark_mode,
      ),
      CounsellingToolFeature(
        title: "Wide Format Support",
        description: "Plays MP4, MKV, AVI and many more formats.",
        icon: Icons.movie,
      ),
      CounsellingToolFeature(
        title: "Voice Search",
        description: "Find your videos, songs and photos by speaking.",
        icon: Icons.mic,
      ),
      CounsellingToolFeature(
        title: "Gallery",
        description: "View and organise your photos, and find duplicates.",
        icon: Icons.photo_library,
      ),
      CounsellingToolFeature(
        title: "Play from a Link",
        description: "Stream a video by pasting its web address.",
        icon: Icons.link,
      ),
    ],
  ),
];
