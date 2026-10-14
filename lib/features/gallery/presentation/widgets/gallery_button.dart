import 'package:material_ui/material_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../Utils/color.dart';

/// The gallery module's one filled button.
///
/// Every tool page, the delete bar, the dialogs and the permission screen used
/// to style their own `ElevatedButton` — and they had drifted to four corner
/// radii (8, 9, 10, 12), three paddings, two disabled colours and a mix of
/// raised and flat. They all go through this now, so they cannot drift again
/// one edit at a time.
///
/// Two sizes: [GalleryButton] fills the width (the main action at the bottom
/// of a tool page); [GalleryButton.compact] hugs its label (dialogs, inline
/// actions, the delete bar).
class GalleryButton extends StatelessWidget {
  const GalleryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.busy = false,
    this.destructive = false,
  }) : expanded = true;

  const GalleryButton.compact({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.busy = false,
    this.destructive = false,
  }) : expanded = false;

  final String label;

  /// Null disables the button.
  final VoidCallback? onPressed;
  final IconData? icon;

  /// Shows a spinner in place of the label, and ignores taps.
  final bool busy;

  /// Red instead of the accent — for actions that delete.
  final bool destructive;

  final bool expanded;

  static double get radius => 10.sp;

  @override
  Widget build(BuildContext context) {
    final background =
        destructive ? Colors.red.shade600 : ColorSelect.maineColor;
    final fontSize = expanded ? 13.sp : 12.sp;

    final Widget content = busy
        ? SizedBox(
            width: 18.sp,
            height: 18.sp,
            child: const CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: fontSize + 3.sp),
                SizedBox(width: 6.sp),
              ],
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontFamily: 'Poppins', fontSize: fontSize,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          );

    final button = ElevatedButton(
      onPressed: busy ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: background,
        foregroundColor: Colors.white,
        // Readable on both the light gallery pages and the black editors.
        disabledBackgroundColor: background.withValues(alpha: 0.38),
        disabledForegroundColor: Colors.white70,
        elevation: 0,
        padding: expanded
            ? EdgeInsets.symmetric(vertical: 13.sp)
            : EdgeInsets.symmetric(horizontal: 20.sp, vertical: 11.sp),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
      child: content,
    );

    return expanded
        ? SizedBox(width: double.infinity, child: button)
        : button;
  }
}
