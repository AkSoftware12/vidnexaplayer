import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:docman/docman.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;

import '../../NotifyListeners/LanguageProvider/home_strings.dart';
import '../../NotifyListeners/LanguageProvider/language_provider.dart';
import '../../Utils/app_palette.dart';
import 'file_kind.dart';
import 'file_tools.dart';

/// Serves the granted folder over Wi-Fi so a PC on the same network can browse
/// and download from it in a browser.
///
/// Read-only on purpose. Accepting uploads would mean an unauthenticated
/// endpoint that writes into the user's storage for as long as the screen is
/// open, on whatever network they happen to be on. Downloads are the half of
/// "wireless transfer" that is worth having and cannot damage anything.
class WirelessTransferPage extends StatefulWidget {
  const WirelessTransferPage({super.key, this.accent = const Color(0xFF6C4DF6)});

  final Color accent;

  @override
  State<WirelessTransferPage> createState() => _WirelessTransferPageState();
}

class _WirelessTransferPageState extends State<WirelessTransferPage> {
  static const _prefsKey = 'file_browser_folders_tree_uri';
  static const _port = 8642;

  HttpServer? _server;
  DocumentFile? _root;

  /// Flat index of what is being served, built once when the server starts.
  ///
  /// Rebuilding it per request would mean a full SAF walk on every page load,
  /// and the browser asks for a favicon too.
  List<DocumentFile> _files = const [];

  bool _starting = false;
  String? _address;
  String? _error;
  int _hits = 0;

  String get _lang => context.read<LocaleProvider>().locale.languageCode;
  String _t(String key) => HomeStrings.t(_lang, key);

  @override
  void dispose() {
    // Not `unawaited(_stop())` — the server holds a socket, and leaving it
    // bound after the screen is gone means the next visit fails with
    // "address already in use".
    _server?.close(force: true);
    _server = null;
    super.dispose();
  }

  /// The device's own LAN address.
  ///
  /// From dart:io rather than a network-info plugin: `NetworkInterface.list`
  /// already reports every non-loopback IPv4, and the Wi-Fi one is the only
  /// address a PC on the same network can reach.
  Future<String?> _localIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      for (final i in interfaces) {
        for (final addr in i.addresses) {
          if (!addr.isLoopback) return addr.address;
        }
      }
    } catch (e) {
      debugPrint('localIp failed: $e');
    }
    return null;
  }

  Future<void> _start() async {
    if (_starting || _server != null) return;
    setState(() {
      _starting = true;
      _error = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefsKey);
      if (saved == null || saved.isEmpty) {
        throw _t('fb_scan_no_folder');
      }

      final root = await DocumentFile(uri: saved).get();
      if (root == null || !root.exists) throw _t('fb_scan_no_folder');
      _root = root;

      final walk = await FileTools.walk(root);
      _files = walk.files;

      final ip = await _localIp();
      if (ip == null) throw _t('fb_wifi_needed');

      final server = await shelf_io.serve(
        _handler,
        InternetAddress.anyIPv4,
        _port,
      );

      if (!mounted) {
        await server.close(force: true);
        return;
      }
      setState(() {
        _server = server;
        _address = 'http://$ip:$_port';
        _starting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _starting = false;
        _error = '$e';
      });
    }
  }

  Future<void> _stop() async {
    final server = _server;
    if (server == null) return;
    await server.close(force: true);
    if (!mounted) return;
    setState(() {
      _server = null;
      _address = null;
    });
  }

  Future<shelf.Response> _handler(shelf.Request request) async {
    if (mounted) setState(() => _hits++);

    final path = request.url.path;

    if (path.isEmpty || path == 'index.html') {
      return shelf.Response.ok(
        _indexHtml(),
        headers: {'content-type': 'text/html; charset=utf-8'},
      );
    }

    if (path.startsWith('f/')) {
      // The index position, not a name or a path: nothing the client sends is
      // ever turned into a storage lookup, so there is no traversal to guard
      // against — an out-of-range index is simply a 404.
      final index = int.tryParse(path.substring(2));
      if (index == null || index < 0 || index >= _files.length) {
        return shelf.Response.notFound('Not found');
      }

      final file = _files[index];
      try {
        final bytes = await file.read();
        if (bytes == null) return shelf.Response.notFound('Not found');
        return shelf.Response.ok(
          bytes,
          headers: {
            'content-type':
                file.type.isEmpty ? 'application/octet-stream' : file.type,
            'content-disposition':
                'attachment; filename="${Uri.encodeComponent(file.name)}"',
            'content-length': '${bytes.length}',
          },
        );
      } catch (e) {
        return shelf.Response.internalServerError(body: '$e');
      }
    }

    return shelf.Response.notFound('Not found');
  }

  String _indexHtml() {
    final rows = StringBuffer();
    for (var i = 0; i < _files.length; i++) {
      final f = _files[i];
      final name = const HtmlEscape().convert(f.name);
      rows.writeln(
        '<tr><td><a href="/f/$i">$name</a></td>'
        '<td class="s">${formatBytes(f.size)}</td></tr>',
      );
    }

    final title = const HtmlEscape().convert(_root?.name ?? 'Files');

    return '''
<!doctype html>
<html><head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>$title</title>
<style>
 body{font:15px system-ui,-apple-system,Segoe UI,Roboto,sans-serif;
      margin:0;background:#f6f7fb;color:#111827}
 header{background:#4f46e5;color:#fff;padding:18px 20px}
 h1{margin:0;font-size:18px}
 p{margin:4px 0 0;opacity:.85;font-size:13px}
 table{width:100%;border-collapse:collapse;background:#fff}
 td{padding:11px 20px;border-bottom:1px solid #eceef3}
 a{color:#4338ca;text-decoration:none;word-break:break-all}
 a:hover{text-decoration:underline}
 .s{text-align:right;color:#6b7280;font-size:13px;white-space:nowrap}
</style>
</head><body>
<header><h1>$title</h1><p>${_files.length} files &middot; tap to download</p></header>
<table>${rows.toString()}</table>
</body></html>
''';
  }

  @override
  Widget build(BuildContext context) {
    AppPalette.sync(context);
    final running = _server != null;

    return Scaffold(
      backgroundColor: AppPalette.surface,
      appBar: AppBar(
        backgroundColor: AppPalette.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppPalette.textH,
        title: Text(
          _t('fb_wireless'),
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 16.sp,
            fontWeight: FontWeight.w700,
            color: AppPalette.textH,
          ),
        ),
      ),
      body: Padding(
        padding: EdgeInsets.all(20.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: EdgeInsets.all(18.sp),
              decoration: BoxDecoration(
                color: AppPalette.card,
                borderRadius: BorderRadius.circular(18.r),
                border: Border.all(color: AppPalette.border),
              ),
              child: Column(
                children: [
                  Icon(
                    running ? Icons.wifi_tethering_rounded : Icons.wifi_off_rounded,
                    size: 44.sp,
                    color: running ? widget.accent : AppPalette.textS,
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    running ? _t('fb_wireless_on') : _t('fb_wireless_off'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                      color: AppPalette.textH,
                    ),
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    _t('fb_wireless_body'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11.sp,
                      height: 1.45,
                      color: AppPalette.textS,
                    ),
                  ),
                  if (_address != null) ...[
                    SizedBox(height: 14.h),
                    SelectableText(
                      _address!,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 17.sp,
                        fontWeight: FontWeight.w800,
                        color: widget.accent,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    TextButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _address!));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(_t('fb_copied'))),
                        );
                      },
                      icon: Icon(Icons.copy_rounded, size: 15.sp),
                      label: Text(
                        _t('fb_copy'),
                        style: TextStyle(fontSize: 11.sp),
                      ),
                    ),
                    Text(
                      _t('fb_wireless_stats')
                          .replaceAll('{files}', '${_files.length}')
                          .replaceAll('{hits}', '$_hits'),
                      style:
                          TextStyle(fontSize: 10.5.sp, color: AppPalette.textS),
                    ),
                  ],
                  if (_error != null) ...[
                    SizedBox(height: 12.h),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: Colors.red.shade700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(height: 18.h),
            SizedBox(
              height: 48.h,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: running ? Colors.red.shade600 : widget.accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                ),
                onPressed: _starting ? null : (running ? _stop : _start),
                icon: _starting
                    ? SizedBox(
                        height: 15.sp,
                        width: 15.sp,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(running ? Icons.stop_rounded : Icons.play_arrow_rounded,
                        size: 20.sp),
                label: Text(
                  running ? _t('fb_wireless_stop') : _t('fb_wireless_start'),
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
