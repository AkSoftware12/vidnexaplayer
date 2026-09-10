import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../Utils/color.dart';

/// Dialog action buttons with explicit colours.
///
/// The app's light theme sets `colorScheme.primary` to white and its dark
/// theme sets it to a dark grey, and a bare `TextButton` takes its foreground
/// from exactly that — so default dialog buttons render white-on-white or
/// grey-on-grey and read as missing. Every dialog in this module goes through
/// these two widgets instead of styling buttons ad hoc.
///
/// The pairing also carries meaning: the confirming action is filled, the
/// dismissing one is not, so which button does the irreversible thing is
/// obvious before reading either label.
class DialogCancelButton extends StatelessWidget {
  const DialogCancelButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: Colors.grey.shade600,
        padding: EdgeInsets.symmetric(horizontal: 16.sp, vertical: 10.sp),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.sp),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(fontFamily: 'Poppins', fontSize: 12.5.sp,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

/// The confirming action. [destructive] paints it red — used by the delete
/// confirmations, where the filled button is the one that cannot be undone.
class DialogConfirmButton extends StatelessWidget {
  const DialogConfirmButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.destructive = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final background =
        destructive ? Colors.red.shade600 : ColorSelect.maineColor;

    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: background,
        foregroundColor: Colors.white,
        disabledBackgroundColor: Colors.grey.shade400,
        disabledForegroundColor: Colors.white70,
        elevation: 0,
        padding: EdgeInsets.symmetric(horizontal: 20.sp, vertical: 11.sp),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.sp),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(fontFamily: 'Poppins', fontSize: 12.5.sp,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Shared dialog shell: an accent-tinted icon, a title, the caller's body, and
/// a right-aligned action row.
///
/// Exists so the module's dialogs cannot drift apart in padding, radius or
/// button placement as they get edited one at a time.
class GalleryDialog extends StatelessWidget {
  const GalleryDialog({
    super.key,
    required this.icon,
    required this.title,
    required this.child,
    required this.actions,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final Widget child;
  final List<Widget> actions;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = destructive ? Colors.red.shade600 : ColorSelect.maineColor;

    return Dialog(
      backgroundColor: theme.dialogTheme.backgroundColor ?? theme.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.sp),
      ),
      insetPadding: EdgeInsets.symmetric(horizontal: 28.sp, vertical: 24.sp),
      child: Padding(
        padding: EdgeInsets.fromLTRB(20.sp, 20.sp, 20.sp, 14.sp),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36.sp,
                  height: 36.sp,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(9.sp),
                  ),
                  child: Icon(icon, size: 19.sp, color: accent),
                ),
                SizedBox(width: 11.sp),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 14.5.sp,
                      fontWeight: FontWeight.w600,
                      color: theme.textTheme.titleLarge?.color,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16.sp),
            child,
            SizedBox(height: 18.sp),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                for (final action in actions) ...[
                  action,
                  if (action != actions.last) SizedBox(width: 8.sp),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
