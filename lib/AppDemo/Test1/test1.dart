import 'package:flutter/material.dart';
import 'package:instamusic/AppDemo/Test2/test2.dart';
import 'package:permission_handler/permission_handler.dart';
import '../Premission/premission.dart';

class Test1Screen extends StatelessWidget {
  const Test1Screen({super.key});

  Future<void> _askPermissions(BuildContext context) async {
    final results = await PermissionManager.requestAppPermissionsSequential();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(results.toString())),
    );
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Home Screen")),
      body: Center(
        child: Column(
          children: [
            ElevatedButton(
              onPressed:(){
                Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (context) => const Test2Screen()));

              },              child: const Text("Next"),
            ),
            ElevatedButton(
              onPressed: () => _askPermissions(context),
              child: const Text("Request Permissions"),
            ),
          ],
        ),
      ),
    );
  }
}
