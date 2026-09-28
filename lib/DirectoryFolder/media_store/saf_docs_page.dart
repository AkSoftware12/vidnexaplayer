import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../NotifyListeners/LanguageProvider/home_strings.dart';
import '../../NotifyListeners/LanguageProvider/language_provider.dart';
import '../../Utils/app_palette.dart';
import '../file_browser/saf_folder_browser.dart';

/// Documents, archives and apks — the files MediaStore will not hand over.
///
/// ## Why this screen still exists
///
/// Everything else in the file manager reads MediaStore and needs no picker.
/// Non-media is the exception, and not for want of trying: verified on an
/// Android 16 device, a `MediaStore.Files` query that returns 4 500 photos and
/// 24 folders returns **zero** pdfs, apks or zips, and no `Download/` folder at
/// all. Scoped storage filters other apps' non-media files out of the cursor
/// entirely. The rows exist — `adb shell content query` as the shell user lists
/// them — they are simply not visible to an app.
///
/// The two ways round that are `MANAGE_EXTERNAL_STORAGE`, which Play reviews
/// separately and routinely refuses to media players, and the Storage Access
/// Framework. So SAF it is, but scoped down to where it is unavoidable: one
/// folder grant, for documents only, asked for at the moment someone opens
/// this screen rather than as a gate in front of the whole file manager.
///
/// Single screen, no tab strip — it hosts [SafFolderBrowser] directly instead
/// of going through the old five-tab page.
class SafDocsPage extends StatefulWidget {
  const SafDocsPage({
    super.key,
    required this.title,
    this.documentsOnly = true,
    this.accent = const Color(0xFF2563EB),
  });

  final String title;

  /// `true` hides media, leaving documents/archives/apks. `false` browses
  /// everything under the grant, which is what the "all files" entry wants.
  final bool documentsOnly;

  final Color accent;

  @override
  State<SafDocsPage> createState() => _SafDocsPageState();
}

class _SafDocsPageState extends State<SafDocsPage> {
  final _browserKey = GlobalKey<SafFolderBrowserState>();

  String get _lang => context.read<LocaleProvider>().locale.languageCode;
  String _t(String key) => HomeStrings.t(_lang, key);

  @override
  Widget build(BuildContext context) {
    AppPalette.sync(context);

    // The browser consumes back to climb a directory, clear a selection or
    // close its search box before the route is allowed to pop.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_browserKey.currentState?.handleBack() ?? false) return;
        Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: AppPalette.surface,
        appBar: AppBar(
          backgroundColor: AppPalette.surface,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          foregroundColor: AppPalette.textH,
          titleSpacing: 0,
          title: Text(
            widget.title,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppPalette.textH,
            ),
          ),
        ),
        body: SafFolderBrowser(
          key: _browserKey,
          prefsKey: 'file_browser_docs_tree_uri',
          documentsOnly: widget.documentsOnly,
          accent: widget.accent,
          emptyTitle: _t('fb_docs_title'),
          emptyBody: _t('fb_docs_body'),
          pickLabel: _t('fb_pick_folder'),
          changeLabel: _t('fb_change_folder'),
          noItemsLabel: _t('fb_no_docs'),
        ),
      ),
    );
  }
}
