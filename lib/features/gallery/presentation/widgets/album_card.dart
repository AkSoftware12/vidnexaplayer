import 'package:material_ui/material_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../../NotifyListeners/LanguageProvider/device_strings.dart';
import '../../../../NotifyListeners/LanguageProvider/language_provider.dart';
import '../../domain/entities/photo_album.dart';
import '../../domain/repositories/gallery_repository.dart';
import '../controllers/gallery_controller.dart';
import 'photo_thumbnail.dart';

/// One album on the Albums tab.
///
/// The cover is resolved by asking the album for its first photo id once, when
/// the card is first built. The old `AlbumTile` nested two `FutureBuilder`s —
/// one for the count, one for the cover — both of which re-fired on every
/// rebuild; the count now arrives with the album itself and the cover future
/// is created in `initState` so a scroll cannot restart it.
class AlbumCard extends StatefulWidget {
  const AlbumCard({
    super.key,
    required this.album,
    required this.onTap,
  });

  final PhotoAlbum album;
  final VoidCallback onTap;

  @override
  State<AlbumCard> createState() => _AlbumCardState();
}

class _AlbumCardState extends State<AlbumCard> {
  String? _coverId;
  bool _resolved = false;

  @override
  void initState() {
    super.initState();
    _resolveCover();
  }

  Future<void> _resolveCover() async {
    final controller = context.read<GalleryController>();
    final photos = await controller.coverPhotoFor(widget.album.id);
    if (!mounted) return;
    setState(() {
      _coverId = photos;
      _resolved = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LocaleProvider>().locale.languageCode;
    final coverId = _coverId;

    return InkWell(
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(8.sp),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8.sp),
              child: coverId != null
                  ? PhotoThumbnail(
                      repository: context.read<GalleryRepository>(),
                      photoId: coverId,
                      pixelSize: 384,
                    )
                  : Container(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white10
                          : Colors.black12,
                      alignment: Alignment.center,
                      child: _resolved
                          ? Icon(
                              Icons.photo_library_outlined,
                              size: 26.sp,
                              color: Colors.grey.shade500,
                            )
                          : null,
                    ),
            ),
          ),
          SizedBox(height: 6.sp),
          Text(
            widget.album.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontFamily: 'Poppins', fontSize: 11.5.sp,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).textTheme.titleMedium?.color,
            ),
          ),
          Text(
            DeviceStrings.t(lang, 'gallery_photos_count')
                .replaceAll('{count}', '${widget.album.assetCount}'),
            style: TextStyle(fontFamily: 'Poppins', fontSize: 10.5.sp,
              fontWeight: FontWeight.w400,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }
}
