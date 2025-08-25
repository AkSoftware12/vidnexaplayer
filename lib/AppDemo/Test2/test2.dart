import 'package:flutter/material.dart';

import '../Premission/premission.dart';

class Test2Screen extends StatelessWidget {
  const Test2Screen({super.key});
  Future<void> _askPermissions(BuildContext context) async {
    final results = await PermissionManager.requestAppPermissionsSequential();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(results.toString())),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Second Screen")),
      body: Center(
        child: ElevatedButton(
          onPressed: () => _askPermissions(context),
          child: const Text("Check Again"),
        ),
      ),
    );
  }
}
