import 'package:material_ui/material_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../../NotifyListeners/LanguageProvider/device_strings.dart';
import '../../../../NotifyListeners/LanguageProvider/language_provider.dart';
import '../controllers/review_controller.dart';
import 'byte_format.dart';
import 'gallery_dialog.dart';

/// The confirm-and-delete bar shared by the duplicate finder and the junk
/// cleaner.
///
/// States exactly what will happen — how many photos, how much space — before
/// the confirm dialog, and again inside it. The count and the bytes are the
/// two things someone needs to catch a mistake before it becomes permanent.
class DeleteActionBar extends StatelessWidget {
  const DeleteActionBar({super.key, required this.controller});

  final ReviewController controller;

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LocaleProvider>().locale.languageCode;
    final count = controller.selectedCount;

    if (count == 0) return const SizedBox.shrink();

    return Material(
      elevation: 12,
      color: Theme.of(context).cardColor,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 14.sp, vertical: 10.sp),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      DeviceStrings.t(lang, 'gallery_selected_count')
                          .replaceAll('{count}', '$count'),
                      style: TextStyle(fontFamily: 'Poppins', fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).textTheme.titleMedium?.color,
                      ),
                    ),
                    Text(
                      DeviceStrings.t(lang, 'gallery_frees_space')
                          .replaceAll(
                            '{size}',
                            formatBytes(controller.selectedBytes),
                          ),
                      style: TextStyle(fontFamily: 'Poppins', fontSize: 10.5.sp,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: controller.clearSelection,
                child: Text(
                  DeviceStrings.t(lang, 'gallery_cancel'),
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 11.5.sp,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
              SizedBox(width: 4.sp),
              ElevatedButton.icon(
                onPressed: () => _confirm(context, lang),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.sp),
                  ),
                ),
                icon: Icon(Icons.delete_outline, size: 16.sp),
                label: Text(
                  DeviceStrings.t(lang, 'gallery_delete'),
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 11.5.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirm(BuildContext context, String lang) async {
    final messenger = ScaffoldMessenger.of(context);
    final count = controller.selectedCount;
    final size = formatBytes(controller.selectedBytes);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => GalleryDialog(
        icon: Icons.delete_outline,
        title: DeviceStrings.t(lang, 'gallery_delete_title'),
        destructive: true,
        actions: [
          DialogCancelButton(
            label: DeviceStrings.t(lang, 'gallery_cancel'),
            onPressed: () => Navigator.pop(dialogContext, false),
          ),
          DialogConfirmButton(
            label: DeviceStrings.t(lang, 'gallery_delete'),
            destructive: true,
            onPressed: () => Navigator.pop(dialogContext, true),
          ),
        ],
        child: Text(
          DeviceStrings.t(lang, 'gallery_delete_confirm_detail')
              .replaceAll('{count}', '$count')
              .replaceAll('{size}', size),
          style: TextStyle(fontFamily: 'Poppins', fontSize: 12.5.sp,
            height: 1.45,
            color: Theme.of(context).textTheme.bodyMedium?.color,
          ),
        ),
      ),
    );
    if (confirmed != true) return;

    final deleted = await controller.deleteSelected();

    // Zero means the system consent dialog was declined. Normal, not an error.
    if (deleted == 0) return;

    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 2),
        content: Text(
          DeviceStrings.t(lang, 'gallery_deleted_toast')
              .replaceAll('{count}', '$deleted'),
        ),
      ),
    );
  }
}
