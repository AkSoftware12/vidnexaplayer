import 'package:flutter/material.dart';



class SettingItem {
  final String title;
  final String description;
  final IconData icon;

  SettingItem({
    required this.title,
    required this.description,
    required this.icon,
  });
}


class SettingsPage extends StatefulWidget {

  const SettingsPage({super.key});




  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  List<SettingItem> settings = [
    SettingItem(
      title: 'Premium',
      description: 'Try Premium version and Remove Ad',
      icon: Icons.currency_rupee, // Replace with appropriate icon
    ),
    SettingItem(
      title: 'Restore Purchase',
      description: 'Regain access to the VIP features',
      icon: Icons.shopping_bag,
    ),
    SettingItem(
      title: 'General',
      description: 'Theme, Night Mode, Language...',
      icon: Icons.settings,
    ),
    SettingItem(
      title: 'Downloader & Browser',
      description: 'Clear Cache, History, Cookies',
      icon: Icons.language,
    ),
    SettingItem(
      title: 'Video Player',
      description: 'Display clock, Skip video, Orientation...',
      icon: Icons.videocam,
    ),
    SettingItem(
      title: 'Vault Security',
      description: 'Unlock fingerprint and change pin protection',
      icon: Icons.lock,
    ),
    SettingItem(
      title: 'Music Player',
      description: 'Tab Order, Duration, Lock Screen widget',
      icon: Icons.music_note,
    ),
    SettingItem(
      title: 'Help',
      description: 'Updates, Feedback, Recover Pin, FAQ...',
      icon: Icons.help,
    ),
    SettingItem(
      title: 'About Us',
      description: 'Privacy Policy',
      icon: Icons.info,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Settings'),
      ),
      body: ListView.builder(
        itemCount: settings.length,
        itemBuilder: (context, index) {
          final item = settings[index];
          return ListTile(
            leading: Icon(item.icon),
            title: Text(item.title),
            subtitle: Text(item.description),
            onTap: () {
              // Handle the item tap, e.g., navigate to another page
            },
          );
        },
      ),
    );
  }
}
