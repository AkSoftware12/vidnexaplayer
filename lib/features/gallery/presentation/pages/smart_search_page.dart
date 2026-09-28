import 'package:material_ui/material_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../../NotifyListeners/LanguageProvider/device_strings.dart';
import '../../../../NotifyListeners/LanguageProvider/language_provider.dart';
import '../../../../Utils/color.dart';
import '../../../../ads/app_open_ad_manager.dart';
import '../../domain/entities/gallery_query.dart';
import '../../domain/repositories/gallery_repository.dart';
import '../controllers/photo_search_controller.dart';
import '../widgets/photo_thumbnail.dart';

/// Facet search over the photo library.
///
/// Deliberately says what it can do in its own empty state. This finds photos
/// by date, folder, colour, orientation and source — it does not understand
/// "photos of my dog", and a user who types that deserves to be told rather
/// than shown an empty grid.
class SmartSearchPage extends StatefulWidget {
  const SmartSearchPage({super.key, required this.repository});

  final GalleryRepository repository;

  @override
  State<SmartSearchPage> createState() => _SmartSearchPageState();
}

class _SmartSearchPageState extends State<SmartSearchPage> {
  final AppOpenAdManager _adManager = AppOpenAdManager();

  late final PhotoSearchController _controller =
      PhotoSearchController(repository: widget.repository);
  final TextEditingController _field = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    _field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<GalleryRepository>.value(value: widget.repository),
        ChangeNotifierProvider<PhotoSearchController>.value(value: _controller),
      ],
      child: Consumer<PhotoSearchController>(
        builder: (context, controller, _) {
          final lang = context.watch<LocaleProvider>().locale.languageCode;

          return Scaffold(
            appBar: AppBar(
              iconTheme: const IconThemeData(color: Colors.white),
              backgroundColor: ColorSelect.maineColor,
              elevation: 4,
              title: Text(
                DeviceStrings.t(lang, 'gallery_tool_search_title'),
                style: TextStyle(fontFamily: 'OpenSans', color: Colors.white,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            bottomNavigationBar: _adManager.bannerWidget(),
            body: Column(
              children: [
                _SearchField(
                  field: _field,
                  controller: controller,
                  lang: lang,
                ),
                _FacetChips(controller: controller, lang: lang),
                // Above the results, never among them. The result grid is
                // three columns of thumbnails that people tap quickly; an ad
                // sitting in that rhythm collects accidental clicks.
                Padding(
                  padding: EdgeInsets.fromLTRB(12.sp, 4.sp, 12.sp, 8.sp),
                  child: _adManager.nativeCompactWidget(),
                ),
                Expanded(
                  child: _Results(controller: controller, lang: lang),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.field,
    required this.controller,
    required this.lang,
  });

  final TextEditingController field;
  final PhotoSearchController controller;
  final String lang;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(12.sp, 12.sp, 12.sp, 6.sp),
      child: TextField(
        controller: field,
        onChanged: controller.onTextChanged,
        onSubmitted: controller.submit,
        textInputAction: TextInputAction.search,
        style: TextStyle(fontFamily: 'Poppins', fontSize: 13.sp),
        decoration: InputDecoration(
          hintText: controller.listening && controller.partial.isNotEmpty
              ? controller.partial
              : DeviceStrings.t(lang, 'gallery_search_hint'),
          hintStyle: TextStyle(fontFamily: 'Poppins', fontSize: 12.sp,
            color: Colors.grey.shade500,
          ),
          prefixIcon: Icon(Icons.search, size: 20.sp),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (field.text.isNotEmpty)
                IconButton(
                  icon: Icon(Icons.close, size: 18.sp),
                  onPressed: () {
                    field.clear();
                    controller.clear();
                  },
                ),
              IconButton(
                icon: Icon(
                  controller.listening ? Icons.mic : Icons.mic_none,
                  size: 20.sp,
                  color: controller.listening
                      ? Colors.redAccent
                      : ColorSelect.maineColor,
                ),
                onPressed: () async {
                  await controller.toggleMic();
                  // A finished voice result becomes the field's text so it can
                  // be edited rather than only re-spoken.
                  if (controller.rawText != field.text) {
                    field.text = controller.rawText;
                  }
                },
              ),
            ],
          ),
          filled: true,
          fillColor: Theme.of(context).brightness == Brightness.dark
              ? Colors.white10
              : Colors.grey.shade100,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.sp),
            borderSide: BorderSide.none,
          ),
          contentPadding: EdgeInsets.symmetric(vertical: 4.sp),
        ),
      ),
    );
  }
}

/// One chip per recognised facet, each removable.
///
/// This is the screen's honesty mechanism: it shows what the app *understood*
/// from the words, so a query that silently parsed into something unintended
/// is visible rather than mysterious.
class _FacetChips extends StatelessWidget {
  const _FacetChips({required this.controller, required this.lang});

  final PhotoSearchController controller;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final query = controller.query;
    if (query.isEmpty) return const SizedBox.shrink();

    final chips = <Widget>[];

    void add(String label, GalleryQuery reduced) {
      chips.add(
        Padding(
          padding: EdgeInsets.only(right: 6.sp),
          child: InputChip(
            label: Text(
              label,
              style: TextStyle(fontFamily: 'Poppins', fontSize: 10.5.sp),
            ),
            onDeleted: () => controller.removeFacet(reduced),
            deleteIcon: Icon(Icons.close, size: 14.sp),
            backgroundColor: ColorSelect.maineColor.withValues(alpha: 0.10),
            side: BorderSide.none,
            visualDensity: VisualDensity.compact,
          ),
        ),
      );
    }

    if (query.color != null) {
      add(
        DeviceStrings.t(lang, query.color!.labelKey),
        query.without(color: true),
      );
    }
    if (query.orientation != null) {
      add(
        DeviceStrings.t(lang, 'gallery_orientation_${query.orientation!.name}'),
        query.without(orientation: true),
      );
    }
    for (final source in query.sources) {
      add(
        DeviceStrings.t(lang, source.labelKey),
        query.without(source: source),
      );
    }
    if (query.tone != null) {
      add(
        DeviceStrings.t(lang, query.tone!.labelKey),
        query.without(tone: true),
      );
    }
    if (query.fromDate != null || query.toDate != null) {
      add(DeviceStrings.t(lang, 'gallery_facet_date'), query.without(dates: true));
    }
    if (query.minSizeBytes != null || query.maxSizeBytes != null) {
      add(DeviceStrings.t(lang, 'gallery_facet_size'), query.without(sizes: true));
    }
    if (query.folder != null) {
      add(query.folder!, query.without(folder: true));
    }
    if (query.extension != null) {
      add('.${query.extension}', query.without(extension: true));
    }
    if (query.text != null) {
      add('"${query.text}"', query.without(text: true));
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 40.sp,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 12.sp),
        children: chips,
      ),
    );
  }
}

class _Results extends StatelessWidget {
  const _Results({required this.controller, required this.lang});

  final PhotoSearchController controller;
  final String lang;

  @override
  Widget build(BuildContext context) {
    if (controller.searching) {
      return Center(
        child: CircularProgressIndicator(color: ColorSelect.maineColor),
      );
    }

    if (!controller.hasSearched) {
      return _Hint(lang: lang);
    }

    if (controller.results.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 32.sp),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.search_off,
                size: 44.sp,
                color: Colors.grey.shade400,
              ),
              SizedBox(height: 12.sp),
              Text(
                DeviceStrings.t(lang, 'gallery_search_no_results'),
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Poppins', fontSize: 12.5.sp,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).textTheme.titleMedium?.color,
                ),
              ),
              SizedBox(height: 6.sp),
              Text(
                DeviceStrings.t(lang, 'gallery_search_limits'),
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Poppins', fontSize: 10.5.sp,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 14.sp, vertical: 6.sp),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              DeviceStrings.t(lang, 'gallery_search_count')
                  .replaceAll('{count}', '${controller.results.length}'),
              style: TextStyle(fontFamily: 'Poppins', fontSize: 11.sp,
                color: Colors.grey.shade600,
              ),
            ),
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: EdgeInsets.symmetric(horizontal: 4.sp),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 3.sp,
              mainAxisSpacing: 3.sp,
            ),
            itemCount: controller.results.length,
            itemBuilder: (context, index) => ClipRRect(
              borderRadius: BorderRadius.circular(3.sp),
              child: PhotoThumbnail(
                repository: context.read<GalleryRepository>(),
                photoId: controller.results[index].id,
                pixelSize: 384,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Empty state. Lists real example queries rather than a generic prompt —
/// the fastest way to teach what the parser actually understands.
class _Hint extends StatelessWidget {
  const _Hint({required this.lang});

  final String lang;

  @override
  Widget build(BuildContext context) {
    final examples = [
      'gallery_search_eg1',
      'gallery_search_eg2',
      'gallery_search_eg3',
      'gallery_search_eg4',
    ];

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 26.sp, vertical: 20.sp),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DeviceStrings.t(lang, 'gallery_search_try'),
            style: TextStyle(fontFamily: 'Poppins', fontSize: 11.5.sp,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          SizedBox(height: 10.sp),
          for (final key in examples)
            Padding(
              padding: EdgeInsets.only(bottom: 8.sp),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '·  ',
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 12.sp,
                      color: ColorSelect.maineColor,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      DeviceStrings.t(lang, key),
                      style: TextStyle(fontFamily: 'Poppins', fontSize: 12.sp,
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          SizedBox(height: 8.sp),
          Text(
            DeviceStrings.t(lang, 'gallery_search_limits'),
            style: TextStyle(fontFamily: 'Poppins', fontSize: 10.5.sp,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }
}
