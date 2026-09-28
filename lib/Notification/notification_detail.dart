import 'package:material_ui/material_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:videoplayer/Utils/app_palette.dart';
import 'package:videoplayer/Utils/color.dart';

import '../ads/app_open_ad_manager.dart';
import '../NotifyListeners/LanguageProvider/language_provider.dart';
import '../NotifyListeners/LanguageProvider/misc_strings.dart';
import 'notification_model.dart';

/// One notification in full.
///
/// The list only shows a single line of each, so a long announcement is
/// unreadable there by design — this is where the whole thing lives. Body text
/// is selectable because pushes often carry a link or a code someone needs to
/// copy.
class NotificationDetailPage extends StatelessWidget {
  const NotificationDetailPage({super.key, required this.item});

  final AppNotification item;

  @override
  Widget build(BuildContext context) {
    AppPalette.sync(context);
    final lang = context.watch<LocaleProvider>().locale.languageCode;
    final adManager = AppOpenAdManager();

    return Scaffold(
      backgroundColor: AppPalette.surface,
      appBar: AppBar(
        backgroundColor: AppPalette.surface,
        elevation: 0,
        iconTheme: IconThemeData(color: AppPalette.textH),
        title: Text(
          MiscStrings.t(lang, 'notification_title'),
          style: TextStyle(fontFamily: 'Poppins', color: AppPalette.textH,
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.all(16.sp),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42.sp,
                height: 42.sp,
                decoration: BoxDecoration(
                  color: ColorSelect.maineColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(11.sp),
                ),
                child: Icon(
                  Icons.notifications_rounded,
                  size: 21.sp,
                  color: ColorSelect.maineColor,
                ),
              ),
              SizedBox(width: 12.sp),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: TextStyle(fontFamily: 'Poppins', fontSize: 16.sp,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                        color: AppPalette.textH,
                      ),
                    ),
                    SizedBox(height: 4.sp),
                    Text(
                      DateFormat(
                        'd MMM yyyy, HH:mm',
                        lang,
                      ).format(item.receivedDate),
                      style: TextStyle(fontFamily: 'Poppins', fontSize: 10.5.sp,
                        color: AppPalette.textS,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16.sp),
          Divider(color: AppPalette.border, height: 1),
          SizedBox(height: 16.sp),
          if (item.body.trim().isNotEmpty)
            SelectableText(
              item.body,
              style: TextStyle(fontFamily: 'Poppins', fontSize: 13.sp,
                height: 1.6,
                color: AppPalette.textB,
              ),
            ),
          if (item.imageUrl != null && item.imageUrl!.isNotEmpty) ...[
            SizedBox(height: 16.sp),
            ClipRRect(
              borderRadius: BorderRadius.circular(12.sp),
              child: Image.network(
                item.imageUrl!,
                fit: BoxFit.cover,
                // A push image is remote and may well 404 — a broken box beats
                // a red error widget in the middle of the message.
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ],
          SizedBox(height: 24.sp),
        ],
      ),
      bottomNavigationBar: adManager.bannerWidget(),
    );
  }
}
