/// One slot in a collage, as a fraction of the canvas.
///
/// Normalised so a template is resolution-independent: the same layout renders
/// at preview size on screen and at full size on export.
class CollageCell {
  const CollageCell(this.left, this.top, this.width, this.height);

  final double left;
  final double top;
  final double width;
  final double height;

  /// Width-to-height ratio of this cell once laid out on a canvas of
  /// [canvasAspect]. A half-width cell on a square canvas is 1:2, not 1:1 —
  /// which is why the canvas has to be part of the calculation.
  double aspectOn(double canvasAspect) =>
      height == 0 ? 1 : (width / height) * canvasAspect;
}

/// A collage layout, stored as data rather than as a widget tree.
///
/// Keeping layouts as plain numbers is what lets the same definition drive the
/// on-screen preview and the full-resolution render in the worker isolate,
/// where no widgets exist.
class CollageTemplate {
  const CollageTemplate({
    required this.id,
    required this.cells,
    this.canvasAspect = 1.0,
  });

  final String id;
  final List<CollageCell> cells;

  /// Canvas width divided by height. 1.0 is square; 0.8 is the 4:5 portrait
  /// most social apps prefer.
  final double canvasAspect;

  int get cellCount => cells.length;

  /// Every curated layout, grouped by how many photos it holds.
  ///
  /// Counts outside this range fall back to [grid], which can lay out any
  /// number — the curated ones exist because an even grid is rarely the best
  /// arrangement for two or three pictures.
  static const List<CollageTemplate> all = [
    // ── 2 ──
    CollageTemplate(
      id: '2-side',
      cells: [
        CollageCell(0, 0, 0.5, 1),
        CollageCell(0.5, 0, 0.5, 1),
      ],
    ),
    CollageTemplate(
      id: '2-stack',
      cells: [
        CollageCell(0, 0, 1, 0.5),
        CollageCell(0, 0.5, 1, 0.5),
      ],
    ),
    // ── 3 ──
    CollageTemplate(
      id: '3-hero-left',
      cells: [
        CollageCell(0, 0, 0.62, 1),
        CollageCell(0.62, 0, 0.38, 0.5),
        CollageCell(0.62, 0.5, 0.38, 0.5),
      ],
    ),
    CollageTemplate(
      id: '3-hero-top',
      cells: [
        CollageCell(0, 0, 1, 0.58),
        CollageCell(0, 0.58, 0.5, 0.42),
        CollageCell(0.5, 0.58, 0.5, 0.42),
      ],
    ),
    CollageTemplate(
      id: '3-columns',
      cells: [
        CollageCell(0, 0, 1 / 3, 1),
        CollageCell(1 / 3, 0, 1 / 3, 1),
        CollageCell(2 / 3, 0, 1 / 3, 1),
      ],
    ),
    // ── 4 ──
    CollageTemplate(
      id: '4-quad',
      cells: [
        CollageCell(0, 0, 0.5, 0.5),
        CollageCell(0.5, 0, 0.5, 0.5),
        CollageCell(0, 0.5, 0.5, 0.5),
        CollageCell(0.5, 0.5, 0.5, 0.5),
      ],
    ),
    CollageTemplate(
      id: '4-hero-left',
      cells: [
        CollageCell(0, 0, 0.6, 1),
        CollageCell(0.6, 0, 0.4, 1 / 3),
        CollageCell(0.6, 1 / 3, 0.4, 1 / 3),
        CollageCell(0.6, 2 / 3, 0.4, 1 / 3),
      ],
    ),
    CollageTemplate(
      id: '4-band',
      cells: [
        CollageCell(0, 0, 1, 0.55),
        CollageCell(0, 0.55, 1 / 3, 0.45),
        CollageCell(1 / 3, 0.55, 1 / 3, 0.45),
        CollageCell(2 / 3, 0.55, 1 / 3, 0.45),
      ],
    ),
    // ── 5 ──
    CollageTemplate(
      id: '5-hero-left',
      cells: [
        CollageCell(0, 0, 0.58, 1),
        CollageCell(0.58, 0, 0.42, 0.25),
        CollageCell(0.58, 0.25, 0.42, 0.25),
        CollageCell(0.58, 0.5, 0.42, 0.25),
        CollageCell(0.58, 0.75, 0.42, 0.25),
      ],
    ),
    CollageTemplate(
      id: '5-two-three',
      cells: [
        CollageCell(0, 0, 0.5, 0.5),
        CollageCell(0.5, 0, 0.5, 0.5),
        CollageCell(0, 0.5, 1 / 3, 0.5),
        CollageCell(1 / 3, 0.5, 1 / 3, 0.5),
        CollageCell(2 / 3, 0.5, 1 / 3, 0.5),
      ],
    ),
    // ── 6 ──
    CollageTemplate(
      id: '6-grid',
      cells: [
        CollageCell(0, 0, 1 / 3, 0.5),
        CollageCell(1 / 3, 0, 1 / 3, 0.5),
        CollageCell(2 / 3, 0, 1 / 3, 0.5),
        CollageCell(0, 0.5, 1 / 3, 0.5),
        CollageCell(1 / 3, 0.5, 1 / 3, 0.5),
        CollageCell(2 / 3, 0.5, 1 / 3, 0.5),
      ],
    ),
    CollageTemplate(
      id: '6-hero-top',
      cells: [
        CollageCell(0, 0, 1, 0.5),
        CollageCell(0, 0.5, 0.5, 0.25),
        CollageCell(0.5, 0.5, 0.5, 0.25),
        CollageCell(0, 0.75, 1 / 3, 0.25),
        CollageCell(1 / 3, 0.75, 1 / 3, 0.25),
        CollageCell(2 / 3, 0.75, 1 / 3, 0.25),
      ],
    ),
  ];

  /// Layouts that hold exactly [count] photos, plus an even grid so there is
  /// always at least one option.
  static List<CollageTemplate> forCount(int count) {
    final curated =
        all.where((template) => template.cellCount == count).toList();
    return [...curated, grid(count)];
  }

  /// An even grid for [count] photos — the fallback, and the option people
  /// reach for when they want the pictures treated equally.
  static CollageTemplate grid(int count) {
    final columns = count <= 1 ? 1 : (count <= 4 ? 2 : (count <= 9 ? 3 : 4));
    final rows = (count / columns).ceil();
    final cells = <CollageCell>[];
    for (var index = 0; index < count; index++) {
      final column = index % columns;
      final row = index ~/ columns;
      cells.add(
        CollageCell(
          column / columns,
          row / rows,
          1 / columns,
          1 / rows,
        ),
      );
    }
    return CollageTemplate(id: 'grid-$count', cells: cells);
  }
}

/// How the user repositioned one photo inside its cell.
///
/// [focusX]/[focusY] are the centre of the crop window in the source photo's
/// own coordinates (0..1), and [zoom] is 1.0 for the largest crop that fills
/// the cell — larger moves in. Resolution-independent for the same reason
/// [CollageCell] is: the preview and the full-size export read the same
/// numbers.
class CollageAdjustment {
  const CollageAdjustment({
    this.focusX = 0.5,
    this.focusY = 0.5,
    this.zoom = 1.0,
  });

  final double focusX;
  final double focusY;
  final double zoom;

  CollageAdjustment copyWith({double? focusX, double? focusY, double? zoom}) =>
      CollageAdjustment(
        focusX: focusX ?? this.focusX,
        focusY: focusY ?? this.focusY,
        zoom: zoom ?? this.zoom,
      );

  /// True while this still describes the plain centred crop, which is what the
  /// editor opens on. Used to decide whether a cell needs to override the
  /// automatic crop at all.
  bool get isNeutral => focusX == 0.5 && focusY == 0.5 && zoom == 1.0;
}
