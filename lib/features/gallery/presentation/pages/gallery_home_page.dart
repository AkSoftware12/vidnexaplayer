import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../../Analytics/screen_analytics.dart';
import '../../../../NotifyListeners/LanguageProvider/device_strings.dart';
import '../../../../NotifyListeners/LanguageProvider/language_provider.dart';
import '../../../../Utils/app_palette.dart';
import '../../../../Utils/color.dart';
import '../../../../ads/app_open_ad_manager.dart';
import '../../data/repositories/gallery_repository_impl.dart';
import '../../domain/entities/gallery_permission.dart';
import '../../domain/entities/photo_album.dart';
import '../../domain/repositories/gallery_repository.dart';
import '../controllers/gallery_controller.dart';
import '../services/photo_signature_service.dart';
import '../widgets/album_card.dart';
import '../widgets/gallery_dialog.dart';
import '../widgets/gallery_permission_view.dart';
import '../widgets/gallery_segmented_tabs.dart';
import '../widgets/photo_grid.dart';
import '../widgets/tools_tab.dart';
import 'album_photos_page.dart';
import 'smart_search_page.dart';

/// Entry point of the gallery module.
///
/// Owns the repository and the library-wide [GalleryController] for the whole
/// subtree, so the Photos tab, the Albums tab and the viewer all read the same
/// thumbnail cache and the same permission result. Album pages push their own
/// controller but reuse this repository, which is what keeps the cache shared.
class GalleryHomePage extends StatefulWidget {
  const GalleryHomePage({super.key});

  @override
  State<GalleryHomePage> createState() => _GalleryHomePageState();
}

class _GalleryHomePageState extends State<GalleryHomePage> {
  /// Built once, not in `build` — a rebuild that replaced the repository would
  /// throw away every cached thumbnail with it.
  late final GalleryRepository _repository = GalleryRepositoryImpl();

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<GalleryRepository>.value(value: _repository),
        ChangeNotifierProvider<GalleryController>(
          create: (_) => GalleryController(repository: _repository)..init(),
        ),
      ],
      child: const _GalleryHomeView(),
    );
  }
}

class _GalleryHomeView extends StatefulWidget {
  const _GalleryHomeView();

  @override
  State<_GalleryHomeView> createState() => _GalleryHomeViewState();
}

class _GalleryHomeViewState extends State<_GalleryHomeView> {
  final AppOpenAdManager _adManager = AppOpenAdManager();

  @override
  Widget build(BuildContext context) {
    AppPalette.sync(context);
    final controller = context.watch<GalleryController>();
    final lang = context.watch<LocaleProvider>().locale.languageCode;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppPalette.surface,
        appBar: controller.selectionMode
            ? _SelectionAppBar(lang: lang)
            : _GalleryAppBar(lang: lang),
        body: !controller.ready
            ? Center(
                child: CircularProgressIndicator(color: ColorSelect.maineColor),
              )
            : !controller.permission.canRead
                ? const GalleryPermissionView()
                : Column(
                    children: [
                      if (controller.permission == GalleryPermission.limited)
                        const LimitedAccessBanner(),
                      const Expanded(
                        child: TabScreenReporter(
                          names: [
                            'GalleryHomeScreen_Photos',
                            'GalleryHomeScreen_Albums',
                            'GalleryHomeScreen_Tools',
                          ],
                          child: TabBarView(
                            children: [
                              PhotoGrid(),
                              _AlbumsTab(),
                              ToolsTab(),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
        bottomNavigationBar: _adManager.bannerWidget(),
      ),
    );
  }
}

/// Flat header: the page background carried up behind a big title, with the
/// actions as raised circles.
///
/// The coloured block it replaces competed with the accent-tinted hero on the
/// Tools tab — two saturated purples stacked with 14dp between them. Letting
/// the bar recede leaves exactly one accent surface on screen at a time.
class _GalleryAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _GalleryAppBar({required this.lang});

  final String lang;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 58);

  @override
  Widget build(BuildContext context) {
    AppPalette.sync(context);

    return AppBar(
      backgroundColor: AppPalette.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      // Without this the bar tints itself as content scrolls under it, which
      // on a flat header reads as the background changing colour mid-scroll.
      scrolledUnderElevation: 0,
      titleSpacing: 2.sp,
      leadingWidth: 54.sp,
      leading: Center(
        child: GalleryCircleButton(
          icon: Icons.arrow_back_rounded,
          onTap: () => Navigator.maybePop(context),
        ),
      ),
      title: Text(
        DeviceStrings.t(lang, 'gallery_title'),
        style: TextStyle(fontFamily: 'Poppins', fontSize: 19.sp,
          fontWeight: FontWeight.w700,
          color: AppPalette.textH,
        ),
      ),
      actions: [
        GalleryCircleButton(
          icon: Icons.search_rounded,
          tooltip: DeviceStrings.t(lang, 'gallery_tool_search_title'),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SmartSearchPage(
                repository: context.read<GalleryRepository>(),
              ),
              settings: const RouteSettings(name: 'GallerySmartSearchScreen'),

            ),
          ),
        ),
        SizedBox(width: 8.sp),
        _GalleryMenuButton(lang: lang),
        SizedBox(width: 12.sp),
      ],
      bottom: GallerySegmentedTabs(
        labels: [
          DeviceStrings.t(lang, 'gallery_tab_photos'),
          DeviceStrings.t(lang, 'gallery_tab_albums'),
          DeviceStrings.t(lang, 'gallery_tab_tools'),
        ],
      ),
    );
  }
}

enum _GalleryMenuAction { refresh, rescan }

/// The overflow menu. Two actions, both of which re-read something that can go
/// stale behind the app's back: the library itself, and the signature index
/// the tools are built on.
class _GalleryMenuButton extends StatelessWidget {
  const _GalleryMenuButton({required this.lang});

  final String lang;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_GalleryMenuAction>(
      tooltip: '',
      padding: EdgeInsets.zero,
      position: PopupMenuPosition.under,
      color: AppPalette.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.sp),
      ),
      onSelected: (action) => _run(context, action),
      itemBuilder: (context) => [
        _item(
          _GalleryMenuAction.refresh,
          Icons.refresh_rounded,
          DeviceStrings.t(lang, 'gallery_menu_refresh'),
        ),
        _item(
          _GalleryMenuAction.rescan,
          Icons.data_usage_rounded,
          DeviceStrings.t(lang, 'gallery_menu_rescan'),
        ),
      ],
      child: Container(
        width: 35.sp,
        height: 35.sp,
        decoration: BoxDecoration(
          color: AppPalette.card,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.more_vert_rounded,
          size: 19.sp,
          color: AppPalette.textH,
        ),
      ),
    );
  }

  PopupMenuItem<_GalleryMenuAction> _item(
    _GalleryMenuAction action,
    IconData icon,
    String label,
  ) {
    return PopupMenuItem<_GalleryMenuAction>(
      value: action,
      height: 42.sp,
      child: Row(
        children: [
          Icon(icon, size: 17.sp, color: AppPalette.textB),
          SizedBox(width: 10.sp),
          Text(
            label,
            style: TextStyle(fontFamily: 'Poppins', fontSize: 11.5.sp,
              fontWeight: FontWeight.w500,
              color: AppPalette.textH,
            ),
          ),
        ],
      ),
    );
  }

  void _run(BuildContext context, _GalleryMenuAction action) {
    switch (action) {
      case _GalleryMenuAction.refresh:
        context.read<GalleryController>().refresh();

      case _GalleryMenuAction.rescan:
        // Deliberately not awaited: a full re-sign of a large library runs for
        // minutes, and the index card on the Tools tab is already wired to the
        // service's progress, so that is where it is watched.
        unawaited(PhotoSignatureService.instance.rebuild());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 2),
            content: Text(DeviceStrings.t(lang, 'gallery_menu_rescan_started')),
          ),
        );
    }
  }
}

/// Replaces the app bar while photos are selected. Selection lives in the
/// controller, so this same bar serves the grid, the album page, and — in
/// later phases — the collage picker and the junk cleaner's review screen.
class _SelectionAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _SelectionAppBar({required this.lang});

  final String lang;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<GalleryController>();

    return AppBar(
      backgroundColor: ColorSelect.maineColor,
      elevation: 4,
      iconTheme: const IconThemeData(color: Colors.white),
      leading: IconButton(
        icon: const Icon(Icons.close, color: Colors.white),
        onPressed: controller.clearSelection,
      ),
      title: Text(
        DeviceStrings.t(lang, 'gallery_selected_count')
            .replaceAll('{count}', '${controller.selectedCount}'),
        style: TextStyle(fontFamily: 'OpenSans', color: Colors.white,
          fontSize: 15.sp,
          fontWeight: FontWeight.w500,
        ),
      ),
      actions: [
        IconButton(
          tooltip: DeviceStrings.t(lang, 'gallery_select_all'),
          icon: const Icon(Icons.select_all, color: Colors.white),
          onPressed: controller.selectAll,
        ),
        IconButton(
          tooltip: DeviceStrings.t(lang, 'gallery_share'),
          icon: const Icon(Icons.share_outlined, color: Colors.white),
          onPressed: controller.shareSelected,
        ),
        IconButton(
          tooltip: DeviceStrings.t(lang, 'gallery_delete'),
          icon: const Icon(Icons.delete_outline, color: Colors.white),
          onPressed: () => confirmDeleteSelection(context, lang),
        ),
      ],
    );
  }
}

/// Confirms and runs a batched delete of the current selection.
///
/// Shared by the gallery home and the album page. The batch matters: on
/// Android 11+ each `deleteWithIds` call raises a system consent dialog, so
/// passing the whole selection at once means one dialog instead of one per
/// photo.
Future<void> confirmDeleteSelection(BuildContext context, String lang) async {
  final controller = context.read<GalleryController>();
  final count = controller.selectedCount;
  if (count == 0) return;

  final messenger = ScaffoldMessenger.of(context);

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => GalleryDialog(
      icon: Icons.delete_outline,
      title: DeviceStrings.t(lang, 'gallery_delete_title'),
      destructive: true,
      actions: [
        DialogCancelButton(
          label: DeviceStrings.t(lang, 'gallery_cancel'),
          onPressed: () => Navigator.pop(dialogContext, false),
        ),
        DialogConfirmButton(
          label: DeviceStrings.t(lang, 'gallery_delete'),
          destructive: true,
          onPressed: () => Navigator.pop(dialogContext, true),
        ),
      ],
      child: Text(
        count == 1
            ? DeviceStrings.t(lang, 'gallery_delete_body_one')
            : DeviceStrings.t(lang, 'gallery_delete_body')
                .replaceAll('{count}', '$count'),
        style: TextStyle(fontFamily: 'Poppins', fontSize: 12.5.sp, height: 1.45),
      ),
    ),
  );
  if (confirmed != true) return;

  final deleted = await controller.deleteSelected();

  // Zero deletions means the system consent dialog was declined — a normal
  // outcome, so it gets no error toast.
  if (deleted == 0) return;

  messenger.showSnackBar(
    SnackBar(
      duration: const Duration(seconds: 2),
      content: Text(
        DeviceStrings.t(lang, 'gallery_deleted_toast')
            .replaceAll('{count}', '$deleted'),
      ),
    ),
  );
}

class _AlbumsTab extends StatefulWidget {
  const _AlbumsTab();

  @override
  State<_AlbumsTab> createState() => _AlbumsTabState();
}

class _AlbumsTabState extends State<_AlbumsTab> {
  final AppOpenAdManager _adManager = AppOpenAdManager();

  /// Albums shown before the in-feed ad — one full row at two columns.
  ///
  /// Album cards are large, deliberate targets that nobody taps in a hurry,
  /// so a band between rows is safe here in a way it would not be in a
  /// selection grid. It still goes below the first row rather than above it.
  static const int _albumsBeforeAd = 2;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<GalleryController>();
    final lang = context.watch<LocaleProvider>().locale.languageCode;
    final albums = controller.albums;

    if (albums.isEmpty) {
      return Center(
        child: Text(
          DeviceStrings.t(lang, 'gallery_no_albums'),
          style: TextStyle(fontFamily: 'Poppins', fontSize: 12.sp,
            color: Colors.grey.shade500,
          ),
        ),
      );
    }

    final leading = albums.take(_albumsBeforeAd).toList();
    final trailing = albums.skip(_albumsBeforeAd).toList();

    return CustomScrollView(
      slivers: [
        _albumGrid(leading),
        // Only worth a slot when there is content on both sides of it — an ad
        // stranded under two albums with nothing below reads as the end of
        // the screen.
        if (trailing.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(10.sp, 4.sp, 10.sp, 14.sp),
              child: _adManager.nativeWidget(),
            ),
          ),
        _albumGrid(trailing),
        SliverToBoxAdapter(child: SizedBox(height: 20.sp)),
      ],
    );
  }

  Widget _albumGrid(List<PhotoAlbum> albums) {
    return SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: 10.sp, vertical: 10.sp),
      sliver: SliverGrid.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 10.sp,
          mainAxisSpacing: 12.sp,
          childAspectRatio: 0.82,
        ),
        itemCount: albums.length,
        itemBuilder: (context, index) {
          final album = albums[index];
          return AlbumCard(
            album: album,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                settings: const RouteSettings(name: 'GalleryAlbumPhotosScreen'),
                builder: (_) => AlbumPhotosPage(
                  album: album,
                  // Handed over explicitly — the pushed route sits under the
                  // Navigator, not under this subtree's providers, and reusing
                  // the instance keeps the thumbnail cache shared.
                  repository: context.read<GalleryRepository>(),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
