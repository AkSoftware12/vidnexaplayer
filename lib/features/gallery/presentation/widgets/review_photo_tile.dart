import 'package:material_ui/material_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../../Utils/color.dart';
import '../../domain/entities/photo_entity.dart';
import '../../domain/repositories/gallery_repository.dart';
import 'byte_format.dart';
import 'photo_thumbnail.dart';

/// A photo as it appears in a review screen, with everything needed to decide
/// whether to delete it: the picture, its size, its resolution, and — when it
/// is the suggested keeper — why it was suggested.
///
/// Deliberately larger and more informative than a grid tile. These screens
/// delete files permanently, and a 5-column thumbnail is not enough to judge
/// which of two near-identical shots to keep.
class ReviewPhotoTile extends StatelessWidget {
  const ReviewPhotoTile({
    super.key,
    required this.photo,
    required this.sizeBytes,
    required this.selected,
    required this.onTap,
    this.isKeeper = false,
    this.keeperLabel,
  });

  final PhotoEntity photo;
  final int sizeBytes;
  final bool selected;
  final VoidCallback onTap;
  final bool isKeeper;
  final String? keeperLabel;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(7.sp),
                  child: PhotoThumbnail(
                    repository: context.read<GalleryRepository>(),
                    photoId: photo.id,
                    pixelSize: 384,
                  ),
                ),
                if (selected)
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(7.sp),
                      border: Border.all(color: Colors.red, width: 2.5),
                      color: Colors.red.withValues(alpha: 0.22),
                    ),
                  ),
                if (isKeeper && !selected)
                  Positioned(
                    left: 4.sp,
                    top: 4.sp,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 6.sp,
                        vertical: 2.sp,
                      ),
                      decoration: BoxDecoration(
                        color: ColorSelect.maineColor,
                        borderRadius: BorderRadius.circular(4.sp),
                      ),
                      child: Text(
                        keeperLabel ?? '',
                        style: TextStyle(fontFamily: 'Poppins', fontSize: 8.5.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  right: 4.sp,
                  top: 4.sp,
                  child: Icon(
                    selected
                        ? Icons.remove_circle_rounded
                        : Icons.circle_outlined,
                    size: 19.sp,
                    color: selected ? Colors.red : Colors.white,
                    shadows: const [
                      Shadow(color: Colors.black54, blurRadius: 4),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 4.sp),
          Text(
            formatBytes(sizeBytes),
            style: TextStyle(fontFamily: 'Poppins', fontSize: 10.sp,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).textTheme.bodyMedium?.color,
            ),
          ),
          Text(
            '${photo.width} × ${photo.height}',
            style: TextStyle(fontFamily: 'Poppins', fontSize: 9.sp,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }
}
