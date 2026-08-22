import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:provider/provider.dart';
import '../../../../NotifyListeners/LanguageProvider/home_strings.dart';
import '../../../../NotifyListeners/LanguageProvider/language_provider.dart';

class FolderInfoDialog {
  static void show(
      BuildContext context, {
        required String folderName,
        required String size,
        required String location,
        required String modifiedDate,
        required final AssetPathEntity videos,
      }) {
    final lang = context.read<LocaleProvider>().locale.languageCode;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          backgroundColor: Colors.white,
          title: Row(
            children: [
              const Icon(Icons.folder, color: Colors.blue, size: 30),
              const SizedBox(width: 8),
              Text(
                HomeStrings.t(lang, 'folder_info_title'),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoRow(HomeStrings.t(lang, 'folder_info_name_label'), folderName),
              SizedBox(height: 12.h),
              _buildInfoRow(HomeStrings.t(lang, 'folder_info_size_label'), size),
              SizedBox(height: 12.h),
              _buildInfoRow(HomeStrings.t(lang, 'folder_info_location_label'), location),
              SizedBox(height: 12.h),
              _buildInfoRow(HomeStrings.t(lang, 'folder_info_modified_label'), modifiedDate),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  HomeStrings.t(lang, 'folder_info_ok'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  static Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label: ',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: Colors.black87,
            fontSize: 12.sp,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(color: Colors.black87, fontSize: 12.sp),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ),
      ],
    );
  }
}
