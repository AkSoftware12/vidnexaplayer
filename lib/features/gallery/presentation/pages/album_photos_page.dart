import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../../NotifyListeners/LanguageProvider/device_strings.dart';
import '../../../../NotifyListeners/LanguageProvider/language_provider.dart';
import '../../../../Utils/color.dart';
import '../../../../ads/app_open_ad_manager.dart';
import '../../domain/entities/photo_album.dart';
import '../../domain/repositories/gallery_repository.dart';
import '../controllers/gallery_controller.dart';
import '../widgets/photo_grid.dart';
import 'gallery_home_page.dart';

/// One album, using the same date-sectioned grid as the Photos tab.
///
/// Takes [repository] explicitly rather than reading it from context: a pushed
/// route is a child of the Navigator, not of the widget that pushed it, so the
/// module's providers are not in scope here. Passing the same instance keeps
/// the thumbnail cache shared with the Photos tab instead of starting a second
/// one for every album the user opens.
class AlbumPhotosPage extends StatefulWidget {
  const AlbumPhotosPage({
    super.key,
    required this.album,
    required this.repository,
  });

  final PhotoAlbum album;
  final GalleryRepository repository;

  @override
  State<AlbumPhotosPage> createState() => _AlbumPhotosPageState();
}

class _AlbumPhotosPageState extends State<AlbumPhotosPage> {
  final AppOpenAdManager _adManager = AppOpenAdManager();

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<GalleryRepository>.value(value: widget.repository),
        ChangeNotifierProvider<GalleryController>(
          create: (_) => GalleryController(
            repository: widget.repository,
            albumId: widget.album.id,
          )..init(),
        ),
      ],
      child: Builder(
        builder: (innerContext) {
          final controller = innerContext.watch<GalleryController>();
          final lang =
              innerContext.watch<LocaleProvider>().locale.languageCode;

          return Scaffold(
            appBar: controller.selectionMode
                ? _AlbumSelectionAppBar(lang: lang)
                : AppBar(
                    iconTheme: const IconThemeData(color: Colors.white),
                    backgroundColor: ColorSelect.maineColor,
                    elevation: 4,
                    title: Text(
                      widget.album.name,
                      style: TextStyle(fontFamily: 'OpenSans', color: Colors.white,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
            body: !controller.ready
                ? Center(
                    child: CircularProgressIndicator(
                      color: ColorSelect.maineColor,
                    ),
                  )
                : controller.isEmpty
                    ? Center(
                        child: Text(
                          DeviceStrings.t(lang, 'gallery_no_photos'),
                          style: TextStyle(fontFamily: 'Poppins', fontSize: 12.sp,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      )
                    : const PhotoGrid(),
            bottomNavigationBar: _adManager.bannerWidget(),
          );
        },
      ),
    );
  }
}

class _AlbumSelectionAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const _AlbumSelectionAppBar({required this.lang});

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
