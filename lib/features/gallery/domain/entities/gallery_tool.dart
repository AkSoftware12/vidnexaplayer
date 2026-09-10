/// Which section of the Tools tab a tool belongs to.
///
/// The split is by what the tool does to the library, not by how it looks:
/// [organise] tools read the whole library and change what is in it,
/// [create] tools take a photo or two and produce a new one. That is also why
/// the two are presented differently — an organise tool has a finding to
/// quote, a create tool does not.
enum GalleryToolGroup { organise, create }

/// The seven tools on the gallery's Tools tab.
///
/// [phase] is the build phase from the module blueprint. A tool whose phase
/// has not shipped yet opens a placeholder naming what it will do instead of
/// sitting there as a dead button — the tab stays honest about what works
/// today. Flip [isReady] as each phase lands.
enum GalleryTool {
  smartSearch('search', 4, GalleryToolGroup.organise),
  duplicateFinder('duplicates', 3, GalleryToolGroup.organise),
  junkCleaner('junk', 3, GalleryToolGroup.organise),
  upscale('upscale', 5, GalleryToolGroup.organise),
  collage('collage', 5, GalleryToolGroup.create),
  textOnPhoto('text', 6, GalleryToolGroup.create),
  filters('filters', 8, GalleryToolGroup.create);

  const GalleryTool(this.slug, this.phase, this.group);

  final String slug;
  final int phase;
  final GalleryToolGroup group;

  String get titleKey => 'gallery_tool_${slug}_title';

  String get subtitleKey => 'gallery_tool_${slug}_sub';

  /// All seven have shipped, so nothing carries a "Soon" badge any more.
  ///
  /// Kept rather than deleted: an eighth tool would start here as false, and
  /// the Tools tab already knows how to present one that is not built yet.
  bool get isReady => true;

  static List<GalleryTool> inGroup(GalleryToolGroup group) =>
      GalleryTool.values.where((tool) => tool.group == group).toList();
}
