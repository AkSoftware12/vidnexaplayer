import 'package:flutter/material.dart';

import 'playback_position_store.dart';

/// Thin "how much of this video was watched" line, drawn along the bottom edge
/// of a thumbnail (YouTube-style).
///
/// Renders nothing when the video has never been started, was only watched for
/// a few seconds, or was watched to the end — [PlaybackPositionStore] drops the
/// entry in all three cases, so a finished video shows a clean thumbnail again.
///
/// Reads the store's in-memory cache synchronously and rebuilds through
/// `PlaybackPositionStore.revision`, so scrolling a long list costs no async
/// work and returning from the player updates the line immediately.
class WatchProgressBar extends StatefulWidget {
  /// `AssetEntity.id` for a local video, the link for a stream.
  final String id;

  /// Used only when the stored entry has no duration of its own.
  final Duration? fallbackDuration;

  final double height;
  final BorderRadius? borderRadius;

  const WatchProgressBar({
    super.key,
    required this.id,
    this.fallbackDuration,
    this.height = 3,
    this.borderRadius,
  });

  @override
  State<WatchProgressBar> createState() => _WatchProgressBarState();
}

class _WatchProgressBarState extends State<WatchProgressBar> {
  @override
  void initState() {
    super.initState();
    // Completing this bumps `revision`, which rebuilds every visible bar.
    PlaybackPositionStore.ensureLoaded();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: PlaybackPositionStore.revision,
      builder: (context, _, __) {
        final progress = PlaybackPositionStore.progressOf(
          widget.id,
          fallbackDuration: widget.fallbackDuration,
        );
        if (progress == null || progress <= 0) {
          return const SizedBox.shrink();
        }

        final bar = SizedBox(
          height: widget.height,
          child: Stack(
            children: [
              Container(color: Colors.white.withValues(alpha: 0.28)),
              FractionallySizedBox(
                widthFactor: progress,
                child: Container(color: const Color(0xFFFF8A00)),
              ),
            ],
          ),
        );

        final radius = widget.borderRadius;
        return radius == null ? bar : ClipRRect(borderRadius: radius, child: bar);
      },
    );
  }
}
