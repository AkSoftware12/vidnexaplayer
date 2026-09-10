/// How many columns the photo grid shows.
///
/// Changed by pinching the grid and persisted in `shared_preferences`, so it
/// survives app restarts the way a user expects a zoom level to.
enum GridDensity {
  large(2),
  medium(3),
  small(5);

  const GridDensity(this.columns);

  final int columns;

  /// Thumbnail request size in pixels for this density.
  ///
  /// Denser grids get smaller thumbnails — asking for a 512px thumbnail to
  /// fill a 5-column tile wastes decode time on every scroll and burns cache
  /// bytes that would be better spent holding more tiles.
  int get thumbnailPx => switch (this) {
        GridDensity.large => 512,
        GridDensity.medium => 384,
        GridDensity.small => 256,
      };

  /// Pinching outwards means bigger tiles, which means fewer columns.
  GridDensity get zoomIn => switch (this) {
        GridDensity.small => GridDensity.medium,
        GridDensity.medium => GridDensity.large,
        GridDensity.large => GridDensity.large,
      };

  GridDensity get zoomOut => switch (this) {
        GridDensity.large => GridDensity.medium,
        GridDensity.medium => GridDensity.small,
        GridDensity.small => GridDensity.small,
      };

  static GridDensity fromName(String? name) => GridDensity.values.firstWhere(
        (density) => density.name == name,
        orElse: () => GridDensity.medium,
      );
}
