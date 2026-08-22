import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:videoplayer/Utils/color.dart';

import 'app_language.dart';
import 'app_strings.dart';
import 'language_provider.dart';

/// Shared "Choose Language" bottom sheet — defaults to whatever
/// [LocaleProvider] currently holds (English on first launch), lets the user
/// pick a different language, and only actually switches the app on "Apply"
/// so browsing the list doesn't change anything until confirmed.
///
/// Used from the drawer, the home app bar (next to voice search) and the
/// Profile screen so there is a single place styling/behavior lives.
void showLanguagePickerSheet(BuildContext context, {bool isDark = false}) {
  final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
  String pendingCode = localeProvider.locale.languageCode;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: isDark ? const Color(0xff1E293B) : Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
    ),
    builder: (sheetCtx) {
      return StatefulBuilder(
        builder: (sheetCtx, setSheetState) {
          final lang = localeProvider.locale.languageCode;
          return Padding(
            padding: EdgeInsets.only(
              left: 16.w,
              right: 16.w,
              top: 16.h,
              bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 16.h,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                ),
                SizedBox(height: 14.h),
                Text(
                  AppStrings.t(lang, 'choose_language'),
                  style: GoogleFonts.openSans(
                    textStyle: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ),
                SizedBox(height: 14.h),
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: 360.h),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: kAppLanguages.length,
                    itemBuilder: (_, i) {
                      final option = kAppLanguages[i];
                      final bool isSelected = pendingCode == option.code;
                      return Container(
                        margin: EdgeInsets.only(bottom: 8.h),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14.r),
                          color: isSelected
                              ? const Color(0xff0891B2).withValues(alpha: 0.12)
                              : Colors.transparent,
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xff0891B2)
                                : Colors.grey.shade300,
                          ),
                        ),
                        child: ListTile(
                          leading: Text(
                            option.flag,
                            style: TextStyle(fontSize: 20.sp),
                          ),
                          title: Text(
                            option.nativeName,
                            style: GoogleFonts.openSans(
                              textStyle: TextStyle(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                          ),
                          subtitle: Text(
                            option.englishName,
                            style: GoogleFonts.openSans(
                              textStyle: TextStyle(
                                fontSize: 10.sp,
                                color: isDark ? Colors.white70 : Colors.grey.shade600,
                              ),
                            ),
                          ),
                          trailing: isSelected
                              ? const Icon(Icons.check_circle, color: Color(0xff0891B2))
                              : null,
                          onTap: () {
                            setSheetState(() {
                              pendingCode = option.code;
                            });
                          },
                        ),
                      );
                    },
                  ),
                ),
                SizedBox(height: 10.h),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      // backgroundColor: const Color(0xff0891B2),
                      backgroundColor: ColorSelect.maineColor,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 13.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14.r),
                      ),
                    ),
                    onPressed: () async {
                      await localeProvider.setLocale(Locale(pendingCode));
                      if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                    },
                    child: Text(
                      AppStrings.t(lang, 'apply'),
                      style: GoogleFonts.openSans(
                        textStyle: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}
