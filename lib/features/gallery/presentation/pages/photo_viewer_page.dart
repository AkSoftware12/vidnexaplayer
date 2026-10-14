import 'dart:io';
import 'dart:typed_data';

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

  /// File lookups, shared by the pages and the neighbour prefetch so each
  /// photo's file is resolved once. On Android 10+ that lookup copies the
  /// photo into the cache before it can be opened, which for a large photo is
  /// most of the wait — doing it for the next page while this one is on
  /// screen is what makes a swipe land on a ready image.
  final Map<String, Future<File?>> _files = {};

  /// How far from the current page a lookup is kept before it is dropped.
  static const int _keepRadius = 2;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _pageController = PageController(initialPage: _index);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _prefetchAround(_index);
    });
  }

  Future<File?> _fileFor(GalleryController controller, String photoId) =>
      _files.putIfAbsent(photoId, () => controller.originalFile(photoId));

  /// Longest side, in pixels, a page decodes to. Twice the screen leaves room
  /// to zoom; above 4096 a photo costs far more to decode and hold than any
  /// phone screen can show, which is what made 50–200 MP photos crawl in.
  int _decodeCap(BuildContext context) {
    final media = MediaQuery.of(context);
    final screen = media.size.longestSide * media.devicePixelRatio;
    return (screen * 2).clamp(2048, 4096).round();
  }

  /// Resolves the neighbours' files and decodes them into the image cache,
  /// and forgets lookups that have scrolled well out of range.
  void _prefetchAround(int index) {
    final controller = context.read<GalleryController>();
    final photos = controller.photos;
    if (photos.isEmpty) return;

    final keep = <String>{
      for (var i = index - _keepRadius; i <= index + _keepRadius; i++)
        if (i >= 0 && i < photos.length) photos[i].id,
    };
    _files.removeWhere((id, _) => !keep.contains(id));

    final cap = _decodeCap(context);
    for (final neighbour in [index + 1, index - 1]) {
      if (neighbour < 0 || neighbour >= photos.length) continue;
      final id = photos[neighbour].id;
      _fileFor(controller, id).then((file) {
        if (file == null || !mounted) return;
        precacheImage(
          _ViewerImage.providerFor(file, cap),
          context,
          onError: (_, __) {}, // the page shows its own error if it recurs
        );
      });
    }
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
    final decodeCap = _decodeCap(context);

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
        onPageChanged: (index) {
          setState(() => _index = index);
          _prefetchAround(index);
        },
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
              file: _fileFor(controller, photo.id),
              decodeCap: decodeCap,
            ),
          );
        },
      ),
    );
  }
}

/// One full-resolution page.
///
/// Its file lookup is handed in by the page, which resolves each photo once
/// and shares it with the neighbour prefetch. The viewer rebuilds constantly
/// while swiping, and resolving inside `build` — which the old gallery did
/// before it was fixed — re-reads from MediaStore on every frame.
///
/// Until the full image is decoded it shows the grid's thumbnail, which is
/// already in memory, instead of a spinner on black — so a large photo
/// appears at once and sharpens, rather than appearing only when done.
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
    required this.file,
    required this.decodeCap,
  });

  final GalleryController controller;
  final String photoId;
  final Future<File?> file;

  /// Longest side to decode to; see `_PhotoViewerPageState._decodeCap`.
  final int decodeCap;

  /// The provider a page displays — shared with the prefetch so a precached
  /// neighbour is a cache hit, which needs the identical key.
  ///
  /// `fit` inside a square works whichever way round the photo is, and never
  /// upscales, so photos already under the cap decode exactly as before.
  static ImageProvider providerFor(File file, int cap) => ResizeImage(
        FileImage(file),
        width: cap,
        height: cap,
        policy: ResizeImagePolicy.fit,
      );

  @override
  State<_ViewerImage> createState() => _ViewerImageState();
}

class _ViewerImageState extends State<_ViewerImage> {
  late final Future<Uint8List?> _thumbnail;

  @override
  void initState() {
    super.initState();
    // The grid's own size, so this is normally a hit in its thumbnail cache.
    _thumbnail = widget.controller.thumbnail(widget.photoId);
  }

  Widget _placeholder() {
    return FutureBuilder<Uint8List?>(
      future: _thumbnail,
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes == null) {
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
        return Image.memory(
          bytes,
          fit: BoxFit.contain,
          width: double.infinity,
          height: double.infinity,
          gaplessPlayback: true,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LocaleProvider>().locale.languageCode;

    return FutureBuilder<File?>(
      future: widget.file,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _placeholder();
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

        return Image(
          image: _ViewerImage.providerFor(file, widget.decodeCap),
          fit: BoxFit.contain,
          width: double.infinity,
          height: double.infinity,
          gaplessPlayback: true,
          // Thumbnail until the first frame is ready. A precached neighbour
          // arrives synchronously and skips straight to the full image.
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            if (wasSynchronouslyLoaded || frame != null) return child;
            return _placeholder();
          },
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
