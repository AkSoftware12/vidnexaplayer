import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../Utils/app_palette.dart';
import '../../../../Utils/color.dart';

/// Photos / Albums / Tools as a segmented pill rather than an underline.
///
/// Still a [TabBar] driving the same [TabController], so swiping the
/// [TabBarView] moves it and nothing else has to know it changed shape — only
/// the indicator is redrawn as a filled pill.
class GallerySegmentedTabs extends StatelessWidget implements PreferredSizeWidget {
  const GallerySegmentedTabs({super.key, required this.labels});

  final List<String> labels;

  @override
  Size get preferredSize => const Size.fromHeight(58);

  @override
  Widget build(BuildContext context) {
    AppPalette.sync(context);
    final accent = ColorSelect.maineColor;

    return Padding(
      padding: EdgeInsets.fromLTRB(14.sp, 2.sp, 14.sp, 10.sp),
      child: Container(
        padding: EdgeInsets.all(4.sp),
        decoration: BoxDecoration(
          color: AppPalette.raised,
          borderRadius: BorderRadius.circular(30.sp),
        ),
        child: TabBar(
          // The pill is the indicator, so the usual chrome around it has to go.
          dividerColor: Colors.transparent,
          indicatorSize: TabBarIndicatorSize.tab,
          splashBorderRadius: BorderRadius.circular(26.sp),
          indicatorPadding: EdgeInsets.zero,
          padding: EdgeInsets.zero,
          indicator: BoxDecoration(
            borderRadius: BorderRadius.circular(26.sp),
            gradient: LinearGradient(
              colors: [accent, Color.alphaBlend(Colors.white24, accent)],
            ),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.35),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          labelColor: Colors.white,
          unselectedLabelColor: AppPalette.textS,
          labelStyle: TextStyle(fontFamily: 'Poppins', fontSize: 11.5.sp,
            fontWeight: FontWeight.w700,
          ),
          unselectedLabelStyle: TextStyle(fontFamily: 'Poppins', fontSize: 11.5.sp,
            fontWeight: FontWeight.w600,
          ),
          tabs: [
            for (final label in labels)
              Tab(height: 34.sp, child: Text(label)),
          ],
        ),
      ),
    );
  }
}

/// The round icon button used by the gallery's app bar.
///
/// A raised circle on the flat page background, which is what separates the
/// bar's actions from the content once the bar itself stops being a coloured
/// block.
class GalleryCircleButton extends StatelessWidget {
  const GalleryCircleButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: AppPalette.card,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(8.sp),
          child: Icon(icon, size: 19.sp, color: AppPalette.textH),
        ),
      ),
    );

    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}
