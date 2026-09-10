import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:videoplayer/Utils/app_palette.dart';
import 'package:videoplayer/Utils/color.dart';

import '../ads/app_open_ad_manager.dart';
import '../NotifyListeners/LanguageProvider/language_provider.dart';
import '../NotifyListeners/LanguageProvider/misc_strings.dart';
import 'notification_detail.dart';
import 'notification_model.dart';
import 'notification_store.dart';

/// The delivered push notifications, newest first.
///
/// Unread ones carry a NEW badge. Opening this screen is what marks them read,
/// which starts a 24-hour clock — after that they drop off the list on their
/// own (see [NotificationStore.load]). Unread entries never expire, so nothing
/// disappears before the user has had a chance to see it.
class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  // Singleton — initialised once in main.dart, never disposed by a screen.
  final appOpenManager = AppOpenAdManager();

  List<AppNotification> _items = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await NotificationStore.instance.load();
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });

    // Marked read *after* the list is on screen, so the NEW badges are
    // actually visible during this visit and gone on the next one.
    await NotificationStore.instance.markAllRead();
  }

  Future<void> _delete(AppNotification item) async {
    await NotificationStore.instance.remove(item.id);
    if (!mounted) return;
    setState(() {
      _items = _items.where((entry) => entry.id != item.id).toList();
    });
  }

  Future<void> _clearAll() async {
    await NotificationStore.instance.clear();
    if (!mounted) return;
    setState(() => _items = const []);
  }

  @override
  Widget build(BuildContext context) {
    AppPalette.sync(context);
    final lang = context.watch<LocaleProvider>().locale.languageCode;

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
        actions: [
          if (_items.isNotEmpty)
            TextButton(
              onPressed: _clearAll,
              child: Text(
                MiscStrings.t(lang, 'notification_clear_all'),
                style: TextStyle(fontFamily: 'Poppins', fontSize: 11.5.sp,
                  fontWeight: FontWeight.w600,
                  color: ColorSelect.maineColor,
                ),
              ),
            ),
        ],
      ),
      body:
          _loading
              ? Center(
                child: CircularProgressIndicator(color: ColorSelect.maineColor),
              )
              : _items.isEmpty
              ? _EmptyState(lang: lang)
              : RefreshIndicator(
                color: ColorSelect.maineColor,
                onRefresh: _load,
                child: ListView.separated(
                  padding: EdgeInsets.all(12.sp),
                  itemCount: _items.length,
                  separatorBuilder: (_, __) => SizedBox(height: 9.sp),
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    return Dismissible(
                      key: ValueKey(item.id),
                      direction: DismissDirection.endToStart,
                      onDismissed: (_) => _delete(item),
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: EdgeInsets.only(right: 18.sp),
                        decoration: BoxDecoration(
                          color: Colors.red.shade600,
                          borderRadius: BorderRadius.circular(12.sp),
                        ),
                        child: Icon(
                          Icons.delete_outline,
                          color: Colors.white,
                          size: 20.sp,
                        ),
                      ),
                      child: _NotificationCard(
                        item: item,
                        lang: lang,
                        onTap:
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                settings: const RouteSettings(name: 'NotificationDetailScreen'),
                                builder:
                                    (_) => NotificationDetailPage(item: item),
                              ),
                            ),
                      ),
                    );
                  },
                ),
              ),
      bottomNavigationBar: appOpenManager.bannerWidget(),
    );
  }
}

/// A one-line summary. The full text lives on [NotificationDetailPage].
///
/// Both title and body are clamped to a single line: a push body can run to
/// several sentences, and letting them expand here turns the list into a wall
/// of text where nothing is scannable.
class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.item,
    required this.lang,
    required this.onTap,
  });

  final AppNotification item;
  final String lang;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    AppPalette.sync(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.sp),
      child: Container(
        padding: EdgeInsets.all(13.sp),
        decoration: BoxDecoration(
          color: AppPalette.card,
          borderRadius: BorderRadius.circular(12.sp),
          // An unread entry gets an accent edge as well as the badge — the
          // colour is what you notice scanning the list, the badge is what
          // explains it.
          border: Border.all(
            color:
                item.isUnread
                    ? ColorSelect.maineColor.withValues(alpha: 0.55)
                    : AppPalette.border,
            width: item.isUnread ? 1.4 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38.sp,
              height: 38.sp,
              decoration: BoxDecoration(
                color: ColorSelect.maineColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10.sp),
              ),
              child: Icon(
                Icons.notifications_rounded,
                size: 19.sp,
                color: ColorSelect.maineColor,
              ),
            ),
            SizedBox(width: 11.sp),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontFamily: 'Poppins', fontSize: 12.5.sp,
                            fontWeight: FontWeight.w600,
                            color: AppPalette.textH,
                          ),
                        ),
                      ),
                      if (item.isUnread) ...[
                        SizedBox(width: 6.sp),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 6.sp,
                            vertical: 2.sp,
                          ),
                          decoration: BoxDecoration(
                            color: ColorSelect.maineColor,
                            borderRadius: BorderRadius.circular(4.sp),
                          ),
                          child: Text(
                            MiscStrings.t(lang, 'notification_new'),
                            style: TextStyle(fontFamily: 'Poppins', fontSize: 8.5.sp,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (item.body.trim().isNotEmpty) ...[
                    SizedBox(height: 3.sp),
                    Text(
                      item.body,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontFamily: 'Poppins', fontSize: 11.sp,
                        height: 1.4,
                        color: AppPalette.textB,
                      ),
                    ),
                  ],
                  SizedBox(height: 6.sp),
                  Text(
                    _relativeTime(item.receivedDate, lang),
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 9.5.sp,
                      color: AppPalette.textS,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 18.sp, color: AppPalette.textS),
          ],
        ),
      ),
    );
  }

  /// "Just now" / "5m" / "3h" for anything recent, a real date beyond a day —
  /// the list only keeps things for about 24 hours after they are read, so
  /// relative time is the useful form nearly always.
  String _relativeTime(DateTime when, String lang) {
    final diff = DateTime.now().difference(when);
    if (diff.inMinutes < 1) return MiscStrings.t(lang, 'notification_just_now');
    if (diff.inMinutes < 60) {
      return MiscStrings.t(
        lang,
        'notification_minutes_ago',
      ).replaceAll('{n}', '${diff.inMinutes}');
    }
    if (diff.inHours < 24) {
      return MiscStrings.t(
        lang,
        'notification_hours_ago',
      ).replaceAll('{n}', '${diff.inHours}');
    }
    return DateFormat('d MMM, HH:mm', lang).format(when);
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.lang});

  final String lang;

  @override
  Widget build(BuildContext context) {
    AppPalette.sync(context);

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 30.sp),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(20.sp),
              decoration: BoxDecoration(
                color: AppPalette.raised,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.notifications,
                size: 42.sp,
                color: ColorSelect.maineColor,
              ),
            ),
            SizedBox(height: 18.sp),
            Text(
              MiscStrings.t(lang, 'notification_empty_title'),
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Poppins', fontSize: 16.sp,
                fontWeight: FontWeight.w700,
                color: AppPalette.textH,
              ),
            ),
            SizedBox(height: 8.sp),
            Text(
              MiscStrings.t(lang, 'notification_empty_subtitle'),
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Poppins', fontSize: 12.sp,
                color: AppPalette.textS,
              ),
            ),
            SizedBox(height: 22.sp),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: ColorSelect.maineColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  horizontal: 26.sp,
                  vertical: 12.sp,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.sp),
                ),
              ),
              child: Text(
                MiscStrings.t(lang, 'go_back'),
                style: TextStyle(fontFamily: 'Poppins', fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
