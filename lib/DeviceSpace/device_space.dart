import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:instamusic/Utils/color.dart';
import 'package:path_provider/path_provider.dart';

import '../DirectoryFolder/directory_folder.dart';
class DeviceSpaceScreen extends StatefulWidget {
  const DeviceSpaceScreen({super.key});

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<DeviceSpaceScreen> {
  double _totalDiskSpace = 0;
  double _freeDiskSpace = 0;
  Map<Directory, double> _directorySpace = {};

  @override
  void initState() {
    super.initState();
    initDiskSpacePlus();
  }

  Future<void> initDiskSpacePlus() async {
    double totalDiskSpace = 0;
    double freeDiskSpace = 0;

    // totalDiskSpace = await DiskSpacePlus.getTotalDiskSpace ?? 0;
    // freeDiskSpace = await DiskSpacePlus.getFreeDiskSpace ?? 0;

    List<Directory> directories;
    Map<Directory, double> directorySpace = {};

    if (Platform.isIOS) {
      directories = [await getApplicationDocumentsDirectory()];
    } else if (Platform.isAndroid) {
      directories = await getExternalStorageDirectories(type: StorageDirectory.movies)
          .then((list) async => list ?? [await getApplicationDocumentsDirectory()]);
    } else {
      return;
    }

    for (var directory in directories) {
      // var space = await DiskSpacePlus.getFreeDiskSpaceForPath(directory.path) ?? 0;
      // directorySpace[directory] = space;
    }

    if (!mounted) return;

    setState(() {
      _totalDiskSpace = totalDiskSpace;
      _freeDiskSpace = freeDiskSpace;
      _directorySpace = directorySpace;
    });
  }

  String formatSpace(double spaceInMB) {
    return (spaceInMB / 1024).toStringAsFixed(1); // Convert MB to GB and format to 2 decimal places
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        backgroundColor:Theme.of(context).colorScheme.background,
        automaticallyImplyLeading: true,
        title:  Text('Directory',
            style: GoogleFonts.radioCanada(
            textStyle: TextStyle(
            color: Theme.of(context).colorScheme.secondary,
        fontSize: 15.sp,
        // Adjust font size as needed
        fontWeight: FontWeight
            .bold, // Adjust font weight as needed
      ),
    ),
        ),
      ),
      body: Container(
        color: Theme.of(context).colorScheme.background,
        child: Column(
          children: [
            Expanded(
              child:  Container(
                child: Column(
                  children: [
                    ListTile(
                      leading: Container(
                        height: 50.sp,
                        width: 50.sp,
                        decoration: BoxDecoration(
                          color: ColorSelect.maineColor,
                          borderRadius: BorderRadius.circular(15.0),
                        ),
                        child: Icon(Icons.folder_open_outlined,color: Colors.white,),
                      ),
                      title:  Text('Internal Storage',
                        style: GoogleFonts.poppins(
                          textStyle: TextStyle(
                            color: Theme.of(context).colorScheme.secondary,
                            fontSize: 13.sp,
                            // Adjust font size as needed
                            fontWeight: FontWeight
                                .bold, // Adjust font weight as needed
                          ),
                        ),
                      ),
                      subtitle: Text('Free ${formatSpace(_freeDiskSpace)} ${'GB of'} ${formatSpace(_totalDiskSpace)} ${'GB'}',
                        style: GoogleFonts.poppins(
                          textStyle: TextStyle(
                            color:Colors.grey,
                            fontSize: 10.sp,
                            // Adjust font size as needed
                            fontWeight: FontWeight
                                .normal, // Adjust font weight as needed
                          ),
                        ),
                      ),
                      onTap: (){
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  DirectoryFolder(),)

                        );
                      },

                    ),
                    Divider(
                      height: 5,
                      color: Colors.grey.shade300,
                    )
                  ],
                ),
              ),
            ),



          ],
        ),
      ),
    );
  }
}