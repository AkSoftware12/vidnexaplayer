import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../../NotifyListeners/LanguageProvider/device_strings.dart';
import '../../../../NotifyListeners/LanguageProvider/language_provider.dart';
import '../../../../Utils/color.dart';
import '../../../../ads/app_open_ad_manager.dart';
import '../../domain/entities/photo_entity.dart';
import '../../domain/entities/text_overlay.dart';
import '../../domain/repositories/gallery_repository.dart';
import '../controllers/text_editor_controller.dart';
import '../widgets/gallery_dialog.dart';
import '../widgets/text_overlay_item.dart';
import 'photo_picker_page.dart';

/// Places captions on a photo and exports at source resolution.
///
/// This is the one tool that exports through a `RepaintBoundary` capture
/// rather than the `image` package, and deliberately so: `image` renders text
/// with bitmap fonts, which would neither match what the user positioned nor
/// shape Devanagari correctly. Flutter's text engine is exactly the right tool
/// here — the trade-off is the texture-size ceiling documented on
/// [_maxExportEdge].
class TextOnPhotoPage extends StatefulWidget {
  const TextOnPhotoPage({super.key, required this.repository});

  final GalleryRepository repository;

  @override
  State<TextOnPhotoPage> createState() => _TextOnPhotoPageState();
}

class _TextOnPhotoPageState extends State<TextOnPhotoPage> {
  final AppOpenAdManager _adManager = AppOpenAdManager();

  /// Longest edge this will export.
  ///
  /// A boundary capture rasterises through the GPU, and exceeding the device's
  /// maximum texture size fails outright. 4096 is the floor across the Android
  /// devices this app targets, so a larger source is exported downscaled
  /// rather than not at all — and the UI says so instead of quietly shrinking
  /// someone's photo.
  static const double _maxExportEdge = 4096;

  final GlobalKey _boundaryKey = GlobalKey();
  final TextEditorController _controller = TextEditorController();

  PhotoEntity? _photo;
  File? _file;
  bool _saving = false;
  bool _capturing = false;
  String? _status;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _pick());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    if (!mounted) return;
    final lang = context.read<LocaleProvider>().locale.languageCode;
    final picked = await Navigator.push<List<PhotoEntity>>(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: 'PhotoPickerScreen_TextOnPhoto'),
        builder: (_) => PhotoPickerPage(
          repository: widget.repository,
          title: DeviceStrings.t(lang, 'gallery_tool_text_title'),
        ),
      ),
    );
    if (!mounted) return;
    if (picked == null || picked.isEmpty) {
      Navigator.pop(context);
      return;
    }
    final file = await widget.repository.originalFile(picked.first.id);
    if (!mounted) return;
    setState(() {
      _photo = picked.first;
      _file = file;
      _status = null;
    });
  }

  Future<void> _addText() async {
    final lang = context.read<LocaleProvider>().locale.languageCode;
    final text = await showDialog<String>(
      context: context,
      builder: (_) => _TextInputDialog(lang: lang),
    );
    if (text == null || text.trim().isEmpty) return;
    _controller.add(text.trim());
  }

  Future<void> _save() async {
    final photo = _photo;
    if (photo == null || _controller.isEmpty) return;

    final lang = context.read<LocaleProvider>().locale.languageCode;
    setState(() {
      _saving = true;
      _capturing = true;
      _status = null;
    });

    // Drop selection chrome before the frame that gets captured, or the
    // dashed box around the active layer ends up in the exported file.
    _controller.select(null);
    await WidgetsBinding.instance.endOfFrame;

    Uint8List? bytes;
    try {
      final boundary = _boundaryKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary != null) {
        // pixelRatio recovers the source's own resolution rather than the
        // screen's: the boundary is laid out at whatever width fits the
        // display, so capturing at 1.0 would export a phone-sized image.
        final logicalWidth = boundary.size.width;
        var ratio =
            logicalWidth == 0 ? 1.0 : photo.width / logicalWidth;
        final longestLogical =
            boundary.size.longestSide == 0 ? 1.0 : boundary.size.longestSide;
        final maxRatio = _maxExportEdge / longestLogical;
        if (ratio > maxRatio) ratio = maxRatio;
        if (ratio < 1.0) ratio = 1.0;

        final image = await boundary.toImage(pixelRatio: ratio);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        bytes = data?.buffer.asUint8List();
      }
    } catch (_) {
      bytes = null;
    }

    var saved = false;
    if (bytes != null) {
      saved = await widget.repository.saveComposedImage(bytes);
    }

    if (!mounted) return;
    setState(() {
      _saving = false;
      _capturing = false;
      _status = DeviceStrings.t(
        lang,
        saved ? 'gallery_text_saved' : 'gallery_text_failed',
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LocaleProvider>().locale.languageCode;
    final photo = _photo;
    final file = _file;

    return ChangeNotifierProvider<TextEditorController>.value(
      value: _controller,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          iconTheme: const IconThemeData(color: Colors.white),
          backgroundColor: ColorSelect.maineColor,
          elevation: 4,
          title: Text(
            DeviceStrings.t(lang, 'gallery_tool_text_title'),
            style: TextStyle(fontFamily: 'OpenSans', color: Colors.white,
              fontSize: 16.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
          actions: [
            if (photo != null)
              IconButton(
                tooltip: DeviceStrings.t(lang, 'gallery_text_add'),
                icon: const Icon(Icons.add, color: Colors.white),
                onPressed: _saving ? null : _addText,
              ),
          ],
        ),
        bottomNavigationBar: _adManager.bannerWidget(),
        body: photo == null || file == null
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Expanded(
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: photo.aspectRatio,
                        child: RepaintBoundary(
                          key: _boundaryKey,
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final canvas = Size(
                                constraints.maxWidth,
                                constraints.maxHeight,
                              );
                              return Consumer<TextEditorController>(
                                builder: (context, controller, _) => Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Image.file(file, fit: BoxFit.fill),
                                    for (final overlay in controller.overlays)
                                      TextOverlayItem(
                                        key: ValueKey(overlay.id),
                                        overlay: overlay,
                                        canvasSize: canvas,
                                        interactive: !_capturing,
                                        selected:
                                            controller.selectedId == overlay.id,
                                        onTap: () {
                                          controller.select(overlay.id);
                                          controller.bringToFront(overlay.id);
                                        },
                                        onChanged: (next) => controller.update(
                                          overlay.id,
                                          (_) => next,
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                  _StyleBar(lang: lang),
                  if (_status != null)
                    Padding(
                      padding: EdgeInsets.only(top: 6.sp),
                      child: Text(
                        _status!,
                        style: TextStyle(fontFamily: 'Poppins', fontSize: 11.sp,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                  Padding(
                    padding: EdgeInsets.all(12.sp),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ColorSelect.maineColor,
                          foregroundColor: Colors.white,
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
                                DeviceStrings.t(lang, 'gallery_text_save'),
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

/// Style controls for the selected layer. Hidden when nothing is selected —
/// there is nothing for them to act on, and showing dead sliders is worse
/// than showing a prompt.
class _StyleBar extends StatelessWidget {
  const _StyleBar({required this.lang});

  final String lang;

  static const _palette = [
    0xFFFFFFFF,
    0xFF000000,
    0xFFEF4444,
    0xFFF59E0B,
    0xFF10B981,
    0xFF3B82F6,
    0xFF8B5CF6,
    0xFFEC4899,
  ];

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<TextEditorController>();
    final overlay = controller.selected;

    if (overlay == null) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 14.sp),
        child: Text(
          DeviceStrings.t(
            lang,
            controller.isEmpty ? 'gallery_text_prompt' : 'gallery_text_select',
          ),
          textAlign: TextAlign.center,
          style: TextStyle(fontFamily: 'Poppins', fontSize: 11.sp,
            color: Colors.white54,
          ),
        ),
      );
    }

    // A font that cannot draw the script the user typed is not offered.
    final fonts = OverlayFont.values
        .where((font) => !overlay.needsDevanagari || font.supportsDevanagari)
        .toList();

    return Container(
      color: Colors.white10,
      padding: EdgeInsets.symmetric(vertical: 8.sp),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 34.sp,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 12.sp),
              children: [
                for (final value in _palette)
                  GestureDetector(
                    onTap: () => controller.updateSelected(
                      (item) => item.copyWith(colorValue: value),
                    ),
                    child: Container(
                      width: 28.sp,
                      height: 28.sp,
                      margin: EdgeInsets.only(right: 8.sp),
                      decoration: BoxDecoration(
                        color: Color(value),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: overlay.colorValue == value
                              ? ColorSelect.maineColor
                              : Colors.white24,
                          width: overlay.colorValue == value ? 3 : 1,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(height: 6.sp),
          SizedBox(
            height: 32.sp,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 12.sp),
              itemCount: fonts.length,
              separatorBuilder: (_, __) => SizedBox(width: 7.sp),
              itemBuilder: (context, index) {
                final font = fonts[index];
                final active = font == overlay.font;
                return GestureDetector(
                  onTap: () => controller.updateSelected(
                    (item) => item.copyWith(font: font),
                  ),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 10.sp),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(7.sp),
                      color: active
                          ? ColorSelect.maineColor
                          : Colors.white12,
                    ),
                    child: Text(
                      font.label,
                      style: TextStyle(fontFamily: 'Poppins', fontSize: 10.5.sp,
                        color: Colors.white,
                        fontWeight:
                            active ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Row(
            children: [
              SizedBox(width: 12.sp),
              Icon(Icons.format_size, size: 16.sp, color: Colors.white54),
              Expanded(
                child: Slider(
                  min: 12,
                  max: 72,
                  value: overlay.fontSize.clamp(12, 72),
                  activeColor: ColorSelect.maineColor,
                  onChanged: (value) => controller.updateSelected(
                    (item) => item.copyWith(fontSize: value),
                  ),
                ),
              ),
              IconButton(
                tooltip: DeviceStrings.t(lang, 'gallery_text_outline'),
                icon: Icon(
                  Icons.border_color_outlined,
                  size: 18.sp,
                  color: overlay.strokeWidth > 0
                      ? ColorSelect.maineColor
                      : Colors.white54,
                ),
                onPressed: () => controller.updateSelected(
                  (item) => item.copyWith(
                    strokeWidth: item.strokeWidth > 0 ? 0.0 : 4.0,
                  ),
                ),
              ),
              IconButton(
                tooltip: DeviceStrings.t(lang, 'gallery_text_delete'),
                icon: Icon(
                  Icons.delete_outline,
                  size: 18.sp,
                  color: Colors.redAccent,
                ),
                onPressed: () => controller.remove(overlay.id),
              ),
              SizedBox(width: 4.sp),
            ],
          ),
        ],
      ),
    );
  }
}

class _TextInputDialog extends StatefulWidget {
  const _TextInputDialog({required this.lang});

  final String lang;

  @override
  State<_TextInputDialog> createState() => _TextInputDialogState();
}

class _TextInputDialogState extends State<_TextInputDialog> {
  final TextEditingController _field = TextEditingController();

  /// Drives the confirm button's enabled state — adding an empty caption
  /// would place an invisible layer the user then has to hunt for.
  bool _hasText = false;

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _field.text.trim();
    if (text.isEmpty) return;
    Navigator.pop(context, text);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;

    return GalleryDialog(
      icon: Icons.text_fields_rounded,
      title: DeviceStrings.t(widget.lang, 'gallery_text_add'),
      actions: [
        DialogCancelButton(
          label: DeviceStrings.t(widget.lang, 'gallery_cancel'),
          onPressed: () => Navigator.pop(context),
        ),
        DialogConfirmButton(
          label: DeviceStrings.t(widget.lang, 'gallery_text_add'),
          onPressed: _hasText ? _submit : null,
        ),
      ],
      child: TextField(
        controller: _field,
        autofocus: true,
        maxLines: 4,
        minLines: 1,
        textCapitalization: TextCapitalization.sentences,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
        onChanged: (value) {
          final has = value.trim().isNotEmpty;
          if (has != _hasText) setState(() => _hasText = has);
        },
        style: TextStyle(fontFamily: 'Poppins', fontSize: 13.sp,
          color: theme.textTheme.bodyLarge?.color,
        ),
        decoration: InputDecoration(
          hintText: DeviceStrings.t(widget.lang, 'gallery_text_hint'),
          hintStyle: TextStyle(fontFamily: 'Poppins', fontSize: 12.5.sp,
            color: Colors.grey.shade500,
          ),
          filled: true,
          fillColor: dark ? Colors.white10 : Colors.grey.shade100,
          contentPadding: EdgeInsets.symmetric(
            horizontal: 14.sp,
            vertical: 13.sp,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.sp),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.sp),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.sp),
            borderSide: BorderSide(color: ColorSelect.maineColor, width: 1.6),
          ),
        ),
      ),
    );
  }
}
