import 'dart:async';
import 'dart:typed_data';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:material_ui/material_ui.dart';
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

  /// Largest thumbnail edge, in pixels.
  ///
  /// Was `(width ?? 200) * 2` clamped to 1080, i.e. up to a 1080x1080 bitmap
  /// per tile — ~4.6 MB decoded. A grid of those is what fed the
  /// `java.lang.OutOfMemoryError` reports. 200px at quality 50 is more than a
  /// list tile or grid cell ever shows and cuts the decoded size ~29x.
  static const int _maxEdge = 200;
  static const int _quality = 50;

  /// Never throws.
  ///
  /// Crash 4 was `_VideoThumbState._load -> FlutterError: Unsupported
  /// operation`. Three separate things could produce it, and the old body
  /// caught only the last of them:
  ///  * the asset row still being in MediaStore while the file behind it is
  ///    gone (deleted from another app, SD card unmounted) — the native side
  ///    then fails on a decoder it cannot build,
  ///  * an `await` completing after the State was disposed,
  ///  * a codec the device has no decoder for at all.
  /// Everything is inside one try/catch now, failure is a null result rather
  /// than a rethrow, and the real ones are reported to Crashlytics as
  /// non-fatal so they stay visible without killing the app.
  Future<void> _load() async {
    try {
      final id = widget.asset.id;

      final cached = _cache[id];
      if (cached != null) {
        if (mounted) setState(() => _bytes = cached);
        return;
      }

      // Cheapest possible guard: a MediaStore id lookup, no file handle. An
      // asset whose file is gone is an ordinary event (the user deleted it
      // elsewhere), so it shows the placeholder and is NOT reported.
      final stillThere = await widget.asset.exists;
      if (!mounted) return;
      if (!stillThere) {
        setState(() => _failed = true);
        return;
      }

      final edge = _thumbEdge();
      final data = await widget.asset.thumbnailDataWithSize(
        ThumbnailSize(edge, edge),
        quality: _quality,
      );

      // The await above can outlive this State — every setState past this
      // point needs the guard, or it throws after dispose().
      if (!mounted) return;
      if (data == null || data.isEmpty) {
        setState(() => _failed = true);
        return;
      }

      if (_cache.length >= _cacheLimit) _cache.clear();
      _cache[id] = data;
      setState(() => _bytes = data);
    } catch (e, s) {
      // Non-fatal: one unreadable video must not take the app down, and the
      // tile has a placeholder for exactly this case.
      unawaited(_report(e, s));
      if (mounted) setState(() => _failed = true);
    }
  }

  /// Requested thumbnail edge in pixels, capped at [_maxEdge].
  int _thumbEdge() {
    final requested = (widget.width ?? widget.height ?? _maxEdge.toDouble());
    if (!requested.isFinite || requested <= 0) return _maxEdge;
    // Clamp as a double *before* rounding. `(requested * 2).round()` on its
    // own can still overflow to infinity for an absurd incoming width, and
    // `double.infinity.round()` is exactly the
    // "Unsupported operation: Infinity or NaN toInt" this method exists to
    // prevent.
    final doubled = (requested * 2).clamp(64.0, _maxEdge.toDouble());
    return doubled.round();
  }

  Future<void> _report(Object e, StackTrace s) async {
    try {
      await FirebaseCrashlytics.instance.recordError(
        e,
        s,
        reason: 'VideoThumb thumbnail decode failed',
        fatal: false,
      );
    } catch (_) {
      // Crashlytics not initialised yet (or disabled) — never let the
      // reporting path become the thing that crashes.
    }
  }


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