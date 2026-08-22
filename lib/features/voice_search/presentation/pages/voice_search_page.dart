import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../../../NotifyListeners/LanguageProvider/language_provider.dart';
import '../../../../NotifyListeners/LanguageProvider/misc_strings.dart';
import '../../../../Utils/color.dart';
import '../../domain/entities/media_kind.dart';
import '../controllers/voice_search_controller.dart';
import '../services/video_index_service.dart';
import '../widgets/mic_button.dart';
import '../widgets/voice_search_result_tile.dart';
import '../widgets/voice_search_state_view.dart';

/// Entry point pushed from the mic icon in `home_bottomNavigation.dart`'s
/// app bar. Wraps a route-scoped [VoiceSearchController] — this feature
/// doesn't need a globally registered provider in `main.dart` since most
/// sessions never open it; it shares the same [VideoSearchRepositoryImpl]
/// instance `VideoIndexService` uses for background indexing, so search
/// always reads whatever the background indexer has already written.
class VoiceSearchPage extends StatelessWidget {
  const VoiceSearchPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => VoiceSearchController(
        repository: VideoIndexService.instance.repository,
      ),
      child: const _VoiceSearchView(),
    );
  }
}

class _VoiceSearchView extends StatefulWidget {
  const _VoiceSearchView();

  @override
  State<_VoiceSearchView> createState() => _VoiceSearchViewState();
}

class _VoiceSearchViewState extends State<_VoiceSearchView> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels > position.maxScrollExtent - 400) {
      context.read<VoiceSearchController>().loadMore();
    }
  }

  String _localeIdFor(BuildContext context) {
    final locale = context.read<LocaleProvider>().locale;
    return locale.languageCode == 'hi' ? 'hi_IN' : 'en_IN';
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<VoiceSearchController>();
    final scheme = Theme.of(context).colorScheme;
    final lang = context.watch<LocaleProvider>().locale.languageCode;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        elevation: 0,
        iconTheme: IconThemeData(color: scheme.secondary),
        title: Text(
          MiscStrings.t(lang, 'voice_search_title'),
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: scheme.secondary),
        ),
      ),
      body: Column(
        children: [
          const SizedBox(height: 12),
          MicButton(
            isListening: controller.state == VoiceSearchState.listening,
            onTap: () {
              if (controller.state == VoiceSearchState.listening) {
                controller.stopListening();
              } else {
                controller.startListening(localeId: _localeIdFor(context));
              }
            },
          ),
          const SizedBox(height: 8),
          _RecognizedTextBanner(controller: controller),
          Expanded(
            child: controller.state == VoiceSearchState.results
                ? _ResultsList(scrollController: _scrollController, controller: controller)
                : SingleChildScrollView(
                    child: VoiceSearchStateView(
                      state: controller.state,
                      errorMessage: controller.errorMessage,
                      mediaKind: controller.lastQuery?.mediaKind,
                      onRetry: () => controller.startListening(localeId: _localeIdFor(context)),
                      onOpenSettings: () {
                        openAppSettings();
                      },
                      onExampleTap: controller.runTextQuery,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _RecognizedTextBanner extends StatelessWidget {
  const _RecognizedTextBanner({required this.controller});

  final VoiceSearchController controller;

  @override
  Widget build(BuildContext context) {
    final isListening = controller.state == VoiceSearchState.listening;
    final text = isListening ? controller.partialText : controller.recognizedText;
    final lang = context.watch<LocaleProvider>().locale.languageCode;

    if (text.isEmpty && !isListening) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      child: Text(
        isListening && text.isEmpty ? MiscStrings.t(lang, 'voice_search_listening') : '"$text"',
        textAlign: TextAlign.center,
        style: GoogleFonts.poppins(
          fontSize: 13,
          fontStyle: FontStyle.italic,
          color: ColorSelect.subtextColor,
        ),
      ),
    );
  }
}

/// "Found 3 videos" / "Found 3 photos" / "Found 3 songs" — the old copy was
/// hardcoded to "videos" even for photo/music results, which read as if the
/// wrong thing had been found.
String _resultsNoun(MediaKind? kind, String lang) {
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

class _ResultsList extends StatelessWidget {
  const _ResultsList({required this.scrollController, required this.controller});

  final ScrollController scrollController;
  final VoiceSearchController controller;

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LocaleProvider>().locale.languageCode;
    final countText = '${controller.results.length}${controller.hasMore ? '+' : ''}';
    final foundText = MiscStrings.t(lang, 'voice_search_found_template')
        .replaceAll('{count}', countText)
        .replaceAll('{noun}', _resultsNoun(controller.lastQuery?.mediaKind, lang));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              foundText,
              style: GoogleFonts.poppins(fontSize: 12, color: ColorSelect.subtextColor),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            controller: scrollController,
            itemCount: controller.results.length + (controller.isLoadingMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index >= controller.results.length) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final video = controller.results[index];
              return VoiceSearchResultTile(
                key: ValueKey(video.id),
                video: video,
                onStale: controller.removeStale,
              );
            },
          ),
        ),
      ],
    );
  }
}
