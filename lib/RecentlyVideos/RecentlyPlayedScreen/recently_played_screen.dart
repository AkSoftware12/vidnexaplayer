import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:provider/provider.dart';
import '../../Home/HomeScreen/home2.dart'; // VideoProvider yahi se aa raha hai

class RecentlyPlayedSection extends StatefulWidget {
  final void Function(List<AssetEntity> videos, int index) onTap;

  const RecentlyPlayedSection({super.key, required this.onTap});

  @override
  State<RecentlyPlayedSection> createState() => _RecentlyPlayedSectionState();
}

class _RecentlyPlayedSectionState extends State<RecentlyPlayedSection> {
  List<AssetEntity> _recentEntities = [];
  bool _loading = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadEntities(); // whenever provider updates / screen rebuild
  }

  Future<void> _loadEntities() async {
    if (_loading) return;
    _loading = true;

    final provider = context.read<VideoProvider>();
    final ids = provider.recentlyPlayed;

    final List<AssetEntity> items = [];
    for (final id in ids) {
      final e = await AssetEntity.fromId(id);
      if (e != null) items.add(e);
    }

    if (!mounted) return;
    setState(() {
      _recentEntities = items;
    });

    _loading = false;
  }

  Future<void> _removeSingle(AssetEntity entity) async {
    final id = entity.id;

    // Provider se remove
    context.read<VideoProvider>().removeRecentlyPlayed(id);

    // UI list se remove
    setState(() {
      _recentEntities.removeWhere((e) => e.id == id);
    });
  }


  Future<void> _showClearSinglePopup(BuildContext context, AssetEntity? entity) async {
    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "remove_single",
      barrierColor: Colors.black.withOpacity(0.45),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (context, anim, __, child) {
        final curve = Curves.easeOutCubic.transform(anim.value);
        return Opacity(
          opacity: anim.value,
          child: Transform.scale(
            scale: 0.96 + (0.04 * curve),
            child: _ClearSingleDialog(
              onCancel: () => Navigator.pop(context),
              onRemoveThis: () async {
                await _removeSingle(entity!);
                if (context.mounted) Navigator.pop(context);
              },
              onClearAll: () {
                context.read<VideoProvider>().clearRecentlyPlayed();
                setState(() => _recentEntities.clear());
                Navigator.pop(context);
              },
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<VideoProvider>();
    final ids = provider.recentlyPlayed;

    if (ids.isEmpty) return const SizedBox.shrink();

    // ✅ if ids changed and entities length mismatch, refresh
    if (_recentEntities.length != ids.length && !_loading) {
      _loadEntities();
    }

    return Padding(
      padding: EdgeInsets.only(top: 5.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                /// LEFT ICON
                Container(
                  padding: EdgeInsets.all(7.sp),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Icon(
                    Icons.playlist_play_rounded,
                    size: 15.sp,
                    color: Colors.blue,
                  ),
                ),

                SizedBox(width: 5.w),

                /// TITLE + SUBTITLE
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "Recently Played",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        "Your last watched videos (${ _recentEntities.length})",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 7.sp,
                          fontWeight: FontWeight.w400,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(width: 8.w),

                /// CLEAR BUTTON
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(22.r),
                    onTap: () => _showClearSinglePopup(context, _recentEntities.last), // ✅ Clear All popup
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xff1e88e5), Color(0xff42a5f5)],
                        ),
                        borderRadius: BorderRadius.circular(22.r),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.25),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.cleaning_services_rounded,
                              size: 12.sp, color: Colors.white),
                          SizedBox(width: 3.w),
                          Text(
                            "Clear",
                            style: GoogleFonts.poppins(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(
            height: 80.h,
            child: ListView.separated(
              padding: EdgeInsets.symmetric(horizontal: 5.w),
              scrollDirection: Axis.horizontal,
              itemCount: _recentEntities.length,
              separatorBuilder: (_, __) => SizedBox(width: 10.w),
              itemBuilder: (context, index) {
                final entity = _recentEntities[index];

                return GestureDetector(
                  onTap: () {
                    widget.onTap(_recentEntities, index);
                  },
                  onLongPress: () {
                    _showClearSinglePopup(context, entity);
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14.r),
                    child: Stack(
                      children: [
                        /// 🎬 Thumbnail
                        SizedBox(
                          width: 140.w,
                          height: 80.h,
                          child: FutureBuilder<Uint8List?>(
                            future: entity.thumbnailDataWithSize(
                              const ThumbnailSize(320, 220),
                              quality: 85,
                            ),
                            builder: (context, snap) {
                              if (!snap.hasData) {
                                return Container(
                                  color: Colors.black12,
                                  alignment: Alignment.center,
                                  child: const CircularProgressIndicator(strokeWidth: 2),
                                );
                              }

                              final bytes = snap.data;
                              if (bytes == null) {
                                return Container(
                                  color: Colors.black12,
                                  alignment: Alignment.center,
                                  child: const Icon(Icons.broken_image_outlined),
                                );
                              }

                              return Image.memory(
                                bytes,
                                fit: BoxFit.cover,
                                gaplessPlayback: true,
                              );
                            },
                          ),
                        ),

                        /// ▶ Play icon
                        Positioned(
                          left: 8.w,
                          bottom: 8.h,
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.55),
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            child: const Icon(Icons.play_arrow_rounded, color: Colors.white),
                          ),
                        ),

                        /// ❌ Delete single item button
                        Positioned(
                          top: 6.h,
                          right: 6.w,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20.r),
                            onTap: () {
                              context.read<VideoProvider>().removeFromRecentlyPlayed(entity.id);

                            },
                            child: Container(
                              padding: EdgeInsets.all(5.sp),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.6),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.close_rounded,
                                color: Colors.white,
                                size: 14.sp,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}


class _ClearSingleDialog extends StatelessWidget {
  final VoidCallback onCancel;
  final VoidCallback onRemoveThis;
  final VoidCallback onClearAll;

  const _ClearSingleDialog({
    required this.onCancel,
    required this.onRemoveThis,
    required this.onClearAll,
  });

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final maxH = media.size.height * 0.78;

    return SafeArea(
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 24.h),
        child: Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18.r),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 420.w, maxHeight: maxH),
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(16.r),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18.r),
                    color: Colors.white.withOpacity(0.92),
                    border: Border.all(color: Colors.white.withOpacity(0.7)),
                    boxShadow: [
                      BoxShadow(
                        blurRadius: 26,
                        spreadRadius: 2,
                        color: Colors.black.withOpacity(0.12),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: EdgeInsets.all(12.r),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.blue.withOpacity(0.15),
                              Colors.blue.withOpacity(0.06),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(14.r),
                          border: Border.all(
                            color: Colors.blue.withOpacity(0.18),
                          ),
                        ),
                        child: Icon(
                          Icons.delete_outline_rounded,
                          color: Colors.blue,
                          size: 26.sp,
                        ),
                      ),
                      SizedBox(height: 12.h),

                      Text(
                        "Remove this video?",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(height: 6.h),

                      Text(
                        "This will remove only this item from Recently Played.",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 12.5.sp,
                          fontWeight: FontWeight.w500,
                          color: Colors.black54,
                          height: 1.35,
                        ),
                      ),
                      SizedBox(height: 16.h),

                      // Buttons
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14.r),
                              onTap: onCancel,
                              child: Container(
                                padding: EdgeInsets.symmetric(vertical: 12.h),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14.r),
                                  color: Colors.black.withOpacity(0.06),
                                  border: Border.all(
                                    color: Colors.black.withOpacity(0.08),
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    "Cancel",
                                    style: GoogleFonts.poppins(
                                      fontSize: 13.sp,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 10.w),
                          Expanded(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14.r),
                              onTap: onRemoveThis,
                              child: Container(
                                padding: EdgeInsets.symmetric(vertical: 12.h),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14.r),
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.blue,
                                      Colors.blueAccent.withOpacity(0.95),
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      blurRadius: 18,
                                      color: Colors.blue.withOpacity(0.25),
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Text(
                                    "Remove This",
                                    style: GoogleFonts.poppins(
                                      fontSize: 13.sp,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 10.h),

                      // Clear All (secondary)
                      InkWell(
                        borderRadius: BorderRadius.circular(14.r),
                        onTap: onClearAll,
                        child: Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(vertical: 11.h),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14.r),
                            color: Colors.red.withOpacity(0.08),
                            border: Border.all(color: Colors.red.withOpacity(0.18)),
                          ),
                          child: Center(
                            child: Text(
                              "Clear All Recently Played",
                              style: GoogleFonts.poppins(
                                fontSize: 12.5.sp,
                                fontWeight: FontWeight.w700,
                                color: Colors.red,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
