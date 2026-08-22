import 'package:disk_space_plus/disk_space_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:videoplayer/Utils/color.dart';
import '../DirectoryFolder/directory_folder.dart';
import '../NotifyListeners/LanguageProvider/device_strings.dart';
import '../NotifyListeners/LanguageProvider/language_provider.dart';
import '../ads/app_open_ad_manager.dart';

class DeviceSpaceScreen extends StatefulWidget {
  const DeviceSpaceScreen({super.key});

  @override
  State<DeviceSpaceScreen> createState() => _DeviceSpaceScreenState();
}

class _DeviceSpaceScreenState extends State<DeviceSpaceScreen> {
  final appOpenManager = AppOpenAdManager();

  double _totalDiskSpaceGB = 0;
  double _freeDiskSpaceGB = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _initDiskSpace();
  }

  Future<void> _initDiskSpace() async {
    // Reading free/total disk space needs no storage permission at all.
    // The old code requested MANAGE_EXTERNAL_STORAGE (All-Files Access) here,
    // which requires a Play Console declaration and is grounds for rejection.
    try {
      final disk = DiskSpacePlus();
      final totalMB = await disk.getTotalDiskSpace ?? 0;
      final freeMB = await disk.getFreeDiskSpace ?? 0;

      if (!mounted) return;

      setState(() {
        _totalDiskSpaceGB = totalMB / 1024; // MB → GB
        _freeDiskSpaceGB = freeMB / 1024;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Disk space error: $e');
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  String gb(double value) => value.toStringAsFixed(1);


  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LocaleProvider>().locale.languageCode;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(
          DeviceStrings.t(lang, 'device_appbar_title'),
          style: GoogleFonts.radioCanada(
            color: Theme.of(context).colorScheme.secondary,
            fontSize: 15.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          ListTile(
            leading: Container(
              height: 50.sp,
              width: 50.sp,
              decoration: BoxDecoration(
                color: ColorSelect.maineColor,
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Icon(
                Icons.folder_open_outlined,
                color: Colors.white,
              ),
            ),
            title: Text(
              DeviceStrings.t(lang, 'device_internal_storage'),
              style: GoogleFonts.poppins(
                color: Theme.of(context).colorScheme.secondary,
                fontSize: 13.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(
              DeviceStrings.t(lang, 'device_storage_free_of')
                  .replaceAll('{free}', gb(_freeDiskSpaceGB))
                  .replaceAll('{total}', gb(_totalDiskSpaceGB)),
              style: GoogleFonts.poppins(
                color: Colors.grey,
                fontSize: 11.sp,
              ),
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DirectoryFolder(),
                ),
              );
            },
          ),
          Divider(color: Colors.grey.shade300),
        ],
      ),

      bottomNavigationBar:appOpenManager.bannerWidget(),

    );
  }
}
