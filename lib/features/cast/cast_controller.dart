import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_chrome_cast/flutter_chrome_cast.dart';
import 'package:path/path.dart' as p;

import 'cast_media_server.dart';

/// Why a cast could not start — each maps to one message for the user.
enum CastFailure {
  /// No Google Play Services / Cast framework on this phone.
  unavailable,

  /// The phone is not on Wi-Fi, so the TV could not reach the video.
  noWifi,

  /// The TV did not accept the connection in time.
  connectFailed,

  /// Connected, but the TV refused or could not play the video.
  loadFailed,
}

/// Plays the current video on a Chromecast / Google TV.
///
/// Replaces screen mirroring as the way to watch on a TV. Mirroring makes
/// Android capture and re-encode the whole screen, which is where the lag
/// came from; casting sends the video itself and the TV decodes it natively.
///
/// Wraps `flutter_chrome_cast` (Google's Cast SDK) so the player only deals
/// with four calls: [ensureReady], [castTo], [stop] and the remote controls.
/// The Cast SDK is started lazily on the first cast tap, never at app launch:
/// on a phone without Play Services that is where it fails, and app start is
/// the wrong place to find out.
class CastController extends ChangeNotifier {
  CastController._();

  static final CastController instance = CastController._();

  static const _connectTimeout = Duration(seconds: 20);

  bool _initialised = false;
  bool _available = false;

  String? _deviceName;

  /// Name of the TV being cast to, or null when not casting.
  String? get deviceName => _deviceName;
  bool get isCasting => _deviceName != null;

  GoogleCastRemoteMediaClientPlatformInterface get remote =>
      GoogleCastRemoteMediaClient.instance;

  Stream<List<GoogleCastDevice>> get devicesStream =>
      GoogleCastDiscoveryManager.instance.devicesStream;

  List<GoogleCastDevice> get devices =>
      GoogleCastDiscoveryManager.instance.devices;

  StreamSubscription<GoogleCastSession?>? _sessionSub;

  /// Starts the Cast SDK once. False when this phone cannot cast.
  Future<bool> ensureReady() async {
    if (_initialised) return _available;
    _initialised = true;
    if (!Platform.isAndroid) return _available = false;
    try {
      _available = await GoogleCastContext.instance.setSharedInstanceWithOptions(
        GoogleCastOptionsAndroid(
          appId: GoogleCastDiscoveryCriteria.kDefaultApplicationId,
          // The video is served from this phone, so it cannot outlive the app.
          stopCastingOnAppTerminated: true,
        ),
      );
    } catch (e) {
      debugPrint('Cast unavailable: $e');
      _available = false;
    }
    return _available;
  }

  Future<void> startDiscovery() async {
    try {
      await GoogleCastDiscoveryManager.instance.startDiscovery();
    } catch (e) {
      debugPrint('Cast discovery failed: $e');
    }
  }

  Future<void> stopDiscovery() async {
    try {
      await GoogleCastDiscoveryManager.instance.stopDiscovery();
    } catch (_) {}
  }

  /// Connects to [device] and starts [source] there at [position].
  ///
  /// [source] is what the local player opened: a file path or an http(s)
  /// URL. A URL is handed to the TV as-is; a file is served from the phone
  /// by [CastMediaServer]. Returns null on success.
  Future<CastFailure?> castTo(
    GoogleCastDevice device, {
    required String source,
    required String title,
    required Duration position,
  }) async {
    final Uri? url;
    final String contentType;
    if (source.startsWith('http://') || source.startsWith('https://')) {
      url = Uri.tryParse(source);
      contentType = CastMediaServer.mimeTypeFor(Uri.parse(source).path);
    } else {
      final path = source.startsWith('file://')
          ? Uri.parse(source).toFilePath()
          : source;
      url = await CastMediaServer.instance.publish(File(path));
      contentType = CastMediaServer.mimeTypeFor(path);
    }
    if (url == null) return CastFailure.noWifi;

    try {
      final sessions = GoogleCastSessionManager.instance;
      if (sessions.connectionState != GoogleCastConnectState.connected) {
        await sessions.startSessionWithDevice(device);
        final connected = await _waitForConnection();
        if (!connected) {
          await CastMediaServer.instance.stop();
          return CastFailure.connectFailed;
        }
      }

      await remote.loadMedia(
        GoogleCastMediaInformationAndroid(
          contentId: url.toString(),
          contentUrl: url,
          contentType: contentType,
          streamType: CastMediaStreamType.buffered,
          metadata: GoogleCastGenericMediaMetadataAndroid(
            title: title.isEmpty ? p.basename(source) : title,
            subtitle: 'Vidnexa Player',
            images: const [],
          ),
        ),
        autoPlay: true,
        playPosition: position,
      );
    } catch (e) {
      debugPrint('Cast load failed: $e');
      await _endSession();
      return CastFailure.loadFailed;
    }

    _deviceName = device.friendlyName;
    _watchSession();
    notifyListeners();
    return null;
  }

  /// Ends casting and returns where the TV had got to, so the phone can carry
  /// on from there.
  Future<Duration> stop() async {
    Duration position = Duration.zero;
    try {
      position = remote.playerPosition;
    } catch (_) {}
    await _endSession();
    return position;
  }

  Future<void> togglePlayPause() async {
    try {
      final playing =
          remote.mediaStatus?.playerState == CastMediaPlayerState.playing;
      playing ? await remote.pause() : await remote.play();
    } catch (e) {
      debugPrint('Cast play/pause failed: $e');
    }
  }

  Future<void> seekBy(Duration offset) async {
    try {
      await remote.seek(GoogleCastMediaSeekOption(
        position: offset,
        relative: true,
      ));
    } catch (e) {
      debugPrint('Cast seek failed: $e');
    }
  }

  Future<void> seekTo(Duration position) async {
    try {
      await remote.seek(GoogleCastMediaSeekOption(position: position));
    } catch (e) {
      debugPrint('Cast seek failed: $e');
    }
  }

  Future<bool> _waitForConnection() async {
    final sessions = GoogleCastSessionManager.instance;
    if (sessions.connectionState == GoogleCastConnectState.connected) {
      return true;
    }
    try {
      await sessions.currentSessionStream
          .firstWhere((_) =>
              sessions.connectionState == GoogleCastConnectState.connected)
          .timeout(_connectTimeout);
      return true;
    } catch (_) {
      return sessions.connectionState == GoogleCastConnectState.connected;
    }
  }

  /// Notices the session ending from the other side — the TV's remote, the
  /// Cast notification, Wi-Fi dropping — so the player can take back over.
  void _watchSession() {
    _sessionSub?.cancel();
    _sessionSub =
        GoogleCastSessionManager.instance.currentSessionStream.listen((_) {
      if (GoogleCastSessionManager.instance.connectionState ==
              GoogleCastConnectState.disconnected &&
          _deviceName != null) {
        _deviceName = null;
        unawaited(CastMediaServer.instance.stop());
        notifyListeners();
      }
    });
  }

  Future<void> _endSession() async {
    _sessionSub?.cancel();
    _sessionSub = null;
    try {
      await GoogleCastSessionManager.instance.endSessionAndStopCasting();
    } catch (_) {}
    await CastMediaServer.instance.stop();
    if (_deviceName != null) {
      _deviceName = null;
      notifyListeners();
    }
  }
}
