import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

/// Serves the one local video being cast, over the Wi-Fi network.
///
/// A Chromecast plays from a URL — it cannot read a file on the phone — so
/// while casting, the phone runs this tiny HTTP server and hands the TV its
/// address. Deliberately minimal:
///
/// * **One file at a time.** Only the video currently on the TV is reachable;
///   publishing another replaces it, and [stop] shuts the server down.
/// * **Unguessable path.** The URL carries a fresh 128-bit random token, so
///   another device on the same Wi-Fi cannot list or fetch anything else, and
///   cannot fetch this file without the link the TV was given.
/// * **Range requests.** Cast receivers seek by asking for byte ranges; a
///   server that only sent whole files would make every seek restart the
///   download from the start.
/// * **Bound to the Wi-Fi address only**, never to mobile data.
///
/// `dart:io` rather than `shelf` (used by wireless transfer): shelf has no
/// Range support, and this needs nothing else.
class CastMediaServer {
  CastMediaServer._();

  static final CastMediaServer instance = CastMediaServer._();

  HttpServer? _server;
  String? _token;
  File? _file;
  String _mimeType = 'video/mp4';

  /// Makes [file] reachable to the TV and returns its URL, or null when the
  /// phone has no Wi-Fi address (casting needs the phone and the TV on the
  /// same network).
  Future<Uri?> publish(File file) async {
    final address = await _wifiAddress();
    if (address == null) return null;

    // Rebind if the network changed since the last cast.
    if (_server != null && _server!.address.address != address.address) {
      await stop();
    }
    if (_server == null) {
      final server = await HttpServer.bind(address, 0);
      server.listen(_handle, onError: (Object e) {
        debugPrint('CastMediaServer: $e');
      });
      _server = server;
    }

    _token = _randomToken();
    _file = file;
    _mimeType = mimeTypeFor(file.path);

    return Uri(
      scheme: 'http',
      host: address.address,
      port: _server!.port,
      pathSegments: [_token!, p.basename(file.path)],
    );
  }

  /// Stops serving. Safe to call when not running.
  Future<void> stop() async {
    _token = null;
    _file = null;
    final server = _server;
    _server = null;
    await server?.close(force: true);
  }

  /// MIME type the receiver is told to expect. Chromecast's default receiver
  /// plays MP4 and WebM reliably; Matroska plays on most current devices
  /// when its codecs are supported.
  static String mimeTypeFor(String path) {
    switch (p.extension(path).toLowerCase()) {
      case '.webm':
        return 'video/webm';
      case '.mkv':
        return 'video/x-matroska';
      case '.mov':
        return 'video/quicktime';
      case '.3gp':
        return 'video/3gpp';
      case '.ts':
        return 'video/mp2t';
      case '.m3u8':
        return 'application/x-mpegURL';
      case '.mpd':
        return 'application/dash+xml';
      default:
        return 'video/mp4';
    }
  }

  Future<void> _handle(HttpRequest request) async {
    final response = request.response;
    try {
      final file = _file;
      final segments = request.uri.pathSegments;
      final authorised = _token != null &&
          file != null &&
          segments.isNotEmpty &&
          segments.first == _token;
      final method = request.method;
      if (!authorised || (method != 'GET' && method != 'HEAD')) {
        response.statusCode = HttpStatus.notFound;
        await response.close();
        return;
      }

      final length = await file.length();
      var start = 0;
      var end = length - 1;
      var partial = false;

      final range = request.headers.value(HttpHeaders.rangeHeader);
      final match =
          range == null ? null : RegExp(r'bytes=(\d*)-(\d*)').firstMatch(range);
      if (match != null) {
        final from = match.group(1) ?? '';
        final to = match.group(2) ?? '';
        if (from.isEmpty && to.isNotEmpty) {
          // "bytes=-500": the last 500 bytes.
          start = (length - int.parse(to)).clamp(0, length);
        } else {
          start = int.tryParse(from) ?? 0;
          if (to.isNotEmpty) end = int.parse(to).clamp(0, length - 1);
        }
        if (start >= length || start > end) {
          response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
          response.headers.set(HttpHeaders.contentRangeHeader, 'bytes */$length');
          await response.close();
          return;
        }
        partial = true;
      }

      response.statusCode =
          partial ? HttpStatus.partialContent : HttpStatus.ok;
      response.headers
        ..contentType = ContentType.parse(_mimeType)
        ..contentLength = end - start + 1
        ..set(HttpHeaders.acceptRangesHeader, 'bytes')
        // The default receiver is a web page; some of its players fetch with
        // CORS. Harmless for the rest, and the token already gates access.
        ..set('Access-Control-Allow-Origin', '*');
      if (partial) {
        response.headers.set(
          HttpHeaders.contentRangeHeader,
          'bytes $start-$end/$length',
        );
      }

      if (method == 'HEAD') {
        await response.close();
        return;
      }
      await response.addStream(file.openRead(start, end + 1));
      await response.close();
    } catch (e) {
      // The TV abandons connections routinely when it seeks; not an error.
      try {
        await response.close();
      } catch (_) {}
    }
  }

  /// The phone's Wi-Fi IPv4 address. Prefers the `wlan` interface, then any
  /// private-range address; never a mobile-data one, which the TV could not
  /// reach anyway.
  static Future<InternetAddress?> _wifiAddress() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      InternetAddress? fallback;
      for (final interface in interfaces) {
        final name = interface.name.toLowerCase();
        if (name.startsWith('rmnet') || name.startsWith('ccmni')) continue;
        for (final address in interface.addresses) {
          if (address.isLoopback || !_isPrivate(address.address)) continue;
          if (name.startsWith('wlan') || name.startsWith('ap')) return address;
          fallback ??= address;
        }
      }
      return fallback;
    } catch (e) {
      debugPrint('CastMediaServer: no Wi-Fi address: $e');
      return null;
    }
  }

  static bool _isPrivate(String ip) {
    if (ip.startsWith('192.168.') || ip.startsWith('10.')) return true;
    final parts = ip.split('.');
    if (parts.length == 4 && parts[0] == '172') {
      final second = int.tryParse(parts[1]) ?? 0;
      return second >= 16 && second <= 31;
    }
    return false;
  }

  static String _randomToken() {
    final random = Random.secure();
    return List.generate(16, (_) => random.nextInt(256))
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
  }
}
