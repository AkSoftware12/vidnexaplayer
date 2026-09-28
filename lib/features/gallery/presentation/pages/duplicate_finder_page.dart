import 'package:material_ui/material_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../../NotifyListeners/LanguageProvider/device_strings.dart';
import '../../../../NotifyListeners/LanguageProvider/language_provider.dart';
import '../../../../Utils/color.dart';
import '../../../../ads/app_open_ad_manager.dart';
import '../../domain/entities/duplicate_group.dart';
import '../../domain/repositories/gallery_repository.dart';
import '../controllers/duplicate_controller.dart';
import '../widgets/byte_format.dart';
import '../widgets/delete_action_bar.dart';
import '../widgets/review_photo_tile.dart';
import '../widgets/signature_status_card.dart';

/// Groups of photos that are the same picture, largest saving first.
///
/// Takes [repository] explicitly for the same reason the album page does: a
/// pushed route sits under the Navigator, not under the module's providers.
class DuplicateFinderPage extends StatefulWidget {
  const DuplicateFinderPage({super.key, required this.repository});

  final GalleryRepository repository;

  @override
  State<DuplicateFinderPage> createState() => _DuplicateFinderPageState();
}

class _DuplicateFinderPageState extends State<DuplicateFinderPage> {
  final AppOpenAdManager _adManager = AppOpenAdManager();

  late final DuplicateController _controller =
      DuplicateController(repository: widget.repository);

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
        // PhotoThumbnail reads the repository from context — see the same note
        // in JunkCleanerPage. Missing, every tile silently renders grey.
        Provider<GalleryRepository>.value(value: widget.repository),
        ChangeNotifierProvider<DuplicateController>.value(value: _controller),
      ],
      child: Consumer<DuplicateController>(
        builder: (context, controller, _) {
          final lang = context.watch<LocaleProvider>().locale.languageCode;

          return Scaffold(
            appBar: AppBar(
              iconTheme: const IconThemeData(color: Colors.white),
              backgroundColor: ColorSelect.maineColor,
              elevation: 4,
              title: Text(
                DeviceStrings.t(lang, 'gallery_tool_duplicates_title'),
                style: TextStyle(fontFamily: 'OpenSans', color: Colors.white,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
              actions: [
                if (controller.groupCount > 0)
                  TextButton(
                    onPressed: () =>
                        controller.selectAllRedundant(exactOnly: true),
                    child: Text(
                      DeviceStrings.t(lang, 'gallery_dup_select_exact'),
                      style: TextStyle(fontFamily: 'Poppins', fontSize: 11.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
            body: controller.loading
                ? _LoadingView(indexing: controller.indexing, lang: lang)
                : controller.groupCount == 0
                    ? _EmptyView(lang: lang)
                    : Column(
                        children: [
                          _SummaryBar(controller: controller, lang: lang),
                          Expanded(
                            child: ListView.builder(
                              padding: EdgeInsets.only(bottom: 16.sp),
                              itemCount: controller.groupCount,
                              itemBuilder: (context, index) => _GroupCard(
                                group: controller.groups[index],
                                controller: controller,
                                lang: lang,
                              ),
                            ),
                          ),
                        ],
                      ),
            // The banner yields the slot the moment anything is selected. An
            // ad sitting directly under a Delete button is how accidental
            // clicks happen, and this screen deletes files permanently.
            bottomNavigationBar: controller.hasSelection
                ? DeleteActionBar(controller: controller)
                : _adManager.bannerWidget(),
          );
        },
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView({required this.indexing, required this.lang});

  final bool indexing;
  final String lang;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(12.sp),
          child: const SignatureStatusCard(),
        ),
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: ColorSelect.maineColor),
                SizedBox(height: 14.sp),
                Text(
                  DeviceStrings.t(
                    lang,
                    // The first pass over a large library runs for minutes.
                    // Saying which stage it is in is what stops that from
                    // reading as a hang.
                    indexing ? 'gallery_dup_indexing' : 'gallery_dup_scanning',
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 12.sp,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.lang});

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
              DeviceStrings.t(lang, 'gallery_dup_none'),
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

class _SummaryBar extends StatelessWidget {
  const _SummaryBar({required this.controller, required this.lang});

  final DuplicateController controller;
  final String lang;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 14.sp, vertical: 10.sp),
      color: ColorSelect.maineColor.withValues(alpha: 0.08),
      child: Text(
        DeviceStrings.t(lang, 'gallery_dup_summary')
            .replaceAll('{groups}', '${controller.groupCount}')
            .replaceAll('{count}', '${controller.redundantCount}')
            .replaceAll('{size}', formatBytes(controller.reclaimableBytes)),
        style: TextStyle(fontFamily: 'Poppins', fontSize: 11.sp,
          color: Theme.of(context).textTheme.bodyMedium?.color,
        ),
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({
    required this.group,
    required this.controller,
    required this.lang,
  });

  final DuplicateGroup group;
  final DuplicateController controller;
  final String lang;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(12.sp, 12.sp, 12.sp, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 6.sp,
                  vertical: 2.sp,
                ),
                decoration: BoxDecoration(
                  color: group.exact
                      ? Colors.green.withValues(alpha: 0.18)
                      : Colors.orange.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(4.sp),
                ),
                child: Text(
                  DeviceStrings.t(
                    lang,
                    group.exact
                        ? 'gallery_dup_exact'
                        : 'gallery_dup_similar',
                  ),
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 8.5.sp,
                    fontWeight: FontWeight.w600,
                    color: group.exact
                        ? Colors.green.shade700
                        : Colors.orange.shade800,
                  ),
                ),
              ),
              SizedBox(width: 8.sp),
              Expanded(
                child: Text(
                  DeviceStrings.t(lang, 'gallery_dup_group_line')
                      .replaceAll('{count}', '${group.photos.length}')
                      .replaceAll(
                        '{size}',
                        formatBytes(group.reclaimableBytes),
                      ),
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 10.5.sp,
                    color: Colors.grey.shade500,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8.sp),
          SizedBox(
            height: 132.sp,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: group.photos.length,
              separatorBuilder: (_, __) => SizedBox(width: 8.sp),
              itemBuilder: (context, index) {
                final photo = group.photos[index];
                return SizedBox(
                  width: 96.sp,
                  child: ReviewPhotoTile(
                    photo: photo,
                    sizeBytes: group.sizeOf(photo.id),
                    selected: controller.isSelected(photo.id),
                    isKeeper: controller.isKeeper(group, photo.id),
                    keeperLabel: DeviceStrings.t(lang, 'gallery_dup_keep'),
                    onTap: () => controller.toggle(photo.id),
                  ),
                );
              },
            ),
          ),
          SizedBox(height: 10.sp),
          Divider(height: 1, color: Colors.grey.withValues(alpha: 0.25)),
        ],
      ),
    );
  }
}
