import 'package:material_ui/material_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../../../NotifyListeners/LanguageProvider/device_strings.dart';
import '../../../../NotifyListeners/LanguageProvider/language_provider.dart';
import '../../../../Utils/color.dart';
import '../controllers/gallery_controller.dart';

/// Shown instead of the tabs when photo access has been refused.
///
/// The module asks for permission exactly once, at its root; this is the only
/// place that asks again, and only because the user pressed a button saying so.
/// The old gallery re-requested on every screen, which is how you train people
/// to tap "deny" reflexively.
class GalleryPermissionView extends StatelessWidget {
  const GalleryPermissionView({super.key});

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LocaleProvider>().locale.languageCode;
    final controller = context.read<GalleryController>();

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32.sp),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.photo_library_outlined,
              size: 54.sp,
              color: ColorSelect.maineColor,
            ),
            SizedBox(height: 16.sp),
            Text(
              DeviceStrings.t(lang, 'gallery_permission_title'),
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Poppins', fontSize: 15.sp,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).textTheme.titleLarge?.color,
              ),
            ),
            SizedBox(height: 8.sp),
            Text(
              DeviceStrings.t(lang, 'gallery_permission_body'),
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Poppins', fontSize: 12.sp,
                color: Colors.grey.shade500,
              ),
            ),
            SizedBox(height: 20.sp),
            ElevatedButton(
              onPressed: controller.retryPermission,
              style: ElevatedButton.styleFrom(
                backgroundColor: ColorSelect.maineColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  horizontal: 24.sp,
                  vertical: 10.sp,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.sp),
                ),
              ),
              child: Text(
                DeviceStrings.t(lang, 'gallery_permission_grant'),
                style: TextStyle(fontFamily: 'Poppins', fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            SizedBox(height: 6.sp),
            TextButton(
              onPressed: openAppSettings,
              child: Text(
                DeviceStrings.t(lang, 'gallery_permission_settings'),
                style: TextStyle(fontFamily: 'Poppins', fontSize: 12.sp,
                  color: Colors.grey.shade500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Thin banner shown above the grid when the user granted "selected photos
/// only" (Android 14+). The gallery works, it just cannot see everything, and
/// saying so is better than looking broken.
class LimitedAccessBanner extends StatelessWidget {
  const LimitedAccessBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LocaleProvider>().locale.languageCode;

    return Material(
      color: ColorSelect.maineColor.withValues(alpha: 0.10),
      child: InkWell(
        onTap: openAppSettings,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 12.sp, vertical: 8.sp),
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 15.sp,
                color: ColorSelect.maineColor,
              ),
              SizedBox(width: 8.sp),
              Expanded(
                child: Text(
                  DeviceStrings.t(lang, 'gallery_limited_banner'),
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 10.5.sp,
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
