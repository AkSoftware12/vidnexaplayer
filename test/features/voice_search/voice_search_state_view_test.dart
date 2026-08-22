import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:videoplayer/features/voice_search/domain/entities/media_kind.dart';
import 'package:videoplayer/features/voice_search/presentation/controllers/voice_search_controller.dart';
import 'package:videoplayer/features/voice_search/presentation/widgets/voice_search_state_view.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('VoiceSearchStateView', () {
    testWidgets('idle shows a hint with example commands', (tester) async {
      await tester.pumpWidget(_wrap(VoiceSearchStateView(
        state: VoiceSearchState.idle,
        errorMessage: null,
        onRetry: () {},
        onOpenSettings: () {},
        onExampleTap: (_) {},
      )));

      expect(find.textContaining('Tap the mic'), findsOneWidget);
      expect(find.text('recent videos'), findsOneWidget);
    });

    testWidgets('processing shows a spinner and label', (tester) async {
      await tester.pumpWidget(_wrap(VoiceSearchStateView(
        state: VoiceSearchState.processing,
        errorMessage: null,
        onRetry: () {},
        onOpenSettings: () {},
        onExampleTap: (_) {},
      )));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Processing...'), findsOneWidget);
    });

    testWidgets('searching shows a spinner and label', (tester) async {
      await tester.pumpWidget(_wrap(VoiceSearchStateView(
        state: VoiceSearchState.searching,
        errorMessage: null,
        onRetry: () {},
        onOpenSettings: () {},
        onExampleTap: (_) {},
      )));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Searching...'), findsOneWidget);
    });

    testWidgets('noResults shows the friendly empty state and example chips', (tester) async {
      await tester.pumpWidget(_wrap(VoiceSearchStateView(
        state: VoiceSearchState.noResults,
        errorMessage: null,
        onRetry: () {},
        onOpenSettings: () {},
        onExampleTap: (_) {},
      )));

      expect(find.text('No videos found'), findsOneWidget);
      expect(find.text('Downloads videos'), findsOneWidget);
    });

    testWidgets('noResults for a photo search says "No photos found"', (tester) async {
      await tester.pumpWidget(_wrap(VoiceSearchStateView(
        state: VoiceSearchState.noResults,
        errorMessage: null,
        mediaKind: MediaKind.photo,
        onRetry: () {},
        onOpenSettings: () {},
        onExampleTap: (_) {},
      )));

      expect(find.text('No photos found'), findsOneWidget);
      expect(find.text('No videos found'), findsNothing);
    });

    testWidgets('noResults for a music search says "No songs found"', (tester) async {
      await tester.pumpWidget(_wrap(VoiceSearchStateView(
        state: VoiceSearchState.noResults,
        errorMessage: null,
        mediaKind: MediaKind.music,
        onRetry: () {},
        onOpenSettings: () {},
        onExampleTap: (_) {},
      )));

      expect(find.text('No songs found'), findsOneWidget);
    });

    testWidgets('tapping an example chip invokes onExampleTap with its text', (tester) async {
      String? tapped;
      await tester.pumpWidget(_wrap(VoiceSearchStateView(
        state: VoiceSearchState.noResults,
        errorMessage: null,
        onRetry: () {},
        onOpenSettings: () {},
        onExampleTap: (text) => tapped = text,
      )));

      await tester.tap(find.text('MP4 videos'));
      await tester.pump();

      expect(tapped, 'MP4 videos');
    });

    testWidgets('permissionDenied shows a friendly message, never a raw error', (tester) async {
      await tester.pumpWidget(_wrap(VoiceSearchStateView(
        state: VoiceSearchState.permissionDenied,
        errorMessage: 'PlatformException(mic, ...)',
        onRetry: () {},
        onOpenSettings: () {},
        onExampleTap: (_) {},
      )));

      expect(find.text('Microphone access needed'), findsOneWidget);
      expect(find.text('Open Settings'), findsOneWidget);
      expect(find.textContaining('PlatformException'), findsNothing);
    });

    testWidgets('tapping "Open Settings" invokes onOpenSettings', (tester) async {
      var tapped = false;
      await tester.pumpWidget(_wrap(VoiceSearchStateView(
        state: VoiceSearchState.permissionDenied,
        errorMessage: null,
        onRetry: () {},
        onOpenSettings: () => tapped = true,
        onExampleTap: (_) {},
      )));

      await tester.tap(find.text('Open Settings'));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('speechError shows the friendly message and a retry button', (tester) async {
      var retried = false;
      await tester.pumpWidget(_wrap(VoiceSearchStateView(
        state: VoiceSearchState.speechError,
        errorMessage: "Didn't catch that. Please try again.",
        onRetry: () => retried = true,
        onOpenSettings: () {},
        onExampleTap: (_) {},
      )));

      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.text("Didn't catch that. Please try again."), findsOneWidget);

      await tester.tap(find.text('Try Again'));
      await tester.pump();
      expect(retried, isTrue);
    });

    testWidgets('listening and results render nothing (handled elsewhere)', (tester) async {
      await tester.pumpWidget(_wrap(VoiceSearchStateView(
        state: VoiceSearchState.listening,
        errorMessage: null,
        onRetry: () {},
        onOpenSettings: () {},
        onExampleTap: (_) {},
      )));
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(SizedBox), findsWidgets);
    });
  });
}
