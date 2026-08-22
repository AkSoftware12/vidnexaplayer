import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:videoplayer/features/voice_search/presentation/widgets/mic_button.dart';

void main() {
  group('MicButton', () {
    testWidgets('idle shows the outlined mic icon', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: MicButton(isListening: false, onTap: () {})),
      ));

      expect(find.byIcon(Icons.mic_none_rounded), findsOneWidget);
      expect(find.byIcon(Icons.mic), findsNothing);
    });

    testWidgets('listening shows the filled mic icon and ripple rings', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: MicButton(isListening: true, onTap: () {})),
      ));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byIcon(Icons.mic), findsOneWidget);
      expect(find.byIcon(Icons.mic_none_rounded), findsNothing);
    });

    testWidgets('tapping invokes onTap', (tester) async {
      var tapped = false;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: MicButton(isListening: false, onTap: () => tapped = true)),
      ));

      await tester.tap(find.byType(MicButton));
      expect(tapped, isTrue);
    });
  });
}
