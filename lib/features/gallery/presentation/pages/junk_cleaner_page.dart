import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../../NotifyListeners/LanguageProvider/device_strings.dart';
import '../../../../NotifyListeners/LanguageProvider/language_provider.dart';
import '../../../../Utils/color.dart';
import '../../../../ads/app_open_ad_manager.dart';
import '../../domain/entities/junk_bucket.dart';
import '../../domain/repositories/gallery_repository.dart';
import '../controllers/junk_controller.dart';
import '../widgets/byte_format.dart';
import '../widgets/delete_action_bar.dart';
import '../widgets/review_photo_tile.dart';
import '../widgets/signature_status_card.dart';

/// Reviewable categories of photos worth reconsidering.
///
/// Every bucket arrives collapsed and unticked. The screen's job is to show
/// what is there and let someone decide — not to arrive with a number
/// pre-selected for one-tap deletion.
class JunkCleanerPage extends StatefulWidget {
  const JunkCleanerPage({super.key, required this.repository});

  final GalleryRepository repository;

  @override
  State<JunkCleanerPage> createState() => _JunkCleanerPageState();
}

class _JunkCleanerPageState extends State<JunkCleanerPage> {
  final AppOpenAdManager _adManager = AppOpenAdManager();

  late final JunkController _controller =
      JunkController(repository: widget.repository);

  @override
  void initState() {
    super.initState();
    _controller.refresh();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Required by PhotoThumbnail, which resolves the repository from
        // context. Without it every tile here renders as a grey placeholder:
        // the tile swallows the lookup failure the same way it swallows a
        // missing thumbnail, so the screen looks like it loaded and simply
        // found no pictures.
        Provider<GalleryRepository>.value(value: widget.repository),
        ChangeNotifierProvider<JunkController>.value(value: _controller),
      ],
      child: Consumer<JunkController>(
        builder: (context, controller, _) {
          final lang = context.watch<LocaleProvider>().locale.languageCode;

          return Scaffold(
            appBar: AppBar(
              iconTheme: const IconThemeData(color: Colors.white),
              backgroundColor: ColorSelect.maineColor,
              elevation: 4,
              title: Text(
                DeviceStrings.t(lang, 'gallery_tool_junk_title'),
                style: TextStyle(fontFamily: 'OpenSans', color: Colors.white,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            body: controller.loading
                ? Column(
                    children: [
                      Padding(
                        padding: EdgeInsets.all(12.sp),
                        child: const SignatureStatusCard(),
                      ),
                      Expanded(
                        child: Center(
                          child: CircularProgressIndicator(
                            color: ColorSelect.maineColor,
                          ),
                        ),
                      ),
                    ],
                  )
                : controller.buckets.isEmpty
                    ? _NothingFound(lang: lang)
                    : ListView(
                        padding: EdgeInsets.only(bottom: 16.sp),
                        children: [
                          _TotalBar(controller: controller, lang: lang),
                          for (final bucket in controller.buckets)
                            _BucketSection(
                              bucket: bucket,
                              controller: controller,
                              lang: lang,
                            ),
                        ],
                      ),
            // Same rule as the duplicate finder: no ad beneath a Delete
            // button. The action bar takes the slot while a selection exists.
            bottomNavigationBar: controller.hasSelection
                ? DeleteActionBar(controller: controller)
                : _adManager.bannerWidget(),
          );
        },
      ),
    );
  }
}

class _NothingFound extends StatelessWidget {
  const _NothingFound({required this.lang});

  final String lang;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32.sp),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 48.sp,
              color: Colors.green.shade400,
            ),
            SizedBox(height: 12.sp),
            Text(
              DeviceStrings.t(lang, 'gallery_junk_none'),
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Poppins', fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).textTheme.titleMedium?.color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TotalBar extends StatelessWidget {
  const _TotalBar({required this.controller, required this.lang});

  final JunkController controller;
  final String lang;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 14.sp, vertical: 10.sp),
      color: ColorSelect.maineColor.withValues(alpha: 0.08),
      child: Text(
        // Photos are counted once even when they sit in several buckets — see
        // JunkController.totalBytes.
        DeviceStrings.t(lang, 'gallery_junk_summary')
            .replaceAll('{count}', '${controller.totalPhotos}')
            .replaceAll('{size}', formatBytes(controller.totalBytes)),
        style: TextStyle(fontFamily: 'Poppins', fontSize: 11.sp,
          color: Theme.of(context).textTheme.bodyMedium?.color,
        ),
      ),
    );
  }
}

class _BucketSection extends StatelessWidget {
  const _BucketSection({
    required this.bucket,
    required this.controller,
    required this.lang,
  });

  final JunkBucket bucket;
  final JunkController controller;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final expanded = controller.isExpanded(bucket.category);
    final allSelected = controller.isBucketFullySelected(bucket);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => controller.toggleExpanded(bucket.category),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 14.sp, vertical: 12.sp),
            child: Row(
              children: [
                Icon(
                  expanded ? Icons.expand_less : Icons.expand_more,
                  size: 20.sp,
                  color: Colors.grey.shade600,
                ),
                SizedBox(width: 8.sp),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DeviceStrings.t(lang, bucket.category.titleKey),
                        style: TextStyle(fontFamily: 'Poppins', fontSize: 12.5.sp,
                          fontWeight: FontWeight.w600,
                          color:
                              Theme.of(context).textTheme.titleMedium?.color,
                        ),
                      ),
                      Text(
                        DeviceStrings.t(lang, 'gallery_junk_bucket_line')
                            .replaceAll('{count}', '${bucket.count}')
                            .replaceAll(
                              '{size}',
                              formatBytes(bucket.totalBytes),
                            ),
                        style: TextStyle(fontFamily: 'Poppins', fontSize: 10.5.sp,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => controller.toggleBucket(bucket),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 8.sp),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    DeviceStrings.t(
                      lang,
                      allSelected
                          ? 'gallery_junk_deselect_all'
                          : 'gallery_junk_select_all',
                    ),
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 10.5.sp,
                      fontWeight: FontWeight.w600,
                      color: ColorSelect.maineColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (expanded) ...[
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 14.sp),
            child: Text(
              DeviceStrings.t(lang, bucket.category.subtitleKey),
              style: TextStyle(fontFamily: 'Poppins', fontSize: 10.sp,
                color: Colors.grey.shade500,
              ),
            ),
          ),
          SizedBox(height: 10.sp),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: 12.sp),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8.sp,
              mainAxisSpacing: 10.sp,
              childAspectRatio: 0.72,
            ),
            itemCount: bucket.photos.length,
            itemBuilder: (context, index) {
              final photo = bucket.photos[index];
              return ReviewPhotoTile(
                photo: photo,
                sizeBytes: bucket.sizeOf(photo.id),
                selected: controller.isSelected(photo.id),
                onTap: () => controller.toggle(photo.id),
              );
            },
          ),
        ],
        Divider(height: 1, color: Colors.grey.withValues(alpha: 0.25)),
      ],
    );
  }
}
