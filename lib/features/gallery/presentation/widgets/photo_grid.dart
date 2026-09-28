import 'package:material_ui/material_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../NotifyListeners/LanguageProvider/device_strings.dart';
import '../../../../NotifyListeners/LanguageProvider/language_provider.dart';
import '../../../../Utils/color.dart';
import '../../../../ads/app_open_ad_manager.dart';
import '../../domain/entities/photo_entity.dart';
import '../../domain/repositories/gallery_repository.dart';
import '../controllers/gallery_controller.dart';
import '../pages/photo_viewer_page.dart';
import 'photo_thumbnail.dart';
import 'pinch_density_detector.dart';

/// The date-sectioned photo grid: one pinned header plus one grid per calendar
/// day, pinch to change density, and paging as it nears the bottom.
///
/// Sections come pre-grouped from [GalleryController] — building them here
/// would recompute the whole grouping on every scroll frame.
class PhotoGrid extends StatefulWidget {
  const PhotoGrid({super.key});

  @override
  State<PhotoGrid> createState() => _PhotoGridState();
}

class _PhotoGridState extends State<PhotoGrid> {
  /// How close to the bottom to get before asking for the next page. Roughly
  /// two rows of headroom, so the spinner rarely becomes visible.
  static const _loadMoreThreshold = 800.0;

  final ScrollController _scrollController = ScrollController();
  final AppOpenAdManager _adManager = AppOpenAdManager();

  /// Day sections to clear before the first in-feed ad, and the gap between
  /// ads after that.
  ///
  /// The first screenful stays pure content on purpose. An ad above the fold
  /// in a photo grid sits exactly where a thumb is already moving fast, and
  /// AdMob counts the clicks that come out of that against the account, not
  /// the layout.
  static const int _sectionsBeforeFirstAd = 2;
  static const int _sectionsBetweenAds = 4;

  /// Whether an ad band follows the section at [index].
  ///
  /// Between sections, never inside the grid: an ad rendered as a grid cell
  /// occupies a slot the eye has already read as "a photo", and every tap on
  /// it is an accident. A full-width band under a day's photos, with its own
  /// padding and a Sponsored label, is a thing you have to choose to touch.
  bool _showAdAfterSection(int index) {
    if (index < _sectionsBeforeFirstAd) return false;
    return (index - _sectionsBeforeFirstAd) % _sectionsBetweenAds == 0;
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - _loadMoreThreshold) {
      context.read<GalleryController>().loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<GalleryController>();
    final lang = context.watch<LocaleProvider>().locale.languageCode;
    final density = controller.density;
    final headerColor = Theme.of(context).scaffoldBackgroundColor;

    return PinchDensityDetector(
      onZoomIn: controller.zoomIn,
      onZoomOut: controller.zoomOut,
      child: RefreshIndicator(
        color: ColorSelect.maineColor,
        onRefresh: controller.refresh,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            if (controller.sections.isEmpty && !controller.loadingPhotos)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Text(
                    DeviceStrings.t(lang, 'gallery_no_photos'),
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 12.sp,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ),
              ),
            for (var i = 0; i < controller.sections.length; i++) ...[
              SliverMainAxisGroup(
                slivers: [
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _DayHeaderDelegate(
                      label: _dayLabel(controller.sections[i].day, lang),
                      count: controller.sections[i].photos.length,
                      background: headerColor,
                      height: 38.sp,
                    ),
                  ),
                  SliverPadding(
                    padding: EdgeInsets.symmetric(horizontal: 4.sp),
                    sliver: SliverGrid.builder(
                      gridDelegate:
                          SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: density.columns,
                        crossAxisSpacing: 3.sp,
                        mainAxisSpacing: 3.sp,
                      ),
                      itemCount: controller.sections[i].photos.length,
                      itemBuilder: (context, index) => _PhotoTile(
                        photo: controller.sections[i].photos[index],
                        pixelSize: density.thumbnailPx,
                      ),
                    ),
                  ),
                ],
              ),
              if (_showAdAfterSection(i))
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(10.sp, 14.sp, 10.sp, 6.sp),
                    child: _adManager.nativeCompactWidget(),
                  ),
                ),
            ],
            if (controller.loadingPhotos)
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 20.sp),
                  child: Center(
                    child: SizedBox(
                      width: 22.sp,
                      height: 22.sp,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: ColorSelect.maineColor,
                      ),
                    ),
                  ),
                ),
              ),
            SliverToBoxAdapter(child: SizedBox(height: 28.sp)),
          ],
        ),
      ),
    );
  }

  /// "Today" / "Yesterday" for the two days people scan for, a full date
  /// otherwise. Falls back to the locale's own date format rather than forcing
  /// an English one on Hindi.
  String _dayLabel(DateTime day, String lang) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final difference = today.difference(day).inDays;

    if (difference == 0) return DeviceStrings.t(lang, 'gallery_today');
    if (difference == 1) return DeviceStrings.t(lang, 'gallery_yesterday');

    final pattern = day.year == today.year ? 'd MMMM' : 'd MMMM yyyy';
    return DateFormat(pattern, lang).format(day);
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({required this.photo, required this.pixelSize});

  final PhotoEntity photo;
  final int pixelSize;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<GalleryController>();
    final selected = controller.isSelected(photo.id);
    final selecting = controller.selectionMode;

    return GestureDetector(
      onTap: () {
        if (selecting) {
          controller.toggleSelection(photo.id);
        } else {
          _openViewer(context, controller);
        }
      },
      onLongPress: () => controller.startSelection(photo.id),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Insetting the selected tile is what makes selection readable at
          // 5 columns, where a border alone is only a couple of pixels.
          AnimatedPadding(
            duration: const Duration(milliseconds: 120),
            padding: EdgeInsets.all(selected ? 6.sp : 0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(selected ? 6.sp : 3.sp),
              child: Hero(
                tag: photo.id,
                child: PhotoThumbnail(
                  // Read here, outside the Hero's child, and passed in: during
                  // a flight the child is re-mounted in the Navigator overlay,
                  // where this provider is not an ancestor.
                  repository: context.read<GalleryRepository>(),
                  photoId: photo.id,
                  pixelSize: pixelSize,
                ),
              ),
            ),
          ),
          if (selecting)
            Positioned(
              top: 4.sp,
              right: 4.sp,
              child: Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.circle_outlined,
                size: 18.sp,
                color: selected ? ColorSelect.maineColor : Colors.white,
                shadows: const [
                  Shadow(color: Colors.black45, blurRadius: 4),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _openViewer(BuildContext context, GalleryController controller) {
    final index = controller.photos.indexWhere((item) => item.id == photo.id);
    if (index < 0) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: 'GalleryPhotoViewerScreen'),
        builder: (_) => ChangeNotifierProvider<GalleryController>.value(
          value: controller,
          child: PhotoViewerPage(initialIndex: index),
        ),
      ),
    );
  }
}

class _DayHeaderDelegate extends SliverPersistentHeaderDelegate {
  _DayHeaderDelegate({
    required this.label,
    required this.count,
    required this.background,
    required this.height,
  });

  final String label;
  final int count;
  final Color background;
  final double height;

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: background,
      alignment: Alignment.centerLeft,
      padding: EdgeInsets.symmetric(horizontal: 10.sp),
      child: Text(
        label,
        style: TextStyle(fontFamily: 'Poppins', fontSize: 12.sp,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).textTheme.titleMedium?.color,
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _DayHeaderDelegate oldDelegate) =>
      oldDelegate.label != label ||
      oldDelegate.count != count ||
      oldDelegate.background != background ||
      oldDelegate.height != height;
}
