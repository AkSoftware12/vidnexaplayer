import 'dart:io';

import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:videoplayer/Utils/color.dart';

import '../Utils/video_thumb.dart';
import '../ads/app_open_ad_manager.dart';

class AlbumScreen extends StatefulWidget {
  @override
  _AlbumScreenState createState() => _AlbumScreenState();
}

class _AlbumScreenState extends State<AlbumScreen> with SingleTickerProviderStateMixin {

  final appOpenManager = AppOpenAdManager();

  List<AssetPathEntity> _albums = [];
  bool _isLoading = true;
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _requestPermissionAndLoadAlbums();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _requestPermissionAndLoadAlbums() async {
    final PermissionState ps = await PhotoManager.requestPermissionExtend();
    if (ps.isAuth) {
      final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
        type: RequestType.image,
      );
      setState(() {
        _albums = albums;
        _isLoading = false;
        _controller.forward();
      });
    } else {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Permission denied to access photos', style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        iconTheme: IconThemeData(color: Colors.white),
        title:Text(
          'Photo Albums',
          style: GoogleFonts.openSans(
            color: Colors.white,
            fontSize: 16.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
        elevation: 4,
        backgroundColor: ColorSelect.maineColor,
      ),
      body: _isLoading
          ? Center(child: AnimatedProgressIndicator())
          : _albums.isEmpty
          ? Center(child: Text('No albums found', style: Theme.of(context).textTheme.bodyMedium))
          : FadeTransition(
        opacity: _fadeAnimation,
        child: GridView.builder(
          padding: EdgeInsets.all(8.sp), // Added padding for better UX
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 5.sp,
            mainAxisSpacing: 5.sp,
            childAspectRatio: 0.8, // Adjusted for better thumbnail appearance
          ),
          itemCount: _albums.length,
          itemBuilder: (context, index) {
            return AlbumTile(album: _albums[index]);
          },
        ),
      ),

      bottomNavigationBar:appOpenManager.bannerWidget(),

    );
  }
}

class AnimatedProgressIndicator extends StatefulWidget {
  @override
  _AnimatedProgressIndicatorState createState() => _AnimatedProgressIndicatorState();
}

class _AnimatedProgressIndicatorState extends State<AnimatedProgressIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(seconds: 1),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: CupertinoActivityIndicator(
        radius: 25,
        color: ColorSelect.maineColor,
        animating: true,
      ),
    );
  }
}

class AlbumTile extends StatelessWidget {
  final AssetPathEntity album;

  AlbumTile({required this.album});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int>(
      future: album.assetCountAsync,
      builder: (context, snapshot) {
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) => PhotosScreen(album: album),
                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                  const begin = Offset(1.0, 0.0);
                  const end = Offset.zero;
                  const curve = Curves.easeInOut;
                  var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                  return SlideTransition(position: animation.drive(tween), child: child);
                },
              ),
            );
          },
          child: AnimatedScale(
            duration: Duration(milliseconds: 500),
            scale: snapshot.hasData ? 1.0 : 1,
            child: Card(
              elevation: 6,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(5)),
                      child: FutureBuilder<List<AssetEntity>>(
                        future: album.getAssetListRange(start: 0, end: 1),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData || snapshot.data!.isEmpty) {
                            return Center(child: Icon(Icons.image_not_supported, size: 30.sp, color: Colors.grey[600]));
                          }
                          final cover = snapshot.data![0];
                          return VideoThumb(
                            key: ValueKey(cover.id),
                            asset: cover,
                            placeholderIcon: Icons.image_outlined,
                          );
                        },
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(12.sp),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          album.name,
                          style: GoogleFonts.poppins(
                            color: Colors.black,
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 0.h),
                        Text(
                          '${snapshot.data ?? 0} photos',
                          style: GoogleFonts.poppins(
                            color: Colors.grey[600],
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

}

class PhotosScreen extends StatefulWidget {
  final AssetPathEntity album;

  PhotosScreen({required this.album});

  @override
  _PhotosScreenState createState() => _PhotosScreenState();
}

class _PhotosScreenState extends State<PhotosScreen> with SingleTickerProviderStateMixin {
  List<AssetEntity> _photos = [];
  bool _isLoading = true;
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _loadPhotos();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadPhotos() async {
    final List<AssetEntity> photos = await widget.album.getAssetListRange(start: 0, end: 1000);
    setState(() {
      _photos = photos;
      _isLoading = false;
      _controller.forward();
    });
  }

  void _onPhotoDeleted() {
    _loadPhotos();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        iconTheme: IconThemeData(color: Colors.white),
        title:Text(
          widget.album.name,
          style: GoogleFonts.openSans(
          color: Colors.white,
          fontSize: 16.sp,
          fontWeight: FontWeight.w500,
        ),
        ),
        elevation: 4,
        backgroundColor: ColorSelect.maineColor,
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: _loadPhotos,
        child: Icon(Icons.refresh,color: Colors.white,),
        backgroundColor: ColorSelect.maineColor,
      ),
      body: _isLoading
          ? Center(child: AnimatedProgressIndicator())
          : _photos.isEmpty
          ? Center(child: Text('No photos in this album', style: Theme.of(context).textTheme.bodyMedium))
          : FadeTransition(
        opacity: _fadeAnimation,
        child: GridView.builder(
          padding: EdgeInsets.all(8.sp),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 5.sp,
            mainAxisSpacing: 5.sp,
            childAspectRatio: 1.0, // Square tiles for better appearance
          ),
          itemCount: _photos.length,
          itemBuilder: (context, index) {
            return PhotoTile(
              photo: _photos[index],
              photos: _photos,
              initialIndex: index,
              onDelete: _onPhotoDeleted,
            );
          },
        ),
      ),
    );
  }
}

class PhotoTile extends StatelessWidget {
  final AssetEntity photo;
  final List<AssetEntity> photos;
  final int initialIndex;
  final VoidCallback onDelete;

  PhotoTile({required this.photo, required this.photos, required this.initialIndex, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => FullScreenPhoto(
              photos: photos,
              initialIndex: initialIndex,
              onDelete: onDelete,
            ),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              const begin = Offset(0.0, 1.0);
              const end = Offset.zero;
              const curve = Curves.easeInOut;
              var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
              return SlideTransition(position: animation.drive(tween), child: child);
            },
          ),
        );
      },
      child: AnimatedScale(
        duration: Duration(milliseconds: 500),
        scale: 1.0,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: VideoThumb(
            key: ValueKey(photo.id),
            asset: photo,
            placeholderIcon: Icons.image_outlined,
          ),
        ),
      ),
    );
  }
}

class FullScreenPhoto extends StatefulWidget {
  final List<AssetEntity> photos;
  final int initialIndex;
  final VoidCallback onDelete;

  FullScreenPhoto({required this.photos, required this.initialIndex, required this.onDelete});

  @override
  _FullScreenPhotoState createState() => _FullScreenPhotoState();
}

class _FullScreenPhotoState extends State<FullScreenPhoto> {
  late PageController _pageController;
  late int _currentIndex;
  late List<AssetEntity> _photos;
  Color _backgroundColor = Colors.black;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _photos = List.from(widget.photos);
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _deletePhoto(BuildContext context) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Delete Photo', style: Theme.of(context).textTheme.titleLarge),
        content: Text('Are you sure you want to delete this photo?', style: Theme.of(context).textTheme.bodyMedium),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: Colors.teal)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final result = await PhotoManager.editor.deleteWithIds([_photos[_currentIndex].id]);
        if (result.isNotEmpty) {
          setState(() {
            _photos.removeAt(_currentIndex);
            if (_photos.isEmpty) {
              widget.onDelete();
              Navigator.pop(context);
              return;
            }
            if (_currentIndex >= _photos.length) {
              _currentIndex = _photos.length - 1;
            }
            _pageController.jumpToPage(_currentIndex);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Photo deleted successfully', style: TextStyle(color: Colors.white)),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
          widget.onDelete();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete photo', style: TextStyle(color: Colors.white)),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting photo: $e', style: TextStyle(color: Colors.white)),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        iconTheme: IconThemeData(color: Colors.white),
        title:Text(
          _photos.isEmpty ? '0/0' : '${_currentIndex + 1}/${_photos.length}',
          style: GoogleFonts.openSans(
            color: Colors.white,
            fontSize: 14.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.delete, color: Colors.white),
            onPressed: _photos.isEmpty ? null : () => _deletePhoto(context),
          ),
        ],
        elevation: 4,
        backgroundColor: Colors.black,
      ),
      body: Container(
        color: _backgroundColor,
        child: _photos.isEmpty
            ? Center(child: Text('No photos available', style: Theme.of(context).textTheme.bodyMedium))
            : PageView.builder(
          controller: _pageController,
          itemCount: _photos.length,
          onPageChanged: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          itemBuilder: (context, index) {
            final photo = _photos[index];
            return Center(
              child: _FullPhoto(key: ValueKey(photo.id), asset: photo),
            );
          },
        ),
      ),
    );
  }
}

/// Full-resolution page in the photo viewer.
///
/// Replaces a `FutureBuilder(future: _buildFullImage(...))` that (a) re-read the
/// file from MediaStore on every rebuild — and a PageView rebuilds constantly
/// while swiping — and (b) did `Image.file(file!)`, crashing outright whenever
/// the asset had no local file (deleted, or cloud-only).
class _FullPhoto extends StatefulWidget {
  const _FullPhoto({super.key, required this.asset});

  final AssetEntity asset;

  @override
  State<_FullPhoto> createState() => _FullPhotoState();
}

class _FullPhotoState extends State<_FullPhoto> {
  late Future<File?> _file;

  @override
  void initState() {
    super.initState();
    _file = widget.asset.file;
  }

  @override
  void didUpdateWidget(_FullPhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.asset.id != widget.asset.id) {
      _file = widget.asset.file;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<File?>(
      future: _file,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return AnimatedProgressIndicator();
        }

        final file = snapshot.data;
        if (file == null) {
          return Container(
            color: Colors.grey[300],
            padding: EdgeInsets.all(24.sp),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.broken_image_outlined, size: 48.sp, color: Colors.grey),
                SizedBox(height: 8.sp),
                const Text('This file is no longer available'),
              ],
            ),
          );
        }

        return Image.file(
          file,
          fit: BoxFit.fitWidth,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (context, error, stackTrace) => Container(
            color: Colors.grey[300],
            child: Icon(Icons.error, size: 50.sp, color: Colors.red),
          ),
        );
      },
    );
  }
}

class AnimatedScale extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final double scale;

  AnimatedScale({required this.child, required this.duration, required this.scale});

  @override
  _AnimatedScaleState createState() => _AnimatedScaleState();
}

class _AnimatedScaleState extends State<AnimatedScale> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: widget.scale).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: widget.child,
    );
  }
}