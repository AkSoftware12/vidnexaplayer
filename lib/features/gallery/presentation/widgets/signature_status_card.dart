import 'package:material_ui/material_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../../NotifyListeners/LanguageProvider/device_strings.dart';
import '../../../../NotifyListeners/LanguageProvider/language_provider.dart';
import '../../../../Utils/color.dart';
import '../../domain/entities/signature_progress.dart';
import '../services/photo_signature_service.dart';

/// Status of the photo signature index, shown above the tools that depend on
/// it.
///
/// A first pass over a large library runs for minutes, and three of the six
/// tools are useless until it finishes. Showing the count and live progress is
/// what stops that from looking like the tools are broken.
class SignatureStatusCard extends StatefulWidget {
  const SignatureStatusCard({super.key});

  @override
  State<SignatureStatusCard> createState() => _SignatureStatusCardState();
}

class _SignatureStatusCardState extends State<SignatureStatusCard> {
  final PhotoSignatureService _service = PhotoSignatureService.instance;

  int? _signedCount;

  @override
  void initState() {
    super.initState();
    _refreshCount();
    _service.progress.addListener(_onProgress);
  }

  @override
  void dispose() {
    _service.progress.removeListener(_onProgress);
    super.dispose();
  }

  void _onProgress() {
    // The count only moves when a pass finishes, so re-read it then rather
    // than on every batch.
    if (!_service.progress.value.running) _refreshCount();
  }

  Future<void> _refreshCount() async {
    final count = await _service.signedCount();
    if (!mounted) return;
    setState(() => _signedCount = count);
  }

  Future<void> _scan() async {
    await _service.ensureSignatures();
    if (!mounted) return;
    await _refreshCount();
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LocaleProvider>().locale.languageCode;
    final theme = Theme.of(context);

    return ValueListenableBuilder<SignatureProgress>(
      valueListenable: _service.progress,
      builder: (context, progress, _) {
        final running = progress.running;

        return Container(
          padding: EdgeInsets.all(12.sp),
          decoration: BoxDecoration(
            color: ColorSelect.maineColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10.sp),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.data_usage_rounded,
                    size: 17.sp,
                    color: ColorSelect.maineColor,
                  ),
                  SizedBox(width: 8.sp),
                  Expanded(
                    child: Text(
                      DeviceStrings.t(lang, 'gallery_index_title'),
                      style: TextStyle(fontFamily: 'Poppins', fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        color: theme.textTheme.titleMedium?.color,
                      ),
                    ),
                  ),
                  if (!running)
                    TextButton(
                      onPressed: _scan,
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(horizontal: 10.sp),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        DeviceStrings.t(lang, 'gallery_index_scan'),
                        style: TextStyle(fontFamily: 'Poppins', fontSize: 11.sp,
                          fontWeight: FontWeight.w600,
                          color: ColorSelect.maineColor,
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(height: 4.sp),
              Text(
                running && progress.hasWork
                    ? DeviceStrings.t(lang, 'gallery_index_running')
                        .replaceAll('{done}', '${progress.done}')
                        .replaceAll('{total}', '${progress.total}')
                    : DeviceStrings.t(lang, 'gallery_index_idle')
                        .replaceAll('{count}', '${_signedCount ?? 0}'),
                style: TextStyle(fontFamily: 'Poppins', fontSize: 10.5.sp,
                  color: Colors.grey.shade600,
                ),
              ),
              if (running) ...[
                SizedBox(height: 8.sp),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3.sp),
                  child: LinearProgressIndicator(
                    // Indeterminate until the enumeration pass has worked out
                    // how much there is to do.
                    value: progress.hasWork ? progress.fraction : null,
                    minHeight: 3.sp,
                    backgroundColor: Colors.grey.withValues(alpha: 0.25),
                    color: ColorSelect.maineColor,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
