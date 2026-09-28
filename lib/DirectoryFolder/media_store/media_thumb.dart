import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../file_browser/file_kind.dart';
import 'media_store.dart';

/// Square preview for a MediaStore item, with the file-type icon as fallback.
///
/// Thumbnails come from the system's own cache via `ContentResolver
/// .loadThumbnail`, so nothing here decodes a full-size photo or seeks a video.
/// Results are memoised in [_ThumbCache] because a grid re-requests the same
/// item constantly while scrolling.
class MediaThumb extends StatefulWidget {
  const MediaThumb({
    super.key,
    required this.file,
    this.size = 256,
    this.fit = BoxFit.cover,
  });

  final MediaFile file;
  final int size;
  final BoxFit fit;

  @override
  State<MediaThumb> createState() => _MediaThumbState();
}

class _MediaThumbState extends State<MediaThumb> {
  Uint8List? _bytes;
  bool _tried = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(MediaThumb old) {
    super.didUpdateWidget(old);
    if (old.file.uri != widget.file.uri) {
      _bytes = null;
      _tried = false;
      _load();
    }
  }

  Future<void> _load() async {
    final kind = widget.file.kind;
    // Only media has a system thumbnail; asking for a pdf's costs a round trip
    // to be told no.
    if (kind != FileKind.image && kind != FileKind.video) {
      _tried = true;
      return;
    }

    final cached = _ThumbCache.instance.get(widget.file.uri);
    if (cached != null) {
      // Synchronous hit — set directly so the tile never flashes an icon.
      _bytes = cached;
      _tried = true;
      return;
    }

    final bytes = await _ThumbCache.instance.fetch(widget.file.uri, widget.size);
    if (!mounted) return;
    setState(() {
      _bytes = bytes;
      _tried = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;
    if (bytes != null) {
      return Image.memory(
        bytes,
        fit: widget.fit,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => _fallback(),
      );
    }
    return _fallback(showSpinner: !_tried);
  }

  Widget _fallback({bool showSpinner = false}) {
    final kind = widget.file.kind;
    return ColoredBox(
      color: kind.color.withValues(alpha: 0.12),
      child: Center(
        child: showSpinner
            ? const SizedBox(
                height: 16,
                width: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(kind.icon, color: kind.color, size: 24),
      ),
    );
  }
}

/// Bounded in-memory thumbnail cache.
///
/// Bounded because the alternative is holding a decoded bitmap for every file
/// the user has scrolled past; on a library of a few thousand photos that is
/// the out-of-memory kill. Oldest entries are dropped first.
class _ThumbCache {
  _ThumbCache._();
  static final _ThumbCache instance = _ThumbCache._();

  static const MethodChannel _channel =
      MethodChannel('com.vidnexa.videoplayer/media_store');

  static const int _maxEntries = 300;

  final LinkedHashMap<String, Uint8List?> _entries = LinkedHashMap();

  /// In-flight requests, so a tile rebuilt mid-scroll does not start a second
  /// platform call for the same uri.
  final Map<String, Future<Uint8List?>> _pending = {};

  Uint8List? get(String uri) => _entries[uri];

  Future<Uint8List?> fetch(String uri, int size) {
    final existing = _pending[uri];
    if (existing != null) return existing;

    final future = _load(uri, size);
    _pending[uri] = future;
    return future.whenComplete(() => _pending.remove(uri));
  }

  Future<Uint8List?> _load(String uri, int size) async {
    try {
      final bytes = await _channel.invokeMethod<Uint8List>('thumbnail', {
        'uri': uri,
        'size': size,
      });
      _put(uri, bytes);
      return bytes;
    } on PlatformException {
      // Cached as a null so a file that has no thumbnail is not asked about
      // again on every rebuild.
      _put(uri, null);
      return null;
    }
  }

  void _put(String uri, Uint8List? bytes) {
    _entries.remove(uri);
    _entries[uri] = bytes;
    while (_entries.length > _maxEntries) {
      _entries.remove(_entries.keys.first);
    }
  }
}
