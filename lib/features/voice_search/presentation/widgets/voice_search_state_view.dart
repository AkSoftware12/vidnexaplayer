import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../NotifyListeners/LanguageProvider/language_provider.dart';
import '../../../../NotifyListeners/LanguageProvider/misc_strings.dart';
import '../../../../Utils/color.dart';
import '../../domain/entities/media_kind.dart';
import '../controllers/voice_search_controller.dart';

/// Renders the non-results, non-idle-mic states of the search screen:
/// processing/searching spinners, the no-results empty state (with example
/// command chips per the spec), permission-denied, and speech-error — each
/// with a friendly message, never a raw exception string.
class VoiceSearchStateView extends StatelessWidget {
  const VoiceSearchStateView({
    super.key,
    required this.state,
    required this.errorMessage,
    this.mediaKind,
    required this.onRetry,
    required this.onOpenSettings,
    required this.onExampleTap,
  });

  final VoiceSearchState state;
  final String? errorMessage;

  /// The kind that was searched for — only meaningful for [VoiceSearchState.noResults],
  /// so "No videos found" doesn't show up for a photo/music search that
  /// genuinely found nothing.
  final MediaKind? mediaKind;
  final VoidCallback onRetry;
  final VoidCallback onOpenSettings;
  final void Function(String command) onExampleTap;

  static String _noun(MediaKind? kind, String lang) {
    switch (kind) {
      case MediaKind.photo:
        return MiscStrings.t(lang, 'voice_search_noun_photos');
      case MediaKind.music:
        return MiscStrings.t(lang, 'voice_search_noun_songs');
      case MediaKind.video:
      case null:
        return MiscStrings.t(lang, 'voice_search_noun_videos');
    }
  }

  static const _examples = [
    'recent videos',
    'Downloads videos',
    'MP4 videos',
    'WhatsApp videos',
  ];

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LocaleProvider>().locale.languageCode;
    switch (state) {
      case VoiceSearchState.idle:
        return _hint(MiscStrings.t(lang, 'voice_search_hint_try'));
      case VoiceSearchState.listening:
      case VoiceSearchState.results:
        return const SizedBox.shrink();
      case VoiceSearchState.processing:
        return _loading(MiscStrings.t(lang, 'voice_search_processing'));
      case VoiceSearchState.searching:
        return _loading(MiscStrings.t(lang, 'voice_search_searching'));
      case VoiceSearchState.noResults:
        return _message(
          icon: Icons.search_off_rounded,
          title: MiscStrings.t(lang, 'voice_search_no_results_template')
              .replaceAll('{noun}', _noun(mediaKind, lang)),
          subtitle: MiscStrings.t(lang, 'voice_search_try_saying'),
          showExamples: true,
        );
      case VoiceSearchState.permissionDenied:
        return _message(
          icon: Icons.mic_off_rounded,
          title: MiscStrings.t(lang, 'voice_search_mic_needed_title'),
          subtitle: MiscStrings.t(lang, 'voice_search_mic_needed_subtitle'),
          action: ElevatedButton(
            onPressed: onOpenSettings,
            child: Text(MiscStrings.t(lang, 'voice_search_open_settings')),
          ),
        );
      case VoiceSearchState.speechError:
        return _message(
          icon: Icons.error_outline_rounded,
          title: MiscStrings.t(lang, 'voice_search_something_wrong'),
          subtitle: errorMessage ?? MiscStrings.t(lang, 'voice_search_please_try_again'),
          action: ElevatedButton(
            onPressed: onRetry,
            child: Text(MiscStrings.t(lang, 'voice_search_try_again')),
          ),
        );
    }
  }

  Widget _loading(String label) {
    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: Column(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 12),
          Text(label, style: GoogleFonts.poppins(fontSize: 13, color: ColorSelect.subtextColor)),
        ],
      ),
    );
  }

  Widget _hint(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 13, color: ColorSelect.subtextColor),
          ),
          const SizedBox(height: 14),
          _exampleChips(),
        ],
      ),
    );
  }

  Widget _message({
    required IconData icon,
    required String title,
    required String subtitle,
    bool showExamples = false,
    Widget? action,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        children: [
          Icon(icon, size: 44, color: ColorSelect.subtextColor),
          const SizedBox(height: 12),
          Text(title, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 12, color: ColorSelect.subtextColor),
          ),
          if (showExamples) ...[
            const SizedBox(height: 14),
            _exampleChips(),
          ],
          if (action != null) ...[
            const SizedBox(height: 16),
            action,
          ],
        ],
      ),
    );
  }

  Widget _exampleChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: _examples
          .map(
            (e) => ActionChip(
              label: Text(e, style: GoogleFonts.poppins(fontSize: 11.5)),
              onPressed: () => onExampleTap(e),
            ),
          )
          .toList(),
    );
  }
}
