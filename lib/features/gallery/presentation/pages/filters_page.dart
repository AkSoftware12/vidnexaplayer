import 'dart:async';
import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../../NotifyListeners/LanguageProvider/device_strings.dart';
import '../../../../NotifyListeners/LanguageProvider/language_provider.dart';
import '../../../../Utils/color.dart';
import '../../../../ads/app_open_ad_manager.dart';
import '../../../../ads/rewarded_unlock.dart';
import '../../../../ads/rewarded_unlock_prompt.dart';
import '../../domain/entities/photo_entity.dart';
import '../../domain/entities/photo_filter.dart';
import '../../domain/repositories/gallery_repository.dart';
import 'photo_picker_page.dart';

/// One-tap looks plus manual brightness, contrast, saturation and warmth.
///
/// Everything here runs on the worker isolate. The preview is rendered small
/// so a slider stays responsive, and only the save re-renders at the source's
/// own resolution — the two go through the same recipe, so what you see is
/// what gets written.
class FiltersPage extends StatefulWidget {
  const FiltersPage({super.key, required this.repository});

  final GalleryRepository repository;

  @override
  State<FiltersPage> createState() => _FiltersPageState();
}

class _FiltersPageState extends State<FiltersPage> {
  final AppOpenAdManager _adManager = AppOpenAdManager();

  /// Slider moves arrive far faster than a render finishes. Coalescing them
  /// means the isolate renders the value the finger landed on, not every value
  /// it passed through.
  static const _debounce = Duration(milliseconds: 180);

  PhotoEntity? _photo;
  PhotoFilter _filter = PhotoFilter.original;
  FilterAdjustments _adjustments = FilterAdjustments.none;

  Uint8List? _preview;
  List<Uint8List?> _strip = const [];
  bool _rendering = false;
  bool _saving = false;

  Timer? _debounceTimer;

  /// Guards against a slow render landing after a newer one and overwriting it.
  int _request = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _pick());
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _pick() async {
    if (!mounted) return;
    final lang = context.read<LocaleProvider>().locale.languageCode;
    final picked = await Navigator.push<List<PhotoEntity>>(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: 'PhotoPickerScreen_Filters'),
        builder: (_) => PhotoPickerPage(
          repository: widget.repository,
          title: DeviceStrings.t(lang, 'gallery_tool_filters_title'),
        ),
      ),
    );
    if (!mounted) return;
    if (picked == null || picked.isEmpty) {
      Navigator.pop(context);
      return;
    }

    setState(() {
      _photo = picked.first;
      _filter = PhotoFilter.original;
      _adjustments = FilterAdjustments.none;
      _strip = const [];
    });

    unawaited(_loadStrip());
    await _render();
  }

  Future<void> _loadStrip() async {
    final photo = _photo;
    if (photo == null) return;
    final strip = await widget.repository.filterStrip(photo.id);
    if (!mounted) return;
    setState(() => _strip = strip);
  }

  Future<void> _render() async {
    final photo = _photo;
    if (photo == null) return;

    final request = ++_request;
    setState(() => _rendering = true);

    final bytes = await widget.repository.previewFilter(
      photoId: photo.id,
      filter: _filter,
      adjustments: _adjustments,
    );

    if (!mounted || request != _request) return;
    setState(() {
      _rendering = false;
      _preview = bytes;
    });
  }

  void _scheduleRender() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounce, _render);
  }

  Future<void> _save() async {
    final photo = _photo;
    if (photo == null) return;

    // Its own unlock key, so this window and Enhance-to-4K's are separate:
    // watching an ad here never silently unlocks that tool, or the reverse.
    final allowed = await ensureRewardedUnlock(
      context,
      feature: RewardedUnlock.filters,
      titleKey: 'rewarded_filters_title',
      bodyKey: 'rewarded_filters_body',
    );
    if (!mounted || !allowed) return;

    final lang = context.read<LocaleProvider>().locale.languageCode;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);

    final saved = await widget.repository.saveFilteredPhoto(
      photoId: photo.id,
      filter: _filter,
      adjustments: _adjustments,
    );

    if (!mounted) return;
    setState(() => _saving = false);

    // A SnackBar rather than a line of text wedged between the sliders and the
    // button: at full resolution this takes seconds, and the one-line status
    // that used to sit there was small enough to miss entirely — which reads
    // as the save having silently failed.
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 3),
        backgroundColor:
            saved ? Colors.green.shade700 : Colors.red.shade700,
        content: Row(
          children: [
            Icon(
              saved ? Icons.check_circle_outline : Icons.error_outline,
              color: Colors.white,
              size: 18.sp,
            ),
            SizedBox(width: 10.sp),
            Expanded(
              child: Text(
                DeviceStrings.t(
                  lang,
                  saved ? 'gallery_filter_saved' : 'gallery_filter_failed',
                ),
                style: TextStyle(fontFamily: 'Poppins', fontSize: 11.5.sp,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool get _isDirty =>
      _filter != PhotoFilter.original || !_adjustments.isNeutral;

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LocaleProvider>().locale.languageCode;

    return Provider<GalleryRepository>.value(
      value: widget.repository,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          iconTheme: const IconThemeData(color: Colors.white),
          backgroundColor: ColorSelect.maineColor,
          elevation: 4,
          title: Text(
            DeviceStrings.t(lang, 'gallery_tool_filters_title'),
            style: TextStyle(fontFamily: 'OpenSans', color: Colors.white,
              fontSize: 16.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
          actions: [
            if (_isDirty)
              TextButton(
                onPressed: _saving
                    ? null
                    : () {
                        setState(() {
                          _filter = PhotoFilter.original;
                          _adjustments = FilterAdjustments.none;
                        });
                        _render();
                      },
                child: Text(
                  DeviceStrings.t(lang, 'gallery_filter_reset'),
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 11.5.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
        bottomNavigationBar: _adManager.bannerWidget(),
        body: _photo == null
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Expanded(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (_preview != null)
                          Padding(
                            padding: EdgeInsets.all(10.sp),
                            child: Image.memory(
                              _preview!,
                              gaplessPlayback: true,
                              fit: BoxFit.contain,
                            ),
                          ),
                        if (_rendering)
                          SizedBox(
                            width: 26.sp,
                            height: 26.sp,
                            child: const CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: Colors.white,
                            ),
                          ),
                      ],
                    ),
                  ),
                  _FilterStrip(
                    filters: PhotoFilter.values,
                    thumbs: _strip,
                    selected: _filter,
                    lang: lang,
                    onSelect: (filter) {
                      setState(() {
                        _filter = filter;
                      });
                      _render();
                    },
                  ),
                  _AdjustSliders(
                    adjustments: _adjustments,
                    lang: lang,
                    onChanged: (next) {
                      setState(() {
                        _adjustments = next;
                      });
                      _scheduleRender();
                    },
                  ),
                  Padding(
                    padding: EdgeInsets.all(12.sp),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saving || !_isDirty ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ColorSelect.maineColor,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey.shade700,
                          disabledForegroundColor: Colors.white54,
                          padding: EdgeInsets.symmetric(vertical: 13.sp),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10.sp),
                          ),
                        ),
                        child: _saving
                            ? SizedBox(
                                width: 18.sp,
                                height: 18.sp,
                                child: const CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                DeviceStrings.t(lang, 'gallery_filter_save'),
                                style: TextStyle(fontFamily: 'Poppins', fontSize: 13.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Each look shown on the user's own photo rather than on a stock swatch —
/// the only way to tell whether a filter suits *this* picture.
class _FilterStrip extends StatelessWidget {
  const _FilterStrip({
    required this.filters,
    required this.thumbs,
    required this.selected,
    required this.lang,
    required this.onSelect,
  });

  final List<PhotoFilter> filters;
  final List<Uint8List?> thumbs;
  final PhotoFilter selected;
  final String lang;
  final ValueChanged<PhotoFilter> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 92.sp,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 12.sp),
        itemCount: filters.length,
        separatorBuilder: (_, __) => SizedBox(width: 9.sp),
        itemBuilder: (context, index) {
          final filter = filters[index];
          final active = filter == selected;
          final thumb = index < thumbs.length ? thumbs[index] : null;

          return GestureDetector(
            onTap: () => onSelect(filter),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 58.sp,
                  height: 58.sp,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(9.sp),
                    border: Border.all(
                      color: active
                          ? ColorSelect.maineColor
                          : Colors.white24,
                      width: active ? 2.5 : 1,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: thumb == null
                      ? Container(color: Colors.white10)
                      : Image.memory(
                          thumb,
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                        ),
                ),
                SizedBox(height: 4.sp),
                Text(
                  DeviceStrings.t(lang, filter.labelKey),
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 9.5.sp,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                    color: active ? ColorSelect.maineColor : Colors.white60,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _AdjustSliders extends StatelessWidget {
  const _AdjustSliders({
    required this.adjustments,
    required this.lang,
    required this.onChanged,
  });

  final FilterAdjustments adjustments;
  final String lang;
  final ValueChanged<FilterAdjustments> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12.sp, vertical: 4.sp),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _row(
            Icons.brightness_6_outlined,
            DeviceStrings.t(lang, 'gallery_adjust_brightness'),
            adjustments.brightness,
            (value) => onChanged(adjustments.copyWith(brightness: value)),
          ),
          _row(
            Icons.contrast,
            DeviceStrings.t(lang, 'gallery_adjust_contrast'),
            adjustments.contrast,
            (value) => onChanged(adjustments.copyWith(contrast: value)),
          ),
          _row(
            Icons.water_drop_outlined,
            DeviceStrings.t(lang, 'gallery_adjust_saturation'),
            adjustments.saturation,
            (value) => onChanged(adjustments.copyWith(saturation: value)),
          ),
          _row(
            Icons.wb_sunny_outlined,
            DeviceStrings.t(lang, 'gallery_adjust_warmth'),
            adjustments.warmth,
            (value) => onChanged(adjustments.copyWith(warmth: value)),
          ),
        ],
      ),
    );
  }

  Widget _row(
    IconData icon,
    String label,
    int value,
    ValueChanged<int> onSlide,
  ) {
    return Row(
      children: [
        Icon(icon, size: 15.sp, color: Colors.white54),
        SizedBox(width: 7.sp),
        SizedBox(
          width: 62.sp,
          child: Text(
            label,
            style: TextStyle(fontFamily: 'Poppins', fontSize: 10.sp,
              color: Colors.white60,
            ),
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 2.5.sp,
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            ),
            child: Slider(
              min: -100,
              max: 100,
              value: value.toDouble(),
              activeColor: ColorSelect.maineColor,
              inactiveColor: Colors.white24,
              onChanged: (next) => onSlide(next.round()),
            ),
          ),
        ),
        SizedBox(
          width: 30.sp,
          child: Text(
            '$value',
            textAlign: TextAlign.right,
            style: TextStyle(fontFamily: 'Poppins', fontSize: 10.sp,
              color: Colors.white60,
              // Digits line up as the value changes instead of jittering.
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}
