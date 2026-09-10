import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../../NotifyListeners/LanguageProvider/device_strings.dart';
import '../../../../NotifyListeners/LanguageProvider/language_provider.dart';
import '../../../../Utils/app_palette.dart';
import '../../../../ads/app_open_ad_manager.dart';
import '../../domain/entities/gallery_tool.dart';
import '../../domain/repositories/gallery_repository.dart';
import '../pages/collage_page.dart';
import '../pages/duplicate_finder_page.dart';
import '../pages/enhance_page.dart';
import '../pages/filters_page.dart';
import '../pages/junk_cleaner_page.dart';
import '../pages/smart_search_page.dart';
import '../pages/text_on_photo_page.dart';
import '../services/gallery_tool_stats.dart';
import 'byte_format.dart';
import 'photo_index_card.dart';

/// The Tools tab: the index hero, then the seven tools in their two groups.
///
/// Organise tools get the two-up grid because each has a finding to show —
/// how many duplicates, how much junk — and a badge needs room the width of a
/// full row would waste. Create tools get plain rows: there is nothing to
/// count until the user has picked a photo.
class ToolsTab extends StatefulWidget {
  const ToolsTab({super.key});

  @override
  State<ToolsTab> createState() => _ToolsTabState();
}

class _ToolsTabState extends State<ToolsTab> {
  final GalleryToolStatsStore _stats = GalleryToolStatsStore.instance;
  final AppOpenAdManager _adManager = AppOpenAdManager();

  /// Photos on the device, for the smart-search badge. A MediaStore count, so
  /// cheap — unlike the duplicate and junk figures, which are quoted from the
  /// last real scan rather than found again here.
  int? _libraryCount;

  @override
  void initState() {
    super.initState();
    _stats.load();
    _loadLibraryCount();
  }

  Future<void> _loadLibraryCount() async {
    final count = await context.read<GalleryRepository>().photoCount();
    if (!mounted) return;
    setState(() => _libraryCount = count);
  }

  @override
  Widget build(BuildContext context) {
    AppPalette.sync(context);
    final lang = context.watch<LocaleProvider>().locale.languageCode;

    final organise = GalleryTool.inGroup(GalleryToolGroup.organise);
    final create = GalleryTool.inGroup(GalleryToolGroup.create);

    return ValueListenableBuilder<GalleryToolStats>(
      valueListenable: _stats.stats,
      builder: (context, stats, _) {
        return ListView(
          padding: EdgeInsets.fromLTRB(14.sp, 14.sp, 14.sp, 20.sp),
          children: [
            const PhotoIndexCard(),
            _SectionLabel(text: DeviceStrings.t(lang, 'gallery_tools_organise')),
            GridView.builder(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 11.sp,
                mainAxisSpacing: 11.sp,
                // A fixed height rather than an aspect ratio: the cards hold
                // three lines of text whose length varies by language, and a
                // ratio would let the tallest translation overflow.
                mainAxisExtent: 136.sp,
              ),
              itemCount: organise.length,
              itemBuilder: (context, index) {
                final tool = organise[index];
                return _ToolGridCard(
                  tool: tool,
                  lang: lang,
                  badge: _badgeFor(tool, lang, stats),
                  onTap: () => _open(context, tool),
                );
              },
            ),
            // Between the two groups, not at the end of the list: the pinned
            // banner already owns the bottom edge, and stacking a second ad
            // right above it would put two on screen at once.
            SizedBox(height: 16.sp),
            _adManager.nativeWidget(),
            _SectionLabel(text: DeviceStrings.t(lang, 'gallery_tools_create')),
            for (final tool in create) ...[
              _ToolRow(
                tool: tool,
                lang: lang,
                onTap: () => _open(context, tool),
              ),
              SizedBox(height: 10.sp),
            ],
          ],
        );
      },
    );
  }

  /// The one-line finding shown on an organise card.
  ///
  /// Null where there is nothing honest to say — a tool that has never run
  /// gets an invitation to run it, never a made-up number.
  ({String text, bool muted})? _badgeFor(
    GalleryTool tool,
    String lang,
    GalleryToolStats stats,
  ) {
    switch (tool) {
      case GalleryTool.smartSearch:
        final count = _libraryCount;
        if (count == null) return null;
        return (
          text: DeviceStrings.t(lang, 'gallery_photos_count')
              .replaceAll('{count}', '$count'),
          muted: false,
        );

      case GalleryTool.duplicateFinder:
        final groups = stats.duplicateGroups;
        if (groups == null) {
          return (text: DeviceStrings.t(lang, 'gallery_tool_never_run'), muted: true);
        }
        if (groups == 0) {
          return (
            text: DeviceStrings.t(lang, 'gallery_tool_no_duplicates'),
            muted: true,
          );
        }
        return (
          text: DeviceStrings.t(lang, 'gallery_tool_groups')
              .replaceAll('{count}', '$groups'),
          muted: false,
        );

      case GalleryTool.junkCleaner:
        final bytes = stats.junkBytes;
        if (bytes == null) {
          return (text: DeviceStrings.t(lang, 'gallery_tool_never_run'), muted: true);
        }
        if (bytes == 0) {
          return (
            text: DeviceStrings.t(lang, 'gallery_tool_nothing_to_clean'),
            muted: true,
          );
        }
        return (
          text: DeviceStrings.t(lang, 'gallery_tool_reclaimable')
              .replaceAll('{size}', formatBytes(bytes)),
          muted: false,
        );

      case GalleryTool.upscale:
        // Not a number but a capability: the pipeline is two cubic 2x passes
        // with a sharpen, so "up to 4x" is what it can actually promise.
        return (text: DeviceStrings.t(lang, 'gallery_tool_up_to_4x'), muted: false);

      case GalleryTool.collage:
      case GalleryTool.textOnPhoto:
      case GalleryTool.filters:
        return null;
    }
  }

  void _open(BuildContext context, GalleryTool tool) {
    // The repository is read here, before the push: a pushed route sits under
    // the Navigator rather than under this subtree's providers, and handing
    // over the same instance keeps the thumbnail cache shared.
    final repository = context.read<GalleryRepository>();
    final navigator = Navigator.of(context);

    // Opening a tool is the one deliberate, low-frequency action on this tab,
    // which makes it the right hook for an interstitial. The manager's own
    // caps decide whether one actually shows — every 4th action, 60s apart, 5
    // a day — and [onContinue] runs either way, so a capped tap is
    // indistinguishable from no ad at all.
    _adManager.showInterstitialIfAllowed(
      onContinue: () => _push(navigator, repository, tool),
    );
  }

  void _push(
    NavigatorState navigator,
    GalleryRepository repository,
    GalleryTool tool,
  ) {
    navigator.push(
      MaterialPageRoute(
        builder: (_) => switch (tool) {
          GalleryTool.smartSearch => SmartSearchPage(repository: repository),
          GalleryTool.duplicateFinder =>
            DuplicateFinderPage(repository: repository),
          GalleryTool.junkCleaner => JunkCleanerPage(repository: repository),
          GalleryTool.upscale => EnhancePage(repository: repository),
          GalleryTool.collage => CollagePage(repository: repository),
          GalleryTool.textOnPhoto => TextOnPhotoPage(repository: repository),
          GalleryTool.filters => FiltersPage(repository: repository),
        },
        settings: RouteSettings(name: _screenName(tool)),
      ),
    );
  }

  /// Firebase ke "Screens" report me har tool alag dikhe — ek hi
  /// 'GalleryToolScreen' se pata nahi chalta ki kaunsa tool chala.
  static String _screenName(GalleryTool tool) => switch (tool) {
        GalleryTool.smartSearch => 'GallerySmartSearchScreen',
        GalleryTool.duplicateFinder => 'GalleryDuplicateFinderScreen',
        GalleryTool.junkCleaner => 'GalleryJunkCleanerScreen',
        GalleryTool.upscale => 'GalleryEnhanceScreen',
        GalleryTool.collage => 'GalleryCollageScreen',
        GalleryTool.textOnPhoto => 'GalleryTextOnPhotoScreen',
        GalleryTool.filters => 'GalleryFiltersScreen',
      };
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(4.sp, 18.sp, 4.sp, 10.sp),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(fontFamily: 'Poppins', fontSize: 10.sp,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
          color: AppPalette.textS,
        ),
      ),
    );
  }
}

/// One organise tool, as a two-up card.
class _ToolGridCard extends StatelessWidget {
  const _ToolGridCard({
    required this.tool,
    required this.lang,
    required this.badge,
    required this.onTap,
  });

  final GalleryTool tool;
  final String lang;
  final ({String text, bool muted})? badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final visual = toolVisual(tool);
    final chip = badge;

    return _ToolSurface(
      radius: 16.sp,
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.all(12.sp),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ToolIcon(visual: visual),
            SizedBox(height: 10.sp),
            Text(
              DeviceStrings.t(lang, tool.titleKey),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontFamily: 'Poppins', fontSize: 12.5.sp,
                fontWeight: FontWeight.w700,
                color: AppPalette.textH,
              ),
            ),
            SizedBox(height: 2.sp),
            Expanded(
              child: Text(
                DeviceStrings.t(lang, tool.subtitleKey),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontFamily: 'Poppins', fontSize: 10.sp,
                  height: 1.3,
                  color: AppPalette.textS,
                ),
              ),
            ),
            if (chip != null)
              _Badge(
                text: chip.text,
                color: chip.muted ? AppPalette.textS : visual.tint,
              ),
          ],
        ),
      ),
    );
  }
}

/// One create tool, as a full-width row.
class _ToolRow extends StatelessWidget {
  const _ToolRow({
    required this.tool,
    required this.lang,
    required this.onTap,
  });

  final GalleryTool tool;
  final String lang;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _ToolSurface(
      radius: 14.sp,
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.all(11.sp),
        child: Row(
          children: [
            _ToolIcon(visual: toolVisual(tool)),
            SizedBox(width: 12.sp),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          DeviceStrings.t(lang, tool.titleKey),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontFamily: 'Poppins', fontSize: 12.5.sp,
                            fontWeight: FontWeight.w700,
                            color: AppPalette.textH,
                          ),
                        ),
                      ),
                      if (!tool.isReady) ...[
                        SizedBox(width: 6.sp),
                        _Badge(
                          text: DeviceStrings.t(lang, 'gallery_tool_soon'),
                          color: AppPalette.textS,
                        ),
                      ],
                    ],
                  ),
                  SizedBox(height: 2.sp),
                  Text(
                    DeviceStrings.t(lang, tool.subtitleKey),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 10.sp,
                      height: 1.3,
                      color: AppPalette.textS,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 6.sp),
            Icon(
              Icons.chevron_right_rounded,
              size: 18.sp,
              color: AppPalette.textS,
            ),
          ],
        ),
      ),
    );
  }
}

/// The card both shapes sit on — one place for the colour, radius and shadow.
class _ToolSurface extends StatelessWidget {
  const _ToolSurface({
    required this.radius,
    required this.onTap,
    required this.child,
  });

  final double radius;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: AppPalette.isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: Material(
        color: AppPalette.card,
        borderRadius: BorderRadius.circular(radius),
        child: InkWell(
          borderRadius: BorderRadius.circular(radius),
          onTap: onTap,
          child: child,
        ),
      ),
    );
  }
}

class _ToolIcon extends StatelessWidget {
  const _ToolIcon({required this.visual});

  final ({IconData icon, Color tint}) visual;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40.sp,
      height: 40.sp,
      decoration: BoxDecoration(
        // A wash of the tool's own colour rather than the colour itself: seven
        // saturated squares in one scroll fight each other for attention.
        color: visual.tint.withValues(alpha: AppPalette.isDark ? 0.22 : 0.12),
        borderRadius: BorderRadius.circular(12.sp),
      ),
      child: Icon(visual.icon, color: visual.tint, size: 20.sp),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 7.sp, vertical: 3.sp),
      decoration: BoxDecoration(
        color: color.withValues(alpha: AppPalette.isDark ? 0.22 : 0.12),
        borderRadius: BorderRadius.circular(7.sp),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontFamily: 'Poppins', fontSize: 9.sp,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

/// Icon and tint for a tool.
///
/// Lives in the presentation layer on purpose — [GalleryTool] is a domain enum
/// and must not import Flutter just to carry an `IconData`. The tint is used
/// for the icon, its washed background and the card's badge, so each tool
/// reads as one colour rather than three.
({IconData icon, Color tint}) toolVisual(GalleryTool tool) {
  return switch (tool) {
    GalleryTool.smartSearch => (
        icon: Icons.manage_search_rounded,
        tint: const Color(0xff2563EB),
      ),
    GalleryTool.duplicateFinder => (
        icon: Icons.copy_all_rounded,
        tint: const Color(0xff7C3AED),
      ),
    GalleryTool.junkCleaner => (
        icon: Icons.cleaning_services_rounded,
        tint: const Color(0xff059669),
      ),
    GalleryTool.upscale => (
        icon: Icons.four_k_rounded,
        tint: const Color(0xffEA8C00),
      ),
    GalleryTool.collage => (
        icon: Icons.dashboard_customize_rounded,
        tint: const Color(0xffDB2777),
      ),
    GalleryTool.textOnPhoto => (
        icon: Icons.text_fields_rounded,
        tint: const Color(0xff4338CA),
      ),
    GalleryTool.filters => (
        icon: Icons.tune_rounded,
        tint: const Color(0xff0891B2),
      ),
  };
}
