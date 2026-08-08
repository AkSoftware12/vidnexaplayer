import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

class VideoThumb extends StatefulWidget {
  final AssetEntity asset;
  final double? width;
  final double? height;
  final BoxFit fit;
  final IconData placeholderIcon;
  final BorderRadius? borderRadius;

  const VideoThumb({
    super.key,
    required this.asset,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholderIcon = Icons.movie_outlined,
    this.borderRadius,
  });

  @override
  State<VideoThumb> createState() => _VideoThumbState();
}

class _VideoThumbState extends State<VideoThumb> {
  /// id -> bytes cache (rebuild pe dobara decode na ho)
  ///
  /// Capped: browsing a large library (thousands of assets) would otherwise
  /// grow this forever for the lifetime of the process, since nothing ever
  /// called [clearCache]. A full clear-on-overflow is enough here — this
  /// isn't hot enough to need a true LRU.
  static final Map<String, Uint8List> _cache = {};
  static const int _cacheLimit = 400;

  Uint8List? _bytes;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant VideoThumb old) {
    super.didUpdateWidget(old);
    if (old.asset.id != widget.asset.id) {
      _bytes = null;
      _failed = false;
      _load();
    }
  }

  Future<void> _load() async {
    final id = widget.asset.id;

    final cached = _cache[id];
    if (cached != null) {
      if (mounted) setState(() => _bytes = cached);
      return;
    }

    // width/height null ho to default size
    final w = ((widget.width ?? 200) * 2).round().clamp(64, 1080);
    final h = ((widget.height ?? 200) * 2).round().clamp(64, 1080);

    try {
      final data = await widget.asset.thumbnailDataWithSize(
        ThumbnailSize(w, h),
        quality: 80,
      );

      if (!mounted) return;
      if (data == null) {
        setState(() => _failed = true);
        return;
      }
      if (_cache.length >= _cacheLimit) _cache.clear();
      _cache[id] = data;
      setState(() => _bytes = data);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  static void clearCache() => _cache.clear();

  @override
  Widget build(BuildContext context) {
    Widget child;

    if (_bytes != null) {
      child = Image.memory(
        _bytes!,
        width: widget.width ?? double.infinity, // <- full width
        height: widget.height,
        fit: widget.fit,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    } else if (_failed) {
      child = _placeholder();
    } else {
      child = _placeholder(loading: true);
    }

    if (widget.borderRadius != null) {
      child = ClipRRect(borderRadius: widget.borderRadius!, child: child);
    }
    return child;
  }

  Widget _placeholder({bool loading = false}) {
    return Container(
      width: widget.width,
      height: widget.height,
      color: Colors.grey.shade300,
      alignment: Alignment.center,
      child: loading
          ? const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      )
          : Icon(
        widget.placeholderIcon,
        color: Colors.grey.shade600,
        size: 22,
      ),
    );
  }
}