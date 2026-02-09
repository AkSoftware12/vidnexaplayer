import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';


class VidBrowserApp extends StatelessWidget {
  const VidBrowserApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "Downloader UI",
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFF8A00)),
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const HomeShell(),
    );
  }
}

/// --------------------
/// Simple in-memory store (for demo)
/// --------------------
class AppStore2 extends ChangeNotifier {
  final List<HistoryItem> history = [];
  final List<DownloadTask> downloads = [];

  void addHistory(String title, String url) {
    history.insert(0, HistoryItem(title: title, url: url, time: DateTime.now()));
    if (history.length > 200) history.removeLast();
    notifyListeners();
  }

  void clearHistory() {
    history.clear();
    notifyListeners();
  }

  void addDownload(DownloadTask t) {
    downloads.insert(0, t);
    notifyListeners();
  }

  void notify() => notifyListeners();
}

class HistoryItem {
  final String title;
  final String url;
  final DateTime time;
  HistoryItem({required this.title, required this.url, required this.time});
}

class DownloadTask {
  final String url;
  final String fileName;
  final String savePath;
  int received = 0;
  int total = 0;
  bool isDownloading = false;
  bool isDone = false;
  String? error;
  CancelToken cancelToken = CancelToken();

  DownloadTask({
    required this.url,
    required this.fileName,
    required this.savePath,
  });

  double get progress => total <= 0 ? 0 : (received / total);
}

/// --------------------
/// HOME SHELL with BottomNav (Screenshots jaisa)
/// --------------------
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  final AppStore2 store = AppStore2();
  int index = 0;

  final browserKey = GlobalKey<BrowserPageState>();

  void openInBrowser(String url) {
    setState(() => index = 1);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      browserKey.currentState?.loadUrl(url);
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      SitesPage(
        store: store,
        onOpenUrl: openInBrowser,
      ),
      BrowserPage(
        key: browserKey,
        store: store,
        onDownloadRequested: (directUrl) async {
          // direct file url download only
          await DownloadManager(store).startDownload(directUrl);
          setState(() => index = 2);
        },
      ),
      ProgressPage(store: store),
      StoragePage(store: store),
      HistoryPage(store: store),
    ];

    return Scaffold(
      body: pages[index],
      bottomNavigationBar: _BottomNav(
        index: index,
        onChanged: (i) => setState(() => index = i),
      ),
    );
  }
}

/// --------------------
/// Top common AppBar (crown pro + icons)
/// --------------------
PreferredSizeWidget commonTopBar(BuildContext context, {VoidCallback? onMore}) {
  return AppBar(
    elevation: 0.5,
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.white,
    leading: IconButton(
      onPressed: () {
        // If you want back behavior, you can handle per page.
        Navigator.maybePop(context);
      },
      icon: const Icon(Icons.arrow_back, color: Colors.black),
    ),
    centerTitle: true,
    title: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.emoji_events, color: Color(0xFFFFB300)),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFFFE2B6),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text(
            "Pro",
            style: TextStyle(
              color: Color(0xFFB35A00),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
      ],
    ),
    actions: [
      IconButton(
        onPressed: () {},
        icon: const Icon(Icons.download, color: Colors.black),
      ),
      IconButton(
        onPressed: () {},
        icon: const Icon(Icons.lock, color: Colors.black),
      ),
      IconButton(
        onPressed: onMore,
        icon: const Icon(Icons.more_vert, color: Colors.black),
      ),
    ],
  );
}

/// --------------------
/// Sites Page (Screenshot 1 jaisa)
/// --------------------
class SitesPage extends StatelessWidget {
  final AppStore2 store;
  final void Function(String url) onOpenUrl;

  SitesPage({super.key, required this.store, required this.onOpenUrl});

  final TextEditingController _search = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: commonTopBar(context, onMore: () => _showMoreSheet(context)),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          _AdBannerCard(),
          const SizedBox(height: 14),

          // Search bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.black12),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              children: [
                const Icon(Icons.g_mobiledata, size: 28),
                const SizedBox(width: 6),
                Expanded(
                  child: TextField(
                    controller: _search,
                    decoration: const InputDecoration(
                      hintText: "Search or type URL",
                      border: InputBorder.none,
                    ),
                    onSubmitted: (v) {
                      final url = normalizeUrl(v);
                      onOpenUrl(url);
                    },
                  ),
                ),
                IconButton(
                  onPressed: () {
                    final url = normalizeUrl(_search.text);
                    onOpenUrl(url);
                  },
                  icon: const Icon(Icons.search),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child: _BigPillButton(
                  color: const Color(0xFFFF2D55),
                  icon: Icons.video_library,
                  label: "Download Reels",
                  onTap: () {
                    // open IG (download extraction not included)
                    onOpenUrl("https://www.instagram.com/");
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _BigPillButton(
                  color: const Color(0xFF11B76D),
                  icon: Icons.chat,
                  label: "Status saver",
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Status saver UI demo. (Local file based feature can be added separately)"),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Recommended web link card (with gradient background like screenshot)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                colors: [Color(0xFFEFE8FF), Color(0xFFFFE8F0)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: Colors.black12),
            ),
            child: Column(
              children: [
                Row(
                  children: const [
                    Text(
                      "Recommended web link",
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                    Spacer(),
                    Icon(Icons.info_outline, size: 18),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 18,
                  runSpacing: 16,
                  children: [
                    _MiniIcon(label: "FB Watch", icon: Icons.play_circle, onTap: () => onOpenUrl("https://www.facebook.com/watch/")),
                    _MiniIcon(label: "Instagram", icon: Icons.camera_alt, onTap: () => onOpenUrl("https://www.instagram.com/")),
                    _MiniIcon(label: "Facebook", icon: Icons.facebook, onTap: () => onOpenUrl("https://www.facebook.com/")),
                    _MiniIcon(label: "Dailymotion", icon: Icons.donut_small, onTap: () => onOpenUrl("https://www.dailymotion.com/")),
                    _MiniIcon(label: "Twitter", icon: Icons.close, onTap: () => onOpenUrl("https://x.com/")),
                    _MiniIcon(label: "Vimeo", icon: Icons.videocam, onTap: () => onOpenUrl("https://vimeo.com/")),
                    _MiniIcon(label: "Play Games", icon: Icons.sports_esports, onTap: () => onOpenUrl("https://play.google.com/store/apps/category/GAME")),
                    _MiniIcon(label: "More Apps", icon: Icons.grid_view, onTap: () => onOpenUrl("https://play.google.com/")),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showMoreSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SheetTile(icon: Icons.person_add_alt_1, title: "Invite", onTap: () => Navigator.pop(context)),
              _SheetTile(icon: Icons.translate, title: "Language", onTap: () => Navigator.pop(context)),
              _SheetTile(icon: Icons.settings, title: "Settings", onTap: () => Navigator.pop(context)),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }
}

class _AdBannerCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white,
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        children: [
          Container(
            width: 120,
            height: 90,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.black12,
            ),
            alignment: Alignment.center,
            child: const Text("Ad", style: TextStyle(fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("ChatGPT", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Row(
                  children: const [
                    Chip(label: Text("Ad")),
                    SizedBox(width: 6),
                    Icon(Icons.star, size: 16, color: Colors.orange),
                    Icon(Icons.star, size: 16, color: Colors.orange),
                    Icon(Icons.star, size: 16, color: Colors.orange),
                    Icon(Icons.star, size: 16, color: Colors.orange),
                    Icon(Icons.star_half, size: 16, color: Colors.orange),
                  ],
                ),
                const Spacer(),
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    width: 140,
                    height: 42,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF2D87), Color(0xFFFF8A00)],
                      ),
                    ),
                    alignment: Alignment.center,
                    child: const Text("Install", style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white)),
                  ),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BigPillButton extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _BigPillButton({required this.color, required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        height: 62,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(18),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniIcon extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _MiniIcon({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: SizedBox(
        width: 78,
        child: Column(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.black12),
              ),
              child: Icon(icon, color: Colors.black87),
            ),
            const SizedBox(height: 6),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

/// --------------------
/// Browser Page (WebView + URL bar + "Download if direct link")
/// --------------------
class BrowserPage extends StatefulWidget {
  final AppStore2 store;
  final Future<void> Function(String directUrl) onDownloadRequested;

  const BrowserPage({
    super.key,
    required this.store,
    required this.onDownloadRequested,
  });

  @override
  State<BrowserPage> createState() => BrowserPageState();
}

class BrowserPageState extends State<BrowserPage> {
  final TextEditingController urlCtrl = TextEditingController(text: "https://www.google.com");
  InAppWebViewController? controller;
  double progress = 0;

  void loadUrl(String url) {
    urlCtrl.text = url;
    controller?.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
  }

  bool isDirectFileLink(String url) {
    final u = url.toLowerCase();
    return u.contains(".mp4") ||
        u.contains(".mkv") ||
        u.contains(".mp3") ||
        u.contains(".pdf") ||
        u.contains(".zip") ||
        u.contains(".jpg") ||
        u.contains(".png");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: commonTopBar(context, onMore: () => _showMoreSheet(context)),
      body: Column(
        children: [
          // URL bar
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: Colors.black12),
                color: Colors.white,
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_outline, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: urlCtrl,
                      decoration: const InputDecoration(border: InputBorder.none, hintText: "Search or type URL"),
                      onSubmitted: (v) => loadUrl(normalizeUrl(v)),
                    ),
                  ),
                  IconButton(
                    onPressed: () => loadUrl(normalizeUrl(urlCtrl.text)),
                    icon: const Icon(Icons.arrow_forward),
                  )
                ],
              ),
            ),
          ),

          if (progress < 1)
            LinearProgressIndicator(value: progress, minHeight: 2),

          Expanded(
            child: InAppWebView(
              initialUrlRequest: URLRequest(url: WebUri(urlCtrl.text)),
              onWebViewCreated: (c) => controller = c,
              onLoadStart: (c, url) {
                if (url != null) urlCtrl.text = url.toString();
              },
              onTitleChanged: (c, title) {
                final url = urlCtrl.text;
                if (title != null && title.trim().isNotEmpty) {
                  widget.store.addHistory(title.trim(), url);
                }
              },
              onProgressChanged: (c, p) => setState(() => progress = p / 100),
            ),
          ),

          // Bottom action bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Colors.black12)),
              color: Colors.white,
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => controller?.goBack(),
                  icon: const Icon(Icons.arrow_back),
                ),
                IconButton(
                  onPressed: () => controller?.reload(),
                  icon: const Icon(Icons.refresh),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () async {
                    final current = urlCtrl.text.trim();
                    if (!isDirectFileLink(current)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Download sirf direct file link (.mp4/.pdf etc) pe hoga.")),
                      );
                      return;
                    }
                    await widget.onDownloadRequested(current);
                  },
                  icon: const Icon(Icons.download),
                  label: const Text("Download"),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  void _showMoreSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SheetTile(icon: Icons.person_add_alt_1, title: "Invite", onTap: () => Navigator.pop(context)),
              _SheetTile(icon: Icons.translate, title: "Language", onTap: () => Navigator.pop(context)),
              _SheetTile(icon: Icons.settings, title: "Settings", onTap: () => Navigator.pop(context)),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }
}

/// --------------------
/// Progress Page (downloads list)
/// --------------------
class ProgressPage extends StatelessWidget {
  final AppStore2 store;
  const ProgressPage({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: commonTopBar(context),
      body: AnimatedBuilder(
        animation: store,
        builder: (_, __) {
          if (store.downloads.isEmpty) {
            return const Center(child: Text("No downloads yet"));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(14),
            itemCount: store.downloads.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final d = store.downloads[i];
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.black12),
                  color: Colors.white,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d.fileName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(value: d.isDone ? 1 : d.progress),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          d.isDone
                              ? "Completed"
                              : "${formatBytes(d.received)} / ${d.total <= 0 ? "?" : formatBytes(d.total)}",
                          style: const TextStyle(color: Colors.black54, fontSize: 12),
                        ),
                        const Spacer(),
                        if (d.isDone)
                          IconButton(
                            onPressed: () => OpenFilex.open(d.savePath),
                            icon: const Icon(Icons.open_in_new),
                          ),
                        if (d.isDone)
                          IconButton(
                            onPressed: () => Share.shareXFiles([XFile(d.savePath)]),
                            icon: const Icon(Icons.share),
                          ),
                      ],
                    ),
                    if (d.error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text("Error: ${d.error}", style: const TextStyle(color: Colors.red)),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// --------------------
/// Storage Page (downloaded files list)
/// --------------------
class StoragePage extends StatelessWidget {
  final AppStore2 store;
  const StoragePage({super.key, required this.store});

  Future<List<FileSystemEntity>> _listFiles() async {
    final dir = await DownloadManager.getDownloadDir();
    if (!await dir.exists()) return [];
    final all = dir.listSync().whereType<File>().toList();
    all.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    return all;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: commonTopBar(context),
      body: FutureBuilder<List<FileSystemEntity>>(
        future: _listFiles(),
        builder: (_, snap) {
          final files = snap.data ?? [];
          if (files.isEmpty) {
            return const Center(child: Text("No saved files"));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(14),
            itemCount: files.length,
            itemBuilder: (_, i) {
              final f = files[i] as File;
              final name = f.path.split('/').last;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.black12),
                  color: Colors.white,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: Colors.black12,
                      ),
                      child: const Icon(Icons.insert_drive_file),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                    IconButton(onPressed: () => OpenFilex.open(f.path), icon: const Icon(Icons.open_in_new)),
                    IconButton(onPressed: () => Share.shareXFiles([XFile(f.path)]), icon: const Icon(Icons.share)),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// --------------------
/// History Page (Screenshot 2/3 jaisa)
/// --------------------
class HistoryPage extends StatelessWidget {
  final AppStore2 store;
  const HistoryPage({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: commonTopBar(context, onMore: () => _showMoreSheet(context)),
      body: AnimatedBuilder(
        animation: store,
        builder: (_, __) {
          return ListView(
            padding: const EdgeInsets.all(14),
            children: [
              // Recent downloads grid (demo thumbnails)
              Row(
                children: [
                  const Text("Recent downloads", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  const Spacer(),
                  IconButton(onPressed: () {}, icon: const Icon(Icons.arrow_forward)),
                ],
              ),
              const SizedBox(height: 10),
              _RecentGrid(),

              const SizedBox(height: 18),
              const Text("Bookmarks", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 10),
              Row(
                children: const [
                  _BookmarkIcon(label: "Faceb...", icon: Icons.facebook),
                  SizedBox(width: 14),
                  _BookmarkIcon(label: "Google", icon: Icons.g_mobiledata),
                  SizedBox(width: 14),
                  _BookmarkIcon(label: "Vimeo", icon: Icons.videocam),
                  SizedBox(width: 14),
                  _BookmarkIcon(label: "More", icon: Icons.add),
                ],
              ),

              const SizedBox(height: 18),
              Row(
                children: [
                  const Text("History", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  const Spacer(),
                  IconButton(onPressed: store.clearHistory, icon: const Icon(Icons.arrow_forward)),
                ],
              ),
              const SizedBox(height: 6),
              TextButton(
                onPressed: store.clearHistory,
                style: TextButton.styleFrom(foregroundColor: Colors.black54),
                child: const Align(alignment: Alignment.centerLeft, child: Text("Clear history")),
              ),

              _AdStrip(),

              // History list
              ...store.history.take(20).map((h) => _HistoryRow(item: h)).toList(),
            ],
          );
        },
      ),
    );
  }

  void _showMoreSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SheetTile(icon: Icons.person_add_alt_1, title: "Invite", onTap: () => Navigator.pop(context)),
              _SheetTile(icon: Icons.translate, title: "Language", onTap: () => Navigator.pop(context)),
              _SheetTile(icon: Icons.settings, title: "Settings", onTap: () => Navigator.pop(context)),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }
}

class _RecentGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Demo thumbnails (placeholders)
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 6,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.05,
      ),
      itemBuilder: (_, __) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Container(color: Colors.black12),
        );
      },
    );
  }
}

class _BookmarkIcon extends StatelessWidget {
  final String label;
  final IconData icon;
  const _BookmarkIcon({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.black12),
            borderRadius: BorderRadius.circular(26),
          ),
          child: Icon(icon, color: Colors.black87),
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

class _AdStrip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
        color: Colors.white,
      ),
      child: Row(
        children: [
          const CircleAvatar(child: Icon(Icons.auto_awesome)),
          const SizedBox(width: 10),
          const Expanded(
            child: Text("ChatGPT\nIntroducing ChatGPT for Android", maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.black26)),
            child: const Text("Install", style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final HistoryItem item;
  const _HistoryRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(20)),
            child: const Icon(Icons.language, color: Colors.black54),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(item.url, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.black54, fontSize: 12)),
              ],
            ),
          ),
          IconButton(onPressed: () {}, icon: const Icon(Icons.close, color: Colors.black54)),
        ],
      ),
    );
  }
}

/// --------------------
/// Download Manager (direct-file links only)
/// --------------------
class DownloadManager {
  final AppStore2 store;
  final Dio dio = Dio();

  DownloadManager(this.store);

  static Future<Directory> getDownloadDir() async {
    final base = await getApplicationDocumentsDirectory();
    final d = Directory("${base.path}/downloads");
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  String guessFileName(String url) {
    try {
      final u = Uri.parse(url);
      final last = u.pathSegments.isNotEmpty ? u.pathSegments.last : "";
      if (last.isNotEmpty && last.contains(".")) return last.split("?").first;
    } catch (_) {}
    return "file_${DateTime.now().millisecondsSinceEpoch}.bin";
  }

  Future<void> startDownload(String url) async {
    final dir = await getDownloadDir();
    final name = guessFileName(url);
    final path = "${dir.path}/$name";

    final task = DownloadTask(url: url, fileName: name, savePath: path);
    task.isDownloading = true;
    store.addDownload(task);

    try {
      await dio.download(
        url,
        path,
        cancelToken: task.cancelToken,
        deleteOnError: true,
        options: Options(
          headers: {"User-Agent": "Mozilla/5.0"},
          followRedirects: true,
          receiveTimeout: const Duration(minutes: 10),
          sendTimeout: const Duration(minutes: 10),
        ),
        onReceiveProgress: (rec, total) {
          task.received = rec;
          task.total = total;
          store.notify();
        },
      );

      task.isDownloading = false;
      task.isDone = true;
      store.notify();
    } catch (e) {
      task.isDownloading = false;
      task.error = e.toString();
      store.notify();
    }
  }
}

/// --------------------
/// Bottom Nav (Screenshots jaisa)
/// --------------------
class _BottomNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;
  const _BottomNav({required this.index, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const active = Color(0xFFFF8A00);
    return NavigationBar(
      selectedIndex: index,
      onDestinationSelected: onChanged,
      indicatorColor: active.withOpacity(0.12),
      destinations: const [
        NavigationDestination(icon: Icon(Icons.local_fire_department), label: "Sites"),
        NavigationDestination(icon: Icon(Icons.public), label: "Browser"),
        NavigationDestination(icon: Icon(Icons.check_circle_outline), label: "Progress"),
        NavigationDestination(icon: Icon(Icons.folder_copy_outlined), label: "Storage"),
        NavigationDestination(icon: Icon(Icons.history), label: "History"),
      ],
    );
  }
}

/// --------------------
/// small UI helpers
/// --------------------
class _SheetTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  const _SheetTile({required this.icon, required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}

String normalizeUrl(String input) {
  var t = input.trim();
  if (t.isEmpty) return "https://www.google.com";
  if (!t.startsWith("http://") && !t.startsWith("https://")) {
    // if it's a domain, add https
    if (t.contains(".") && !t.contains(" ")) {
      t = "https://$t";
    } else {
      // treat as search query
      t = "https://www.google.com/search?q=${Uri.encodeComponent(t)}";
    }
  }
  return t;
}

String formatBytes(int bytes) {
  if (bytes <= 0) return "0 B";
  const s = ["B", "KB", "MB", "GB"];
  double size = bytes.toDouble();
  int i = 0;
  while (size >= 1024 && i < s.length - 1) {
    size /= 1024;
    i++;
  }
  return "${size.toStringAsFixed(1)} ${s[i]}";
}
