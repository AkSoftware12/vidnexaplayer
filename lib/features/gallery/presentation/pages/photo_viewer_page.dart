import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:provider/provider.dart';

import '../../../../NotifyListeners/LanguageProvider/device_strings.dart';
import '../../../../NotifyListeners/LanguageProvider/language_provider.dart';
import '../../../../Utils/color.dart';
import '../controllers/gallery_controller.dart';
import '../widgets/gallery_dialog.dart';

/// Full-screen viewer: a pinch-zoomable pager over the loaded photos.
///
/// Shares the grid's [GalleryController] rather than taking a copy of the
/// list, so a delete here removes the photo from the grid behind it too.
class PhotoViewerPage extends StatefulWidget {
  const PhotoViewerPage({super.key, required this.initialIndex});

  final int initialIndex;

  @override
  State<PhotoViewerPage> createState() => _PhotoViewerPageState();
}

class _PhotoViewerPageState extends State<PhotoViewerPage> {
  late final PageController _pageController;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _pageController = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _confirmDelete() async {
    final controller = context.read<GalleryController>();
    final lang = context.read<LocaleProvider>().locale.languageCode;
    final photos = controller.photos;
    if (_index >= photos.length) return;

    final photoId = photos[_index].id;

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
          DeviceStrings.t(lang, 'gallery_delete_body_one'),
          style: TextStyle(fontFamily: 'Poppins', fontSize: 12.5.sp, height: 1.45),
        ),
      ),
    );
    if (confirmed != true) return;

    final deleted = await controller.deletePhoto(photoId);
    if (!mounted) return;

    // Zero means the user declined the system consent dialog. That is a
    // normal outcome, not an error — say nothing and leave them where they are.
    if (deleted == 0) return;

    final remaining = controller.photos.length;
    if (remaining == 0) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      _index = _index.clamp(0, remaining - 1);
    });
    _pageController.jumpToPage(_index);
  }

  Future<void> _share() async {
    final controller = context.read<GalleryController>();
    final photos = controller.photos;
    if (_index >= photos.length) return;
    await controller.sharePhotoIds([photos[_index].id]);
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<GalleryController>();
    final lang = context.watch<LocaleProvider>().locale.languageCode;
    final photos = controller.photos;

    if (photos.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: SizedBox.shrink(),
      );
    }

    final position = (_index + 1).clamp(1, photos.length);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        title: Text(
          DeviceStrings.t(lang, 'gallery_viewer_position')
              .replaceAll('{index}', '$position')
              .replaceAll('{total}', '${photos.length}'),
          style: TextStyle(fontFamily: 'OpenSans', color: Colors.white,
            fontSize: 14.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined, color: Colors.white),
            onPressed: _share,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.white),
            onPressed: _confirmDelete,
          ),
        ],
      ),
      body: PhotoViewGallery.builder(
        pageController: _pageController,
        itemCount: photos.length,
        onPageChanged: (index) => setState(() => _index = index),
        backgroundDecoration: const BoxDecoration(color: Colors.black),
        builder: (context, index) {
          final photo = photos[index];
          return PhotoViewGalleryPageOptions.customChild(
            heroAttributes: PhotoViewHeroAttributes(tag: photo.id),
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.covered * 3,
            child: _ViewerImage(
              key: ValueKey(photo.id),
              // Captured from this build, where the provider resolves. The
              // page itself is a hero destination, so its child is re-mounted
              // in the Navigator overlay for the length of the flight and
              // cannot look the controller up for itself.
              controller: controller,
              photoId: photo.id,
            ),
          );
        },
      ),
    );
  }
}

/// One full-resolution page.
///
/// Resolves its file exactly once in `initState`. The viewer rebuilds
/// constantly while swiping, and resolving inside `build` — which the old
/// gallery did before it was fixed — re-reads from MediaStore on every frame.
///
/// [controller] arrives as an argument rather than through the context for the
/// same reason [PhotoThumbnail] takes its repository: `photo_view` wraps this
/// child in a `Hero`, and a hero in flight lives in the Navigator's overlay,
/// above the route that provides the controller.
class _ViewerImage extends StatefulWidget {
  const _ViewerImage({
    super.key,
    required this.controller,
    required this.photoId,
  });

  final GalleryController controller;
  final String photoId;

  @override
  State<_ViewerImage> createState() => _ViewerImageState();
}

class _ViewerImageState extends State<_ViewerImage> {
  late Future<File?> _file;

  @override
  void initState() {
    super.initState();
    _file = widget.controller.originalFile(widget.photoId);
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LocaleProvider>().locale.languageCode;

    return FutureBuilder<File?>(
      future: _file,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: SizedBox(
              width: 24.sp,
              height: 24.sp,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: ColorSelect.maineColor,
              ),
            ),
          );
        }

        final file = snapshot.data;
        if (file == null) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.broken_image_outlined,
                  size: 42.sp,
                  color: Colors.grey.shade600,
                ),
                SizedBox(height: 8.sp),
                Text(
                  DeviceStrings.t(lang, 'gallery_file_unavailable'),
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 12.sp,
                    color: Colors.grey.shade400,
                  ),
                ),
              ],
            ),
          );
        }

        return Image.file(
          file,
          fit: BoxFit.contain,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (_, __, ___) => Center(
            child: Icon(
              Icons.error_outline,
              size: 42.sp,
              color: Colors.red.shade300,
            ),
          ),
        );
      },
    );
  }
}
