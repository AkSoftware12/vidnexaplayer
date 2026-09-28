import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../../NotifyListeners/LanguageProvider/device_strings.dart';
import '../../../../NotifyListeners/LanguageProvider/language_provider.dart';
import '../../../../Utils/color.dart';
import '../../../../ads/app_open_ad_manager.dart';
import '../../data/repositories/gallery_repository_impl.dart';
import '../../domain/entities/collage_template.dart';
import '../../domain/entities/photo_entity.dart';
import '../../domain/repositories/gallery_repository.dart';
import 'collage_cell_editor_page.dart';
import 'photo_picker_page.dart';

/// Builds a collage, choosing the layout automatically.
///
/// "Auto" here means two real decisions the user would otherwise make by hand:
/// which layout suits these particular photo shapes, and where to crop each
/// one so the subject survives. Both are computed, both are overridable — the
/// template row lets you take the choice back.
class CollagePage extends StatefulWidget {
  const CollagePage({super.key, required this.repository});

  final GalleryRepository repository;

  @override
  State<CollagePage> createState() => _CollagePageState();
}

class _CollagePageState extends State<CollagePage> {
  final AppOpenAdManager _adManager = AppOpenAdManager();

  /// Preview renders small and fast; the saved file renders large. Same code
  /// path, so what you see is what gets written.
  static const _previewLongEdge = 720;
  static const _exportLongEdge = 2048;

  static const _minPhotos = 2;
  static const _maxPhotos = 6;

  List<PhotoEntity> _photos = const [];
  List<CollageTemplate> _templates = const [];
  CollageTemplate? _template;

  Uint8List? _preview;
  bool _rendering = false;
  bool _saving = false;
  String? _status;

  /// Manual crops, keyed by cell index. Cells absent from this map keep the
  /// automatic crop. Cleared whenever the photos or the template change,
  /// because a cell index means a different slot after either.
  Map<int, CollageAdjustment> _adjustments = {};

  /// Photos in the order the cells hold them — the shape-matched order, not
  /// the pick order. Kept so a tap on a cell knows which photo it opened.
  List<PhotoEntity> _ordered = const [];

  Future<void> _pick() async {
    final lang = context.read<LocaleProvider>().locale.languageCode;
    final picked = await Navigator.push<List<PhotoEntity>>(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: 'PhotoPickerScreen_Collage'),
        builder: (_) => PhotoPickerPage(
          repository: widget.repository,
          title: DeviceStrings.t(lang, 'gallery_tool_collage_title'),
          minSelection: _minPhotos,
          maxSelection: _maxPhotos,
        ),
      ),
    );
    if (!mounted || picked == null || picked.length < _minPhotos) return;

    // Candidates that hold exactly this many photos, best shape match first.
    final options = CollageTemplate.forCount(picked.length)
      ..sort(
        (a, b) => GalleryRepositoryImpl.templateCost(picked, a)
            .compareTo(GalleryRepositoryImpl.templateCost(picked, b)),
      );

    setState(() {
      _photos = picked;
      _templates = options;
      _template = options.first;
      _status = null;
      // A different set of photos means every cell index now points somewhere
      // else, so the old crops describe nothing.
      _adjustments = {};
    });
    await _render();
  }

  Future<void> _render() async {
    final template = _template;
    if (template == null || _photos.isEmpty) return;

    setState(() => _rendering = true);

    // Shape-matched order, so each photo lands in the cell it fits best.
    final ordered = GalleryRepositoryImpl.assignToCells(_photos, template);
    final report = await widget.repository.buildCollage(
      photoIds: ordered.map((photo) => photo.id).toList(),
      template: template,
      canvasLongEdge: _previewLongEdge,
      adjustments: _adjustments,
      save: false,
    );

    if (!mounted) return;
    setState(() {
      _rendering = false;
      _ordered = ordered;
      _preview = report.previewBytes;
    });
  }

  /// Opens the crop editor for whichever cell was tapped.
  ///
  /// [local] is the tap in the preview's own coordinates and [size] the
  /// preview's painted size, so the cell is found by hit-testing the same
  /// normalised rectangles the renderer lays out — no second copy of the
  /// layout to keep in step.
  Future<void> _adjustCellAt(Offset local, Size size) async {
    final template = _template;
    if (template == null || _rendering || _saving) return;
    if (size.width <= 0 || size.height <= 0) return;

    final x = local.dx / size.width;
    final y = local.dy / size.height;

    for (var index = 0; index < template.cells.length; index++) {
      if (index >= _ordered.length) break;
      final cell = template.cells[index];
      final inside = x >= cell.left &&
          x < cell.left + cell.width &&
          y >= cell.top &&
          y < cell.top + cell.height;
      if (!inside) continue;

      final updated = await Navigator.push<CollageAdjustment>(
        context,
        MaterialPageRoute(
          settings: const RouteSettings(name: 'CollageCellEditorScreen'),
          builder: (_) => CollageCellEditorPage(
            repository: widget.repository,
            photo: _ordered[index],
            cellAspect: cell.aspectOn(template.canvasAspect),
            initial: _adjustments[index] ?? const CollageAdjustment(),
          ),
        ),
      );
      if (!mounted || updated == null) return;

      setState(() {
        // Back to neutral means "let the automatic crop have it again", which
        // is what the editor's Reset is for.
        if (updated.isNeutral) {
          _adjustments.remove(index);
        } else {
          _adjustments[index] = updated;
        }
        _status = null;
      });
      await _render();
      return;
    }
  }

  Future<void> _save() async {
    final template = _template;
    if (template == null || _photos.isEmpty) return;

    final lang = context.read<LocaleProvider>().locale.languageCode;
    setState(() {
      _saving = true;
      _status = null;
    });

    final ordered = GalleryRepositoryImpl.assignToCells(_photos, template);
    final report = await widget.repository.buildCollage(
      photoIds: ordered.map((photo) => photo.id).toList(),
      template: template,
      canvasLongEdge: _exportLongEdge,
      adjustments: _adjustments,
    );

    if (!mounted) return;
    setState(() {
      _saving = false;
      _status = DeviceStrings.t(
        lang,
        report.saved ? 'gallery_collage_saved' : 'gallery_collage_failed',
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LocaleProvider>().locale.languageCode;

    return Provider<GalleryRepository>.value(
      value: widget.repository,
      child: Scaffold(
        appBar: AppBar(
          iconTheme: const IconThemeData(color: Colors.white),
          backgroundColor: ColorSelect.maineColor,
          elevation: 4,
          title: Text(
            DeviceStrings.t(lang, 'gallery_tool_collage_title'),
            style: TextStyle(fontFamily: 'OpenSans', color: Colors.white,
              fontSize: 16.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
          actions: [
            if (_photos.isNotEmpty)
              IconButton(
                tooltip: DeviceStrings.t(lang, 'gallery_collage_change'),
                icon: const Icon(Icons.photo_library_outlined,
                    color: Colors.white),
                onPressed: _rendering || _saving ? null : _pick,
              ),
          ],
        ),
        bottomNavigationBar: _adManager.bannerWidget(),
        body: _photos.isEmpty
            ? _EmptyState(lang: lang, onPick: _pick)
            : Column(
                children: [
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.all(14.sp),
                      child: Center(
                        child: _rendering
                            ? CircularProgressIndicator(
                                color: ColorSelect.maineColor,
                              )
                            : _preview == null
                                ? Text(
                                    DeviceStrings.t(
                                      lang,
                                      'gallery_collage_failed',
                                    ),
                                    style: TextStyle(fontFamily: 'Poppins', fontSize: 12.sp,
                                      color: Colors.grey.shade500,
                                    ),
                                  )
                                : _AdjustablePreview(
                                    bytes: _preview!,
                                    onTapCell: _adjustCellAt,
                                  ),
                      ),
                    ),
                  ),
                  _TemplateRow(
                    templates: _templates,
                    selected: _template,
                    busy: _rendering || _saving,
                    onSelect: (template) {
                      setState(() {
                        _template = template;
                        // Cells are re-matched to photos per template, so an
                        // adjustment made for cell 0 of the old layout would
                        // land on a different photo in a different shape.
                        _adjustments = {};
                      });
                      _render();
                    },
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14.sp),
                    child: Text(
                      DeviceStrings.t(lang, 'gallery_collage_adjust_tip'),
                      textAlign: TextAlign.center,
                      style: TextStyle(fontFamily: 'Poppins', fontSize: 10.5.sp,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ),
                  if (_status != null)
                    Padding(
                      padding: EdgeInsets.only(top: 8.sp),
                      child: Text(
                        _status!,
                        style: TextStyle(fontFamily: 'Poppins', fontSize: 11.sp,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  Padding(
                    padding: EdgeInsets.all(14.sp),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed:
                            _rendering || _saving || _preview == null
                                ? null
                                : _save,
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
                                DeviceStrings.t(lang, 'gallery_collage_save'),
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

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.lang, required this.onPick});

  final String lang;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32.sp),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.dashboard_customize_outlined,
              size: 46.sp,
              color: Colors.grey.shade400,
            ),
            SizedBox(height: 12.sp),
            Text(
              DeviceStrings.t(lang, 'gallery_collage_prompt'),
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Poppins', fontSize: 12.5.sp,
                color: Colors.grey.shade600,
              ),
            ),
            SizedBox(height: 16.sp),
            ElevatedButton(
              onPressed: onPick,
              style: ElevatedButton.styleFrom(
                backgroundColor: ColorSelect.maineColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  horizontal: 22.sp,
                  vertical: 11.sp,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9.sp),
                ),
              ),
              child: Text(
                DeviceStrings.t(lang, 'gallery_pick_photos'),
                style: TextStyle(fontFamily: 'Poppins', fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Layout options, best shape match first — the leftmost is what "auto" chose.
class _TemplateRow extends StatelessWidget {
  const _TemplateRow({
    required this.templates,
    required this.selected,
    required this.busy,
    required this.onSelect,
  });

  final List<CollageTemplate> templates;
  final CollageTemplate? selected;
  final bool busy;
  final ValueChanged<CollageTemplate> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 62.sp,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 14.sp),
        itemCount: templates.length,
        separatorBuilder: (_, __) => SizedBox(width: 9.sp),
        itemBuilder: (context, index) {
          final template = templates[index];
          final active = template.id == selected?.id;
          return GestureDetector(
            onTap: busy ? null : () => onSelect(template),
            child: Container(
              width: 52.sp,
              padding: EdgeInsets.all(5.sp),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8.sp),
                border: Border.all(
                  color: active
                      ? ColorSelect.maineColor
                      : Colors.grey.withValues(alpha: 0.4),
                  width: active ? 2 : 1,
                ),
              ),
              child: CustomPaint(
                painter: _TemplatePainter(
                  template: template,
                  color: active
                      ? ColorSelect.maineColor
                      : Colors.grey.shade500,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Draws a template's cells as a thumbnail, straight from the same normalised
/// rectangles the renderer uses — so the chip cannot drift from the output.
class _TemplatePainter extends CustomPainter {
  _TemplatePainter({required this.template, required this.color});

  final CollageTemplate template;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    for (final cell in template.cells) {
      canvas.drawRect(
        Rect.fromLTWH(
          cell.left * size.width + 1,
          cell.top * size.height + 1,
          cell.width * size.width - 2,
          cell.height * size.height - 2,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TemplatePainter oldDelegate) =>
      oldDelegate.template.id != template.id || oldDelegate.color != color;
}

/// The rendered collage, with a tap handler that reports where it landed.
///
/// The rendered bytes are the source of truth for what the collage looks like,
/// so the preview stays an image rather than a widget rebuild of the layout.
/// All this adds is the hit-test: the tap position in the image's own painted
/// box, which the page turns into a cell index using the template it already
/// has.
class _AdjustablePreview extends StatelessWidget {
  const _AdjustablePreview({required this.bytes, required this.onTapCell});

  final Uint8List bytes;
  final void Function(Offset local, Size size) onTapCell;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10.sp),
      child: Builder(
        builder: (context) {
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (details) {
              final box = context.findRenderObject() as RenderBox?;
              if (box == null) return;
              onTapCell(details.localPosition, box.size);
            },
            child: Image.memory(bytes, gaplessPlayback: true),
          );
        },
      ),
    );
  }
}
