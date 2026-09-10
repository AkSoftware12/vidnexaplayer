import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../../NotifyListeners/LanguageProvider/device_strings.dart';
import '../../../../NotifyListeners/LanguageProvider/language_provider.dart';
import '../../../../Utils/color.dart';
import '../../../../ads/app_open_ad_manager.dart';
import '../../../../ads/rewarded_unlock.dart';
import '../../../../ads/rewarded_unlock_prompt.dart';
import '../../domain/entities/photo_entity.dart';
import '../../domain/repositories/gallery_repository.dart';
import '../widgets/photo_thumbnail.dart';
import 'photo_picker_page.dart';

/// Enlarges a photo toward 4K and sharpens it.
///
/// The copy is deliberately plain about what this does. It resamples and
/// sharpens; it does not invent detail that was never captured. Showing the
/// exact before and after pixel sizes is the honest version of a "4K" claim.
class EnhancePage extends StatefulWidget {
  const EnhancePage({super.key, required this.repository});

  final GalleryRepository repository;

  @override
  State<EnhancePage> createState() => _EnhancePageState();
}

class _EnhancePageState extends State<EnhancePage> {
  static const _targetLongEdge = 3840;

  final AppOpenAdManager _adManager = AppOpenAdManager();

  PhotoEntity? _photo;
  bool _working = false;
  UpscaleReport? _report;

  Future<void> _pick() async {
    final lang = context.read<LocaleProvider>().locale.languageCode;
    final picked = await Navigator.push<List<PhotoEntity>>(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: 'PhotoPickerScreen_Enhance'),
        builder: (_) => PhotoPickerPage(
          repository: widget.repository,
          title: DeviceStrings.t(lang, 'gallery_tool_upscale_title'),
        ),
      ),
    );
    if (!mounted || picked == null || picked.isEmpty) return;
    setState(() {
      _photo = picked.first;
      _report = null;
    });
  }

  Future<void> _enhance() async {
    final photo = _photo;
    if (photo == null) return;

    // Opt-in rewarded unlock, not a paywall: one ad opens a 30-minute window,
    // declining leaves every other tool untouched, and an empty ad inventory
    // grants the unlock rather than withholding the feature.
    final allowed = await ensureRewardedUnlock(
      context,
      feature: RewardedUnlock.enhance4k,
      titleKey: 'rewarded_enhance_title',
      bodyKey: 'rewarded_enhance_body',
    );
    if (!mounted || !allowed) return;

    setState(() {
      _working = true;
      _report = null;
    });

    final report = await widget.repository.enhancePhoto(
      photo.id,
      targetLongEdge: _targetLongEdge,
    );

    if (!mounted) return;
    setState(() {
      _working = false;
      _report = report;
    });
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LocaleProvider>().locale.languageCode;
    final photo = _photo;

    return Provider<GalleryRepository>.value(
      value: widget.repository,
      child: Scaffold(
        appBar: AppBar(
          iconTheme: const IconThemeData(color: Colors.white),
          backgroundColor: ColorSelect.maineColor,
          elevation: 4,
          title: Text(
            DeviceStrings.t(lang, 'gallery_tool_upscale_title'),
            style: TextStyle(fontFamily: 'OpenSans', color: Colors.white,
              fontSize: 16.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        body: SingleChildScrollView(
          padding: EdgeInsets.all(16.sp),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: GestureDetector(
                  onTap: _working ? null : _pick,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white10
                          : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(12.sp),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: photo == null
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_photo_alternate_outlined,
                                size: 42.sp,
                                color: Colors.grey.shade500,
                              ),
                              SizedBox(height: 10.sp),
                              Text(
                                DeviceStrings.t(lang, 'gallery_pick_photo'),
                                style: TextStyle(fontFamily: 'Poppins', fontSize: 12.sp,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          )
                        : PhotoThumbnail(
                            repository: widget.repository,
                            photoId: photo.id,
                            pixelSize: 768,
                            fit: BoxFit.contain,
                          ),
                  ),
                ),
              ),
              SizedBox(height: 14.sp),
              if (photo != null) ...[
                _SizeLine(
                  photo: photo,
                  targetLongEdge: _targetLongEdge,
                  lang: lang,
                ),
                SizedBox(height: 14.sp),
              ],
              ElevatedButton(
                onPressed: photo == null || _working ? null : _enhance,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ColorSelect.maineColor,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 13.sp),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.sp),
                  ),
                ),
                child: _working
                    ? SizedBox(
                        width: 18.sp,
                        height: 18.sp,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        DeviceStrings.t(lang, 'gallery_enhance_action'),
                        style: TextStyle(fontFamily: 'Poppins', fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
              if (_working) ...[
                SizedBox(height: 10.sp),
                Text(
                  DeviceStrings.t(lang, 'gallery_enhance_working'),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 11.sp,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
              if (_report != null) ...[
                SizedBox(height: 14.sp),
                _ResultCard(report: _report!, lang: lang),
              ],
              SizedBox(height: 16.sp),
              Text(
                DeviceStrings.t(lang, 'gallery_enhance_note'),
                style: TextStyle(fontFamily: 'Poppins', fontSize: 10.5.sp,
                  color: Colors.grey.shade500,
                ),
              ),
              // The native slot lives here rather than pinned to the bottom:
              // this page's only destructive-feeling control is the enhance
              // button above, and an ad below the explanatory note is well
              // clear of it. It is also the only ad on this screen — no
              // banner competes with it.
              SizedBox(height: 18.sp),
              _adManager.nativeWidget(),
            ],
          ),
        ),
      ),
    );
  }
}

class _SizeLine extends StatelessWidget {
  const _SizeLine({
    required this.photo,
    required this.targetLongEdge,
    required this.lang,
  });

  final PhotoEntity photo;
  final int targetLongEdge;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final longEdge =
        photo.width > photo.height ? photo.width : photo.height;
    final scale = longEdge == 0 ? 1.0 : targetLongEdge / longEdge;
    final outWidth = (photo.width * scale).round();
    final outHeight = (photo.height * scale).round();

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.sp, vertical: 10.sp),
      decoration: BoxDecoration(
        color: ColorSelect.maineColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(9.sp),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${photo.width} × ${photo.height}',
            style: TextStyle(fontFamily: 'Poppins', fontSize: 12.sp,
              color: Theme.of(context).textTheme.bodyMedium?.color,
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.sp),
            child: Icon(
              Icons.arrow_forward,
              size: 15.sp,
              color: ColorSelect.maineColor,
            ),
          ),
          Text(
            '$outWidth × $outHeight',
            style: TextStyle(fontFamily: 'Poppins', fontSize: 12.sp,
              fontWeight: FontWeight.w600,
              color: ColorSelect.maineColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.report, required this.lang});

  final UpscaleReport report;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final good = report.saved;
    final message = good
        ? DeviceStrings.t(lang, 'gallery_enhance_saved')
            .replaceAll('{w}', '${report.outputWidth}')
            .replaceAll('{h}', '${report.outputHeight}')
        : DeviceStrings.t(lang, report.failure?.messageKey ?? 'gallery_enhance_failed');

    return Container(
      padding: EdgeInsets.all(12.sp),
      decoration: BoxDecoration(
        color: (good ? Colors.green : Colors.orange).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(9.sp),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            good ? Icons.check_circle_outline : Icons.info_outline,
            size: 18.sp,
            color: good ? Colors.green.shade600 : Colors.orange.shade800,
          ),
          SizedBox(width: 9.sp),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontFamily: 'Poppins', fontSize: 11.5.sp,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
