import 'package:flutter/material.dart';
import 'package:upgrader/upgrader.dart';

class UpgradeTestScreen extends StatelessWidget {
  const UpgradeTestScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upgrade Popup Testing'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '🔄 Upgrade Popup Testing',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            
            // Current Configuration Info
            Card(
              color: Colors.green[50],
              child: const Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '✅ Current Configuration:',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text('✅ clearSavedSettings(): Enabled (Testing)'),
                    Text('✅ debugDisplayAlways: true'),
                    Text('✅ debugLogging: true'),
                    Text('✅ durationUntilAlertAgain: 1ms'),
                    Text('✅ debugDisplayOnce: false'),
                    SizedBox(height: 8),
                    Text(
                      'This means the popup will appear every time you restart the app!',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            const Text(
              'Test different upgrade dialog styles:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            
            // Manual Test Dialog - Shows immediately
            Card(
              color: Colors.purple[50],
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Text(
                      '🟣 Manual Upgrade Dialog Test',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'This will show an upgrade dialog immediately for testing.',
                      style: TextStyle(fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () {
                        showDialog(
                          context: context,
                          barrierDismissible: true,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              title: const Text('🔄 Update Available'),
                              content: const Text(
                                'A new version of VidNexaPlayer is available! '
                                'Update now to get the latest features and improvements.\n\n'
                                'Current Version: 1.0.4\n'
                                'Latest Version: 1.0.5\n\n'
                                'New Features:\n'
                                '• Bug fixes and improvements\n'
                                '• Enhanced performance\n'
                                '• New UI elements',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  child: const Text('Later'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  child: const Text('Ignore'),
                                ),
                                ElevatedButton(
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                    // Simulate opening app store
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('🏪 Would open Play Store in real app'),
                                        backgroundColor: Colors.blue,
                                        duration: Duration(seconds: 3),
                                      ),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text('Update Now'),
                                ),
                              ],
                            );
                          },
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Show Manual Dialog'),
                    ),
                  ],
                ),
              ),
            ),
            
            // Cupertino Style Test  
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Text(
                      '🍎 Cupertino (iOS) Style Test',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Tests the iOS-style upgrade dialog implementation.',
                      style: TextStyle(fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => UpgradeAlert(
                              upgrader: Upgrader(
                                durationUntilAlertAgain: const Duration(seconds: 1),
                                debugDisplayAlways: true,
                              ),
                              child: Scaffold(
                                appBar: AppBar(title: const Text('Cupertino Test')),
                                body: const Center(
                                  child: Text('This screen tests Cupertino style upgrade dialog'),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Test Cupertino Dialog'),
                    ),
                  ],
                ),
              ),
            ),
            
            // Card Style Test
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Text(
                      '🃏 Upgrade Card Style Test',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Shows upgrade information as a card widget instead of a popup.',
                      style: TextStyle(fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => Scaffold(
                              appBar: AppBar(title: const Text('Upgrade Card Test')),
                              body: Column(
                                children: [
                                  const SizedBox(height: 20),
                                  UpgradeCard(
                                    upgrader: Upgrader(
                                      durationUntilAlertAgain: const Duration(seconds: 1),
                                      debugDisplayAlways: true,
                                    ),
                                  ),
                                  const Expanded(
                                    child: Center(
                                      child: Text(
                                        'This demonstrates the UpgradeCard widget.\n\n'
                                        'The card appears inline with your app content '
                                        'instead of as a blocking popup dialog.',
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Test Upgrade Card'),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Clear Settings Test
            Card(
              color: Colors.red[50],
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Text(
                      '🔄 Reset Upgrade Settings',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'This will clear all saved upgrade settings so you can test the popup again.',
                      style: TextStyle(fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () async {
                        await Upgrader.clearSavedSettings();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('🔄 Upgrade settings cleared! Popup will show on next app start.'),
                              backgroundColor: Colors.green,
                              duration: Duration(seconds: 3),
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Clear Upgrade Settings'),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Instructions
            Card(
              color: Colors.blue[50],
              child: const Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '📋 Testing Instructions:',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text('📱 How to Test:'),
                    Text('1. Hot restart the app - popup should appear automatically'),
                    Text('2. Use \"Manual Dialog Test\" above for immediate preview'),
                    Text('3. Check debug console for upgrade logs'),
                    SizedBox(height: 8),
                    Text('🔄 The popup appears when:'),
                    Text('   - App starts (due to current testing config)'),
                    Text('   - A newer version exists in Play Store'),
                    Text('   - User hasn\'t dismissed it recently'),
                    SizedBox(height: 8),
                    Text('⚠️ For Production Release:'),
                    Text('   - Remove clearSavedSettings() from main.dart'),
                    Text('   - Set debugDisplayAlways: false'),
                    Text('   - Use normal durationUntilAlertAgain (like Duration(days: 3))'),
                    Text('   - Remove debugLogging: true'),
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
