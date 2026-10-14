import 'package:material_ui/material_ui.dart';
import 'package:pdfx/pdfx.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../NotifyListeners/LanguageProvider/home_strings.dart';
import '../../NotifyListeners/LanguageProvider/language_provider.dart';
import '../../Utils/app_palette.dart';
import '../media_store/media_store.dart';
import 'package:videoplayer/ads/ads_manager.dart';

/// In-app PDF viewer for the file manager.
///
/// PDFs used to be handed straight to whatever other app could open them —
/// and on phones with no PDF reader installed, that was a "no app can open
/// this file" dead end. This renders them here, with pinch-zoom that
/// re-renders at the new size (text stays sharp), a page counter, share, and
/// "open with another app" kept as an option.
///
/// Rendering is Android's own `PdfRenderer` (via `pdfx`), so no PDF engine is
/// bundled into the APK. PdfRenderer needs a real file, and MediaStore only
/// hands out `content://` uris, so the file is first copied into the cache —
/// see [MediaStoreRepo.copyToCache], which keeps only the latest copy.
class PdfViewerPage extends StatefulWidget {
  const PdfViewerPage({super.key, required this.file});

  final MediaFile file;

  @override
  State<PdfViewerPage> createState() => _PdfViewerPageState();
}

class _PdfViewerPageState extends State<PdfViewerPage> {
  PdfControllerPinch? _controller;
  String? _path;
  bool _failed = false;
  int _page = 1;
  int _pages = 0;

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    final path = await MediaStoreRepo.instance.copyToCache(widget.file);
    if (!mounted) return;
    if (path == null) {
      setState(() => _failed = true);
      return;
    }
    setState(() {
      _path = path;
      _controller = PdfControllerPinch(document: PdfDocument.openFile(path));
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _openOutside() async {
    final lang = context.read<LocaleProvider>().locale.languageCode;
    final messenger = ScaffoldMessenger.of(context);
    final opened = await MediaStoreRepo.instance.openExternally(widget.file);
    if (!opened && mounted) {
      messenger.showSnackBar(
        SnackBar(content: Text(HomeStrings.t(lang, 'fb_open_failed'))),
      );
    }
  }

  Future<void> _share() async {
    final path = _path;
    if (path == null) return;
    AdsManager.skipNextAppOpen();
    await SharePlus.instance.share(
      ShareParams(files: [XFile(path, mimeType: 'application/pdf')]),
    );
  }

  @override
  Widget build(BuildContext context) {
    AppPalette.sync(context);
    final lang = context.watch<LocaleProvider>().locale.languageCode;
    String t(String key) => HomeStrings.t(lang, key);
    final controller = _controller;

    return Scaffold(
      backgroundColor: AppPalette.surface,
      appBar: AppBar(
        backgroundColor: AppPalette.surface,
        iconTheme: IconThemeData(color: AppPalette.textH),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.file.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppPalette.textH,
              ),
            ),
            if (_pages > 0)
              Text(
                t('pdf_page')
                    .replaceAll('{page}', '$_page')
                    .replaceAll('{total}', '$_pages'),
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11.5,
                  color: AppPalette.textS,
                ),
              ),
          ],
        ),
        actions: [
          if (_path != null)
            IconButton(
              icon: const Icon(Icons.share_outlined),
              onPressed: _share,
            ),
          IconButton(
            tooltip: t('pdf_open_with'),
            icon: const Icon(Icons.open_in_new_rounded),
            onPressed: _openOutside,
          ),
        ],
      ),
      body: _failed
          ? _Failed(message: t('pdf_failed'), action: t('pdf_open_with'),
              onAction: _openOutside)
          : controller == null
              ? const Center(child: CircularProgressIndicator())
              : PdfViewPinch(
                  controller: controller,
                  backgroundDecoration: BoxDecoration(
                    color: AppPalette.raised,
                  ),
                  onDocumentLoaded: (document) {
                    if (mounted) setState(() => _pages = document.pagesCount);
                  },
                  onPageChanged: (page) {
                    if (mounted) setState(() => _page = page);
                  },
                  builders: PdfViewPinchBuilders<DefaultBuilderOptions>(
                    options: const DefaultBuilderOptions(),
                    documentLoaderBuilder: (_) =>
                        const Center(child: CircularProgressIndicator()),
                    pageLoaderBuilder: (_) =>
                        const Center(child: CircularProgressIndicator()),
                    // Password-protected and damaged files land here.
                    errorBuilder: (_, __) => _Failed(
                      message: t('pdf_failed'),
                      action: t('pdf_open_with'),
                      onAction: _openOutside,
                    ),
                  ),
                ),
    );
  }
}

class _Failed extends StatelessWidget {
  const _Failed({
    required this.message,
    required this.action,
    required this.onAction,
  });

  final String message;
  final String action;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.picture_as_pdf_rounded,
                size: 48, color: AppPalette.textS),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                color: AppPalette.textB,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: Text(action),
            ),
          ],
        ),
      ),
    );
  }
}
