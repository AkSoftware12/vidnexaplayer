import 'dart:io';
import 'package:disk_space_plus/disk_space_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:videoplayer/Utils/color.dart';
import '../DirectoryFolder/directory_folder.dart';

class DeviceSpaceScreen extends StatefulWidget {
  const DeviceSpaceScreen({super.key});

  @override
  State<DeviceSpaceScreen> createState() => _DeviceSpaceScreenState();
}

class _DeviceSpaceScreenState extends State<DeviceSpaceScreen> {
  double _totalDiskSpaceGB = 0;
  double _freeDiskSpaceGB = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _initDiskSpace();
  }

  Future<void> _initDiskSpace() async {
    if (Platform.isAndroid) {
      await Permission.storage.request();
      await Permission.manageExternalStorage.request();
    }

    try {
      final totalMB = await DiskSpacePlus().getTotalDiskSpace ?? 0;
      final freeMB = await DiskSpacePlus().getFreeDiskSpace ?? 0;

      if (!mounted) return;

      setState(() {
        _totalDiskSpaceGB = totalMB / 1024; // MB → GB
        _freeDiskSpaceGB = freeMB / 1024;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Disk space error: $e');
      setState(() => _loading = false);
    }
  }

  String gb(double value) => value.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.background,
        title: Text(
          'Directory',
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
              'Internal Storage',
              style: GoogleFonts.poppins(
                color: Theme.of(context).colorScheme.secondary,
                fontSize: 13.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(
              'Free ${gb(_freeDiskSpaceGB)} GB of ${gb(_totalDiskSpaceGB)} GB',
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
    );
  }
}
