import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../../NotifyListeners/LanguageProvider/device_strings.dart';
import '../../../../NotifyListeners/LanguageProvider/language_provider.dart';
import '../../../../Utils/color.dart';
import '../../domain/entities/signature_progress.dart';
import '../../domain/repositories/gallery_repository.dart';
import '../services/gallery_tool_stats.dart';
import '../services/photo_signature_service.dart';

/// The Tools tab's hero: how much of the library is indexed, and a button to
/// index the rest.
///
/// The ring is coverage — signed photos over photos on the device — not the
/// progress of the current pass. That is the number the tools underneath it
/// actually depend on: three of them are only as complete as this ring. Live
/// pass progress moves the same ring while a scan runs, because the two
/// converge on the same figure.
///
/// [SignatureStatusCard] stays as the compact version used inside the
/// duplicate finder and the junk cleaner; this one is the tab's headline.
class PhotoIndexCard extends StatefulWidget {
  const PhotoIndexCard({super.key});

  @override
  State<PhotoIndexCard> createState() => _PhotoIndexCardState();
}

class _PhotoIndexCardState extends State<PhotoIndexCard> {
  final PhotoSignatureService _service = PhotoSignatureService.instance;
  final GalleryToolStatsStore _stats = GalleryToolStatsStore.instance;

  int? _signedCount;

  /// Photos on the device — the ring's denominator. Null until counted, which
  /// is why the ring shows a dash rather than 0% before then.
  int? _libraryCount;

  @override
  void initState() {
    super.initState();
    _stats.load();
    _refresh();
    _service.progress.addListener(_onProgress);
  }

  @override
  void dispose() {
    _service.progress.removeListener(_onProgress);
    super.dispose();
  }

  void _onProgress() {
    // The signed count only moves when a pass finishes, so re-read it then
    // rather than on every batch.
    if (!_service.progress.value.running) _refresh();
  }

  Future<void> _refresh() async {
    final repository = context.read<GalleryRepository>();
    final signed = await _service.signedCount();
    final total = await repository.photoCount();
    if (!mounted) return;
    setState(() {
      _signedCount = signed;
      _libraryCount = total;
    });
  }

  Future<void> _scan() async {
    await _service.ensureSignatures();
    await _stats.recordIndexRun();
    if (!mounted) return;
    await _refresh();
  }

  /// Coverage in 0..1, or null while the denominator is unknown.
  ///
  /// While a pass runs the baseline count is stale by design — it is only
  /// rewritten when the pass ends — so the photos signed so far this run are
  /// added back in to keep the ring moving. Clamped because a re-signed photo
  /// is counted in both halves.
  double? _coverage(SignatureProgress progress) {
    final total = _libraryCount;
    final signed = _signedCount;
    if (total == null || signed == null) return null;
    if (total == 0) return 0;
    final live = progress.running ? progress.done : 0;
    return ((signed + live) / total).clamp(0.0, 1.0);
  }

  String _subtitle(String lang, SignatureProgress progress) {
    if (progress.running && progress.hasWork) {
      return DeviceStrings.t(lang, 'gallery_index_running')
          .replaceAll('{done}', '${progress.done}')
          .replaceAll('{total}', '${progress.total}');
    }

    final indexed = DeviceStrings.t(lang, 'gallery_index_idle')
        .replaceAll('{count}', '${_signedCount ?? 0}');

    final when = _stats.stats.value.indexedAt;
    if (when == null) return indexed;

    final updated = DeviceStrings.t(lang, 'gallery_index_updated')
        .replaceAll('{when}', _relative(lang, when));
    return '$indexed · $updated';
  }

  String _relative(String lang, DateTime when) {
    final diff = DateTime.now().difference(when);
    if (diff.inMinutes < 1) return DeviceStrings.t(lang, 'gallery_time_now');
    if (diff.inMinutes < 60) {
      return DeviceStrings.t(lang, 'gallery_time_minutes')
          .replaceAll('{n}', '${diff.inMinutes}');
    }
    if (diff.inHours < 24) {
      return DeviceStrings.t(lang, 'gallery_time_hours')
          .replaceAll('{n}', '${diff.inHours}');
    }
    return DeviceStrings.t(lang, 'gallery_time_days')
        .replaceAll('{n}', '${diff.inDays}');
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LocaleProvider>().locale.languageCode;
    final accent = ColorSelect.maineColor;

    return ValueListenableBuilder<GalleryToolStats>(
      valueListenable: _stats.stats,
      builder: (context, _, __) {
        return ValueListenableBuilder<SignatureProgress>(
          valueListenable: _service.progress,
          builder: (context, progress, ___) {
            return Container(
              padding: EdgeInsets.fromLTRB(16.sp, 15.sp, 14.sp, 15.sp),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18.sp),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    accent,
                    // A lighter twin of whichever accent is active, rather
                    // than a second hardcoded purple — the accent is a user
                    // setting.
                    Color.alphaBlend(Colors.white24, accent),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.28),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          DeviceStrings.t(lang, 'gallery_index_title'),
                          style: TextStyle(fontFamily: 'Poppins', fontSize: 16.sp,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 3.sp),
                        Text(
                          _subtitle(lang, progress),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontFamily: 'Poppins', fontSize: 10.5.sp,
                            height: 1.35,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                        SizedBox(height: 11.sp),
                        _ScanButton(
                          lang: lang,
                          accent: accent,
                          running: progress.running,
                          onTap: _scan,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 10.sp),
                  _CoverageRing(coverage: _coverage(progress)),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _ScanButton extends StatelessWidget {
  const _ScanButton({
    required this.lang,
    required this.accent,
    required this.running,
    required this.onTap,
  });

  final String lang;
  final Color accent;
  final bool running;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // A scan already in flight has nothing to start, so the pill becomes a
    // status rather than a button that would silently do nothing. It keeps the
    // pill's shape and position: swapping in a bare row instead made the card
    // reflow every time a scan began.
    if (running) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 14.sp, vertical: 7.sp),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(30.sp),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 12.sp,
              height: 12.sp,
              child: CircularProgressIndicator(
                strokeWidth: 1.8.sp,
                color: Colors.white,
              ),
            ),
            SizedBox(width: 8.sp),
            Text(
              DeviceStrings.t(lang, 'gallery_index_scanning'),
              style: TextStyle(fontFamily: 'Poppins', fontSize: 11.5.sp,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(30.sp),
      child: InkWell(
        borderRadius: BorderRadius.circular(30.sp),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.sp, vertical: 7.sp),
          child: Text(
            DeviceStrings.t(lang, 'gallery_index_scan'),
            style: TextStyle(fontFamily: 'Poppins', fontSize: 11.5.sp,
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
        ),
      ),
    );
  }
}

class _CoverageRing extends StatelessWidget {
  const _CoverageRing({required this.coverage});

  /// Null while the library has not been counted yet.
  final double? coverage;

  @override
  Widget build(BuildContext context) {
    final value = coverage;

    return SizedBox(
      width: 62.sp,
      height: 62.sp,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 450),
              curve: Curves.easeOut,
              tween: Tween<double>(begin: 0, end: value ?? 0),
              builder: (context, animated, _) => CircularProgressIndicator(
                value: animated,
                strokeWidth: 5.sp,
                strokeCap: StrokeCap.round,
                backgroundColor: Colors.white.withValues(alpha: 0.25),
                color: Colors.white,
              ),
            ),
          ),
          Text(
            value == null ? '—' : '${(value * 100).round()}%',
            style: TextStyle(fontFamily: 'Poppins', fontSize: 12.5.sp,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
