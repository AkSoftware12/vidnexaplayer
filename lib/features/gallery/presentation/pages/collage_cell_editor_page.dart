import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../../NotifyListeners/LanguageProvider/device_strings.dart';
import '../../../../NotifyListeners/LanguageProvider/language_provider.dart';
import '../../../../Utils/color.dart';
import '../../domain/entities/collage_template.dart';
import '../../domain/entities/photo_entity.dart';
import '../../domain/repositories/gallery_repository.dart';

/// Repositions one photo inside one collage cell.
///
/// The automatic crop keeps the busiest part of the frame, which is right more
/// often than centring but is still a guess — and when it guesses wrong the
/// photo looks cut off with no way to argue. This is the way to argue: drag to
/// move, pinch to zoom, and what you frame here is exactly what the export
/// renders, because both read the same [CollageAdjustment] numbers.
///
/// Pops with the new [CollageAdjustment], or null if the user backed out.
class CollageCellEditorPage extends StatefulWidget {
  const CollageCellEditorPage({
    super.key,
    required this.repository,
    required this.photo,
    required this.cellAspect,
    required this.initial,
  });

  final GalleryRepository repository;
  final PhotoEntity photo;

  /// Width-to-height ratio of the cell this photo has to fill.
  final double cellAspect;

  final CollageAdjustment initial;

  @override
  State<CollageCellEditorPage> createState() => _CollageCellEditorPageState();
}

class _CollageCellEditorPageState extends State<CollageCellEditorPage> {
  /// Big enough to frame accurately, small enough to decode instantly. The
  /// export re-reads the full-resolution original, so this only has to be
  /// good enough to look at.
  static const _previewPx = 1024;

  static const _maxZoom = 4.0;

  Uint8List? _bytes;
  bool _failed = false;

  late double _focusX = widget.initial.focusX;
  late double _focusY = widget.initial.focusY;
  late double _zoom = widget.initial.zoom;

  /// Zoom at the moment the current pinch started, so the gesture scales from
  /// where it began rather than from 1.0 each frame.
  double _zoomAtGestureStart = 1.0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final bytes = await widget.repository.thumbnail(
        widget.photo.id,
        _previewPx,
      );
      if (!mounted) return;
      setState(() {
        _bytes = bytes;
        _failed = bytes == null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _failed = true);
    }
  }

  /// Size of the crop window in normalised source coordinates.
  ///
  /// The window is the largest rectangle of [cellAspect] that fits the photo,
  /// divided by the zoom. Expressed as fractions of the source so it can be
  /// compared directly against [_focusX] / [_focusY].
  Size get _windowFraction {
    final sourceAspect = widget.photo.aspectRatio;
    final aspect = widget.cellAspect;
    double width;
    double height;
    if (sourceAspect > aspect) {
      height = 1;
      width = (aspect / sourceAspect).clamp(0.0, 1.0);
    } else {
      width = 1;
      height = (sourceAspect / aspect).clamp(0.0, 1.0);
    }
    return Size(width / _zoom, height / _zoom);
  }

  /// Keeps the crop window inside the photo. Without this, dragging past an
  /// edge would move the window off the image and the export would clamp it
  /// somewhere the user never saw.
  void _clampFocus() {
    final window = _windowFraction;
    _focusX = _focusX.clamp(window.width / 2, 1 - window.width / 2);
    _focusY = _focusY.clamp(window.height / 2, 1 - window.height / 2);
  }

  void _onScaleStart(ScaleStartDetails details) {
    _zoomAtGestureStart = _zoom;
  }

  void _onScaleUpdate(ScaleUpdateDetails details, Size viewport) {
    setState(() {
      if (details.scale != 1.0) {
        _zoom = (_zoomAtGestureStart * details.scale).clamp(1.0, _maxZoom);
      }

      // A drag of one viewport width moves the focus by exactly one crop
      // window, so the photo tracks the finger at any zoom level.
      final window = _windowFraction;
      if (viewport.width > 0 && viewport.height > 0) {
        _focusX -= details.focalPointDelta.dx / viewport.width * window.width;
        _focusY -= details.focalPointDelta.dy / viewport.height * window.height;
      }
      _clampFocus();
    });
  }

  void _reset() {
    setState(() {
      _focusX = 0.5;
      _focusY = 0.5;
      _zoom = 1.0;
      _clampFocus();
    });
  }

  void _done() {
    Navigator.pop(
      context,
      CollageAdjustment(focusX: _focusX, focusY: _focusY, zoom: _zoom),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LocaleProvider>().locale.languageCode;
    final bytes = _bytes;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: ColorSelect.maineColor,
        elevation: 4,
        title: Text(
          DeviceStrings.t(lang, 'gallery_collage_adjust_title'),
          style: TextStyle(fontFamily: 'OpenSans', color: Colors.white,
            fontSize: 16.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _reset,
            child: Text(
              DeviceStrings.t(lang, 'gallery_collage_adjust_reset'),
              style: TextStyle(fontFamily: 'Poppins', fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          TextButton(
            onPressed: bytes == null ? null : _done,
            child: Text(
              DeviceStrings.t(lang, 'gallery_collage_adjust_done'),
              style: TextStyle(fontFamily: 'Poppins', fontSize: 12.sp,
                fontWeight: FontWeight.w700,
                color: bytes == null ? Colors.white38 : Colors.white,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: bytes == null
                  ? (_failed
                      ? Icon(
                          Icons.image_not_supported_outlined,
                          color: Colors.grey.shade600,
                          size: 32.sp,
                        )
                      : CircularProgressIndicator(
                          color: ColorSelect.maineColor,
                        ))
                  : Padding(
                      padding: EdgeInsets.all(16.sp),
                      child: AspectRatio(
                        aspectRatio: widget.cellAspect,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final viewport = Size(
                              constraints.maxWidth,
                              constraints.maxHeight,
                            );
                            return GestureDetector(
                              onScaleStart: _onScaleStart,
                              onScaleUpdate: (details) =>
                                  _onScaleUpdate(details, viewport),
                              child: ClipRect(
                                child: _CellPreview(
                                  bytes: bytes,
                                  focusX: _focusX,
                                  focusY: _focusY,
                                  window: _windowFraction,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(16.sp, 0, 16.sp, 6.sp),
            child: Row(
              children: [
                Icon(Icons.zoom_out, color: Colors.white70, size: 18.sp),
                Expanded(
                  child: Slider(
                    value: _zoom,
                    min: 1,
                    max: _maxZoom,
                    activeColor: ColorSelect.maineColor,
                    onChanged: bytes == null
                        ? null
                        : (value) => setState(() {
                              _zoom = value;
                              _clampFocus();
                            }),
                  ),
                ),
                Icon(Icons.zoom_in, color: Colors.white70, size: 18.sp),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.only(bottom: 14.sp, left: 16.sp, right: 16.sp),
            child: Text(
              DeviceStrings.t(lang, 'gallery_collage_adjust_hint'),
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Poppins', fontSize: 11.sp,
                color: Colors.white54,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Draws the crop window over [bytes].
///
/// [FractionalTranslation]-style maths rather than an `InteractiveViewer`: the
/// numbers that position the image here are the same `focus` and `window`
/// values the export uses, so the framing cannot drift between what is shown
/// and what is written.
class _CellPreview extends StatelessWidget {
  const _CellPreview({
    required this.bytes,
    required this.focusX,
    required this.focusY,
    required this.window,
  });

  final Uint8List bytes;
  final double focusX;
  final double focusY;
  final Size window;

  @override
  Widget build(BuildContext context) {
    // The image is scaled so the crop window exactly covers the viewport, then
    // shifted so the focus point lands in the middle.
    final scaleX = window.width <= 0 ? 1.0 : 1 / window.width;
    final scaleY = window.height <= 0 ? 1.0 : 1 / window.height;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth * scaleX;
        final height = constraints.maxHeight * scaleY;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: constraints.maxWidth / 2 - focusX * width,
              top: constraints.maxHeight / 2 - focusY * height,
              width: width,
              height: height,
              child: Image.memory(
                bytes,
                fit: BoxFit.fill,
                gaplessPlayback: true,
              ),
            ),
          ],
        );
      },
    );
  }
}
