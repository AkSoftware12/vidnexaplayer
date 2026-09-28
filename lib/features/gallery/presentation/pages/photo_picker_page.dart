import 'package:material_ui/material_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../../NotifyListeners/LanguageProvider/device_strings.dart';
import '../../../../NotifyListeners/LanguageProvider/language_provider.dart';
import '../../../../Utils/color.dart';
import '../../../../ads/app_open_ad_manager.dart';
import '../../domain/entities/photo_entity.dart';
import '../../domain/repositories/gallery_repository.dart';
import '../widgets/photo_thumbnail.dart';

/// Multi-select photo picker, shared by the enhance and collage tools.
///
/// Pops with the chosen photos **in tap order**, which matters for the
/// collage: the order someone picks is the order they expect to see, before
/// shape-matching rearranges anything.
class PhotoPickerPage extends StatefulWidget {
  const PhotoPickerPage({
    super.key,
    required this.repository,
    required this.title,
    this.minSelection = 1,
    this.maxSelection = 1,
  });

  final GalleryRepository repository;
  final String title;
  final int minSelection;
  final int maxSelection;

  @override
  State<PhotoPickerPage> createState() => _PhotoPickerPageState();
}

class _PhotoPickerPageState extends State<PhotoPickerPage> {
  final AppOpenAdManager _adManager = AppOpenAdManager();

  List<PhotoEntity> _photos = const [];
  bool _loading = true;

  /// Insertion-ordered, so tap order survives.
  final List<String> _selected = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// First page paints the grid, the rest fills in behind it.
  ///
  /// This used to await `allPhotos()`, which pages the entire library before
  /// returning — on a 5000-photo device that is a spinner for seconds while
  /// the photos that are about to be on screen were ready after the first
  /// page. The grid is scrolled from the top, so page one is all it can show.
  static const _firstPageSize = 120;

  Future<void> _load() async {
    final firstPage = await widget.repository.loadPhotos(
      offset: 0,
      limit: _firstPageSize,
    );
    if (!mounted) return;
    setState(() {
      _photos = firstPage;
      _loading = false;
    });

    // Short of a full page means that was the whole library.
    if (firstPage.length < _firstPageSize) return;

    final all = await widget.repository.allPhotos();
    if (!mounted) return;
    // Selection is held by id, so replacing the list wholesale cannot lose a
    // pick the user made while the rest was loading.
    setState(() => _photos = all);
  }

  void _toggle(String id) {
    setState(() {
      if (_selected.remove(id)) return;
      // Single-pick mode swaps rather than refusing — tapping a different
      // photo when you already picked one obviously means "that one instead".
      if (widget.maxSelection == 1) {
        _selected
          ..clear()
          ..add(id);
        return;
      }
      if (_selected.length < widget.maxSelection) _selected.add(id);
    });
  }

  void _done() {
    final byId = {for (final photo in _photos) photo.id: photo};
    Navigator.pop(
      context,
      [for (final id in _selected) if (byId[id] != null) byId[id]!],
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LocaleProvider>().locale.languageCode;
    final enough = _selected.length >= widget.minSelection;

    return Provider<GalleryRepository>.value(
      value: widget.repository,
      child: Scaffold(
        appBar: AppBar(
          iconTheme: const IconThemeData(color: Colors.white),
          backgroundColor: ColorSelect.maineColor,
          elevation: 4,
          title: Text(
            widget.title,
            style: TextStyle(fontFamily: 'OpenSans', color: Colors.white,
              fontSize: 16.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
          actions: [
            TextButton(
              onPressed: enough ? _done : null,
              child: Text(
                DeviceStrings.t(lang, 'gallery_picker_done'),
                style: TextStyle(fontFamily: 'Poppins', fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: enough ? Colors.white : Colors.white38,
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: _adManager.bannerWidget(),
        body: _loading
            ? Center(
                child: CircularProgressIndicator(color: ColorSelect.maineColor),
              )
            : Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(
                      horizontal: 14.sp,
                      vertical: 8.sp,
                    ),
                    color: ColorSelect.maineColor.withValues(alpha: 0.08),
                    child: Text(
                      widget.maxSelection == 1
                          ? DeviceStrings.t(lang, 'gallery_picker_one')
                          : DeviceStrings.t(lang, 'gallery_picker_range')
                              .replaceAll('{min}', '${widget.minSelection}')
                              .replaceAll('{max}', '${widget.maxSelection}')
                              .replaceAll('{count}', '${_selected.length}'),
                      style: TextStyle(fontFamily: 'Poppins', fontSize: 11.sp,
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                    ),
                  ),
                  Expanded(
                    child: GridView.builder(
                      padding: EdgeInsets.all(3.sp),
                      gridDelegate:
                          SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 3.sp,
                        mainAxisSpacing: 3.sp,
                      ),
                      itemCount: _photos.length,
                      itemBuilder: (context, index) {
                        final photo = _photos[index];
                        final order = _selected.indexOf(photo.id);
                        return GestureDetector(
                          onTap: () => _toggle(photo.id),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(3.sp),
                                child: PhotoThumbnail(
                                  repository: widget.repository,
                                  photoId: photo.id,
                                  pixelSize: 384,
                                ),
                              ),
                              if (order >= 0)
                                Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(3.sp),
                                    border: Border.all(
                                      color: ColorSelect.maineColor,
                                      width: 3,
                                    ),
                                    color: ColorSelect.maineColor
                                        .withValues(alpha: 0.20),
                                  ),
                                ),
                              if (order >= 0)
                                Positioned(
                                  top: 5.sp,
                                  right: 5.sp,
                                  child: Container(
                                    width: 20.sp,
                                    height: 20.sp,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: ColorSelect.maineColor,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      // The number is the pick order, which is
                                      // the order the collage will lay them
                                      // out before shape-matching adjusts it.
                                      '${order + 1}',
                                      style: TextStyle(fontFamily: 'Poppins', fontSize: 10.sp,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
