import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:provider/provider.dart';

import '../../NotifyListeners/LanguageProvider/home_strings.dart';
import '../../NotifyListeners/LanguageProvider/language_provider.dart';
import '../../Utils/app_palette.dart';
import '../../Utils/safe_storage.dart';
import '../directory_folder.dart';
import 'audio_folders_view.dart';
import 'media_albums_view.dart';
import 'saf_folder_browser.dart';

/// Unified file browser: Videos, Photos, Music, Docs and Folders.
///
/// ## Why this exists
///
/// The old screen was a single `file_manager` view over `dart:io`, which needs
/// `MANAGE_EXTERNAL_STORAGE` on Android 11+. That permission is not declared in
/// the manifest (declaring it means Google's All-files-access review, which
/// media players routinely fail) and `READ_EXTERNAL_STORAGE` is capped at
/// `maxSdkVersion="32"`. The result on every Android 13+ device was a browser
/// permanently stuck on "Storage access needed" that the user could not unblock
/// — verified on an Android 16 device before this was written.
///
/// The tabs here split the problem along the line Android actually draws:
///
///  * **Videos / Photos / Music** — MediaStore, covered by the granular
///    `READ_MEDIA_*` grants the app already requests. Grouped by real on-disk
///    folder, so it reads as folder browsing.
///  * **Docs / Folders** — Storage Access Framework. The user grants one folder
///    through the system picker, Android persists it, and every sub-folder and
///    file type below it is readable.
///
/// Neither path needs All-files access, so nothing here puts the Play listing
/// at risk. On devices where the classic browser *does* work (Android 12 and
/// below, storage permission held) it is still reachable from the overflow
/// menu — the old screen is kept, not replaced.
class FileBrowserPage extends StatefulWidget {
  const FileBrowserPage({super.key});

  @override
  State<FileBrowserPage> createState() => _FileBrowserPageState();
}

class _FileBrowserPageState extends State<FileBrowserPage>
    with SingleTickerProviderStateMixin {
  static const _videoAccent = Color(0xFFFF7043);
  static const _photoAccent = Color(0xFFEC407A);
  static const _musicAccent = Color(0xFF7E57C2);
  static const _docsAccent = Color(0xFF1E88E5);
  static const _folderAccent = Color(0xFF6C4DF6);

  late final TabController _tabs = TabController(length: 5, vsync: this);

  /// Lets the Folders/Docs tabs consume a back press to climb one level
  /// instead of closing the screen.
  final _foldersKey = GlobalKey<SafFolderBrowserState>();
  final _docsKey = GlobalKey<SafFolderBrowserState>();

  /// Whether the pre-Android-13 filesystem browser can still work here.
  bool _classicAvailable = false;

  @override
  void initState() {
    super.initState();
    _checkClassic();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _checkClassic() async {
    final granted = await SafeStorage.hasStoragePermission();
    if (!mounted) return;
    setState(() => _classicAvailable = granted);
  }

  /// True when the tab handled the press itself.
  bool _handleBack() {
    switch (_tabs.index) {
      case 3:
        return _docsKey.currentState?.handleBack() ?? false;
      case 4:
        return _foldersKey.currentState?.handleBack() ?? false;
      default:
        return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    AppPalette.sync(context);
    final lang = context.watch<LocaleProvider>().locale.languageCode;
    String t(String key) => HomeStrings.t(lang, key);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_handleBack()) return;
        Navigator.pop(context);
      },
      child: Scaffold(
        backgroundColor: AppPalette.surface,
        appBar: AppBar(
          backgroundColor: AppPalette.card,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          title: Text(
            t('fb_title'),
            style: TextStyle(
              fontSize: 17.sp,
              fontWeight: FontWeight.w800,
              color: AppPalette.textH,
            ),
          ),
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: AppPalette.textH),
            onPressed: () {
              if (_handleBack()) return;
              Navigator.pop(context);
            },
          ),
          actions: [
            if (_classicAvailable)
              PopupMenuButton<int>(
                icon: Icon(Icons.more_vert, color: AppPalette.textH),
                onSelected: (_) => Navigator.push(
                  context,
                  MaterialPageRoute(
                    settings:
                        const RouteSettings(name: 'DirectoryFolderScreen'),
                    builder: (_) => const DirectoryFolder(),
                  ),
                ),
                itemBuilder: (context) => [
                  PopupMenuItem<int>(
                    value: 0,
                    child: Text(
                      t('fb_classic'),
                      style: TextStyle(fontSize: 12.5.sp),
                    ),
                  ),
                ],
              ),
          ],
          bottom: PreferredSize(
            preferredSize: Size.fromHeight(46.h),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TabBar(
                controller: _tabs,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                dividerColor: Colors.transparent,
                labelColor: Colors.white,
                unselectedLabelColor: AppPalette.textS,
                labelStyle: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                ),
                unselectedLabelStyle: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                ),
                indicator: BoxDecoration(
                  color: _folderAccent,
                  borderRadius: BorderRadius.circular(20.r),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                padding: EdgeInsets.symmetric(horizontal: 8.w),
                labelPadding: EdgeInsets.symmetric(horizontal: 4.w),
                tabs: [
                  _tab(Icons.movie_rounded, t('fb_tab_videos')),
                  _tab(Icons.photo_rounded, t('fb_tab_photos')),
                  _tab(Icons.music_note_rounded, t('fb_tab_music')),
                  _tab(Icons.description_rounded, t('fb_tab_docs')),
                  _tab(Icons.folder_rounded, t('fb_tab_folders')),
                ],
              ),
            ),
          ),
        ),
        body: TabBarView(
          controller: _tabs,
          children: [
            MediaAlbumsView(
              type: RequestType.video,
              accent: _videoAccent,
              emptyLabel: t('fb_empty_videos'),
              permissionLabel: t('fb_media_permission'),
              grantLabel: t('fb_grant'),
              itemsSuffix: t('fb_videos_suffix'),
            ),
            MediaAlbumsView(
              type: RequestType.image,
              accent: _photoAccent,
              emptyLabel: t('fb_empty_photos'),
              permissionLabel: t('fb_media_permission'),
              grantLabel: t('fb_grant'),
              itemsSuffix: t('fb_photos_suffix'),
            ),
            AudioFoldersView(
              accent: _musicAccent,
              emptyLabel: t('fb_empty_music'),
              permissionLabel: t('fb_audio_permission'),
              grantLabel: t('fb_grant'),
              itemsSuffix: t('fb_songs_suffix'),
            ),
            SafFolderBrowser(
              key: _docsKey,
              prefsKey: 'file_browser_docs_tree_uri',
              documentsOnly: true,
              accent: _docsAccent,
              emptyTitle: t('fb_docs_title'),
              emptyBody: t('fb_docs_body'),
              pickLabel: t('fb_pick_folder'),
              changeLabel: t('fb_change_folder'),
              noItemsLabel: t('fb_no_docs'),
            ),
            SafFolderBrowser(
              key: _foldersKey,
              prefsKey: 'file_browser_folders_tree_uri',
              accent: _folderAccent,
              emptyTitle: t('fb_folders_title'),
              emptyBody: t('fb_folders_body'),
              pickLabel: t('fb_pick_folder'),
              changeLabel: t('fb_change_folder'),
              noItemsLabel: t('fb_no_items'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tab(IconData icon, String label) {
    return Tab(
      height: 38.h,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12.w),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15.sp),
            SizedBox(width: 6.w),
            Text(label),
          ],
        ),
      ),
    );
  }
}
