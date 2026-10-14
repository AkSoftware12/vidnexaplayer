import 'package:material_ui/material_ui.dart';
import 'package:flutter_chrome_cast/flutter_chrome_cast.dart';

import '../../NotifyListeners/LanguageProvider/video_strings.dart';
import 'cast_controller.dart';

/// Lists the Chromecast / Google TV devices on this Wi-Fi and returns the one
/// tapped, or null if dismissed.
///
/// Discovery runs only while the sheet is open — it keeps the Wi-Fi radio
/// busy, so it is not left running in the background.
Future<GoogleCastDevice?> showCastDeviceSheet(
  BuildContext context, {
  required String lang,
}) {
  return showModalBottomSheet<GoogleCastDevice>(
    context: context,
    backgroundColor: const Color(0xFF1C1C1E),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (_) => _CastDeviceSheet(lang: lang),
  );
}

class _CastDeviceSheet extends StatefulWidget {
  const _CastDeviceSheet({required this.lang});

  final String lang;

  @override
  State<_CastDeviceSheet> createState() => _CastDeviceSheetState();
}

class _CastDeviceSheetState extends State<_CastDeviceSheet> {
  final CastController _cast = CastController.instance;

  String _t(String key) => VideoStrings.t(widget.lang, key);

  @override
  void initState() {
    super.initState();
    _cast.startDiscovery();
  }

  @override
  void dispose() {
    _cast.stopDiscovery();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              _t('cast_title'),
              style: const TextStyle(
                fontFamily: 'Poppins',
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _t('cast_same_wifi'),
              style: const TextStyle(
                fontFamily: 'Poppins',
                color: Colors.white60,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 10),
            StreamBuilder<List<GoogleCastDevice>>(
              stream: _cast.devicesStream,
              initialData: _cast.devices,
              builder: (context, snapshot) {
                final devices = snapshot.data ?? const <GoogleCastDevice>[];
                if (devices.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 22),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            _t('cast_searching'),
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.5,
                  ),
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final device in devices)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.tv_rounded,
                              color: Colors.white),
                          title: Text(
                            device.friendlyName,
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: device.modelName == null
                              ? null
                              : Text(
                                  device.modelName!,
                                  style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    color: Colors.white54,
                                    fontSize: 11.5,
                                  ),
                                ),
                          onTap: () => Navigator.pop(context, device),
                        ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown over the video area while it plays on a TV: what is playing where,
/// remote play/pause and ±10 s, and the way back to the phone.
class CastingPanel extends StatelessWidget {
  const CastingPanel({
    super.key,
    required this.lang,
    required this.title,
    required this.onStop,
  });

  final String lang;
  final String title;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final cast = CastController.instance;
    String t(String key) => VideoStrings.t(lang, key);

    return ColoredBox(
      color: Colors.black,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cast_connected_rounded,
                    color: Colors.white, size: 54),
                const SizedBox(height: 14),
                Text(
                  t('cast_playing_on')
                      .replaceAll('{device}', cast.deviceName ?? ''),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    color: Colors.white60,
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 18),
                StreamBuilder<Duration>(
                  stream: cast.remote.playerPositionStream,
                  builder: (context, snapshot) {
                    final position = snapshot.data ?? Duration.zero;
                    final duration =
                        cast.remote.mediaStatus?.mediaInformation?.duration;
                    return Text(
                      duration == null || duration == Duration.zero
                          ? _format(position)
                          : '${_format(position)} / ${_format(duration)}',
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      iconSize: 34,
                      color: Colors.white,
                      icon: const Icon(Icons.replay_10_rounded),
                      onPressed: () =>
                          cast.seekBy(const Duration(seconds: -10)),
                    ),
                    const SizedBox(width: 12),
                    StreamBuilder<GoggleCastMediaStatus?>(
                      stream: cast.remote.mediaStatusStream,
                      initialData: cast.remote.mediaStatus,
                      builder: (context, snapshot) {
                        final playing = snapshot.data?.playerState ==
                            CastMediaPlayerState.playing;
                        return IconButton(
                          iconSize: 54,
                          color: Colors.white,
                          icon: Icon(playing
                              ? Icons.pause_circle_filled_rounded
                              : Icons.play_circle_fill_rounded),
                          onPressed: cast.togglePlayPause,
                        );
                      },
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      iconSize: 34,
                      color: Colors.white,
                      icon: const Icon(Icons.forward_10_rounded),
                      onPressed: () => cast.seekBy(const Duration(seconds: 10)),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                OutlinedButton.icon(
                  onPressed: onStop,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white38),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 11,
                    ),
                  ),
                  icon: const Icon(Icons.cast_rounded, size: 18),
                  label: Text(
                    t('cast_stop'),
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _format(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    return hours > 0
        ? '$hours:${two(minutes)}:${two(seconds)}'
        : '${two(minutes)}:${two(seconds)}';
  }
}
