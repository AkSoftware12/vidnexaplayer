import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../domain/repositories/gallery_repository.dart';

/// One photo tile.
///
/// Reads bytes through the repository's bounded LRU, so a tile scrolled out of
/// view and back gets a cache hit rather than a fresh decode.
///
/// [repository] is handed in rather than looked up from the context, and that
/// is not a style choice. The grid wraps every tile in a `Hero`, and for the
/// duration of a flight Flutter re-mounts the hero's child inside the
/// Navigator's overlay — which sits *above* the route that provides the
/// repository. A `context.read` in `initState` therefore threw
/// `ProviderNotFoundError` on every tap that opened the viewer. A constructor
/// argument is captured where the widget is built, so the flight copy carries
/// it with it.
///
/// It is also deliberately not a `watch` on the controller: a tile that
/// rebuilt whenever selection or paging notified would re-run this load for
/// every visible thumbnail on each tap.
class PhotoThumbnail extends StatefulWidget {
  const PhotoThumbnail({
    super.key,
    required this.repository,
    required this.photoId,
    required this.pixelSize,
    this.fit = BoxFit.cover,
  });

  final GalleryRepository repository;
  final String photoId;
  final int pixelSize;
  final BoxFit fit;

  @override
  State<PhotoThumbnail> createState() => _PhotoThumbnailState();
}

class _PhotoThumbnailState extends State<PhotoThumbnail> {
  Uint8List? _bytes;
  bool _failed = false;

  /// Guards against a stale response overwriting a newer one when the tile is
  /// recycled onto a different photo mid-load.
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant PhotoThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photoId != widget.photoId ||
        oldWidget.pixelSize != widget.pixelSize) {
      _bytes = null;
      _failed = false;
      _load();
    }
  }

  Future<void> _load() async {
    final request = ++_request;
    try {
      final bytes =
          await widget.repository.thumbnail(widget.photoId, widget.pixelSize);
      if (!mounted || request != _request) return;
      setState(() {
        _bytes = bytes;
        _failed = bytes == null;
      });
    } catch (_) {
      if (!mounted || request != _request) return;
      setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;
    if (bytes != null) {
      return Image.memory(
        bytes,
        fit: widget.fit,
        width: double.infinity,
        height: double.infinity,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => const _ThumbnailPlaceholder(broken: true),
      );
    }
    return _ThumbnailPlaceholder(broken: _failed);
  }
}

class _ThumbnailPlaceholder extends StatelessWidget {
  const _ThumbnailPlaceholder({this.broken = false});

  final bool broken;

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).brightness == Brightness.dark
        ? Colors.white10
        : Colors.black12;

    return Container(
      color: surface,
      alignment: Alignment.center,
      child: broken
          ? Icon(
              Icons.image_not_supported_outlined,
              size: 20,
              color: Colors.grey.shade500,
            )
          : null,
    );
  }
}
