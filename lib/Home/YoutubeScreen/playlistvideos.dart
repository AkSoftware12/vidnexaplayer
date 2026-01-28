import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../Utils/color.dart';

/// ✅ Playlist videos screen with Hive cache (per playlist 24 hours me 1 bar API hit)
/// Requirement:
/// main.dart me:
///   await Hive.initFlutter();
///   await Hive.openBox('yt_cache');

class YouTubePlaylistVideos extends StatefulWidget {
  final String playlistId;
  final String playlistTitle;
  final String apiKey;

  const YouTubePlaylistVideos({
    super.key,
    required this.playlistId,
    required this.playlistTitle,
    required this.apiKey,
  });

  @override
  State<YouTubePlaylistVideos> createState() => _YouTubePlaylistVideosState();
}

class _YouTubePlaylistVideosState extends State<YouTubePlaylistVideos> {
  final Box _box = Hive.box('yt_cache');

  static const Duration _cacheDuration = Duration(hours: 24);

  // ✅ cache keys will be unique per playlistId
  String get _cacheKey => "yt_playlist_items_${widget.playlistId}";
  String get _cacheTimeKey => "yt_playlist_items_time_${widget.playlistId}";

  List videos = [];
  bool isLoading = true;
  bool isGridView = false;

  @override
  void initState() {
    super.initState();
    _initAndFetch();
  }

  Future<void> _initAndFetch() async {
    try {
      // ✅ 1) Load cache first (no API hit)
      final loaded = await _loadFromCacheIfValid();

      // ✅ 2) If cache invalid/empty => hit API once
      if (!loaded) {
        await fetchVideos();
        await _saveCache();
      }
    } catch (e) {
      debugPrint("_initAndFetch error: $e");
      // fallback to API
      await fetchVideos();
      await _saveCache();
    }

    if (mounted) setState(() => isLoading = false);
  }

  /// ✅ Load cache if within 24 hours
  Future<bool> _loadFromCacheIfValid() async {
    final String? cacheJson = _box.get(_cacheKey);
    final int? lastTimeMs = _box.get(_cacheTimeKey);

    if (cacheJson == null || lastTimeMs == null) return false;

    final lastTime = DateTime.fromMillisecondsSinceEpoch(lastTimeMs);
    final diff = DateTime.now().difference(lastTime);

    if (diff > _cacheDuration) return false; // expired

    final decoded = json.decode(cacheJson);
    if (decoded is! List) return false;

    setState(() {
      videos = decoded;
    });

    return true;
  }

  /// ✅ Save cache after successful fetch
  Future<void> _saveCache() async {
    final String jsonString = json.encode(videos);
    await _box.put(_cacheKey, jsonString);
    await _box.put(_cacheTimeKey, DateTime.now().millisecondsSinceEpoch);
  }

  /// ✅ Optional: manual force refresh (pull-to-refresh)
  Future<void> forceRefresh() async {
    setState(() => isLoading = true);
    //

    if (mounted) setState(() => isLoading = false);
  }

  Future<void> fetchVideos() async {
    final url = Uri.parse(
      'https://www.googleapis.com/youtube/v3/playlistItems'
          '?part=snippet,contentDetails'
          '&playlistId=${widget.playlistId}'
          '&maxResults=20'
          '&key=${widget.apiKey}',
    );

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final items = data["items"] as List? ?? [];

        setState(() {
          videos = items;
        });
      } else {
        debugPrint("API error ${response.statusCode}: ${response.body}");
        setState(() {
          videos = [];
        });
      }
    } catch (e) {
      debugPrint("fetchVideos error: $e");
      setState(() {
        videos = [];
      });
    }
  }

  Future<void> _openYoutube(String videoId) async {
    final Uri youtubeUrl = Uri.parse('https://www.youtube.com/watch?v=$videoId');

    // ✅ Better launch options
    final ok = await launchUrl(
      youtubeUrl,
      mode: LaunchMode.externalApplication,
    );

    if (!ok) {
      throw Exception('Could not launch $youtubeUrl');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        iconTheme:  IconThemeData(color: Colors.white),
        title: Text(
          widget.playlistTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style:  TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 14.sp
          ),
        ),
        backgroundColor: ColorSelect.maineColor,
        elevation: 4,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => setState(() => isGridView = !isGridView),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.35),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  transitionBuilder: (child, animation) =>
                      ScaleTransition(scale: animation, child: child),
                  child: Icon(
                    isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded,
                    key: ValueKey(isGridView),
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ),
          ),
        ],

      ),

      // ✅ Pull to refresh = force API fetch + update cache
      body: RefreshIndicator(
        onRefresh: forceRefresh,
        child: isLoading
            ? ListView(
          children: const [
            SizedBox(height: 220),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.redAccent),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Loading videos...',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        )
            : (videos.isEmpty
            ? ListView(
          children: const [
            SizedBox(height: 220),
            Center(
              child: Text(
                "No videos found",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        )
            : (isGridView ? _buildGrid() : _buildList())),
      ),
    );
  }

  Widget _buildGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(3),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.95,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: videos.length,
      itemBuilder: (context, index) {
        final video = videos[index] as Map<String, dynamic>;
        final snippet = (video["snippet"] ?? {}) as Map<String, dynamic>;

        final title = (snippet["title"] ?? "").toString();
        final channelTitle = (snippet["channelTitle"] ?? "").toString();

        final thumbs = (snippet["thumbnails"] ?? {}) as Map<String, dynamic>;
        final medium = (thumbs["medium"] ?? {}) as Map<String, dynamic>;
        final thumbnail = (medium["url"] ?? "").toString();

        final resource = (snippet["resourceId"] ?? {}) as Map<String, dynamic>;
        final videoId = (resource["videoId"] ?? "").toString();

        if (videoId.isEmpty) return const SizedBox.shrink();

        return Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
          child: InkWell(
            onTap: () => _openYoutube(videoId),
            borderRadius: BorderRadius.circular(5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
                        child: thumbnail.isEmpty
                            ? Container(
                          color: Colors.grey[300],
                          child: const Icon(Icons.video_library_outlined, color: Colors.grey, size: 50),
                        )
                            : Image.network(
                          thumbnail,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          errorBuilder: (_, __, ___) => Container(
                            color: Colors.grey[300],
                            child: const Icon(Icons.broken_image, color: Colors.grey, size: 50),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.play_arrow, color: Colors.white, size: 20),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        channelTitle,
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildList() {
    return ListView.builder(
      padding: const EdgeInsets.all(5),
      itemCount: videos.length,
      itemBuilder: (context, index) {
        final video = videos[index] as Map<String, dynamic>;
        final snippet = (video["snippet"] ?? {}) as Map<String, dynamic>;

        final title = (snippet["title"] ?? "").toString();
        final channelTitle = (snippet["channelTitle"] ?? "").toString();

        final thumbs = (snippet["thumbnails"] ?? {}) as Map<String, dynamic>;
        final medium = (thumbs["medium"] ?? {}) as Map<String, dynamic>;
        final thumbnail = (medium["url"] ?? "").toString();

        final resource = (snippet["resourceId"] ?? {}) as Map<String, dynamic>;
        final videoId = (resource["videoId"] ?? "").toString();

        if (videoId.isEmpty) return const SizedBox.shrink();

        return Card(
          elevation: 1,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
          child: InkWell(
            onTap: () => _openYoutube(videoId),
            borderRadius: BorderRadius.circular(5),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: Stack(
                      children: [
                        thumbnail.isEmpty
                            ? Container(
                          width: 100,
                          height: 70,
                          color: Colors.grey[300],
                          child: const Icon(Icons.video_library_outlined, color: Colors.grey, size: 40),
                        )
                            : Image.network(
                          thumbnail,
                          width: 100,
                          height: 70,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 100,
                            height: 70,
                            color: Colors.grey[300],
                            child: const Icon(Icons.broken_image, color: Colors.grey, size: 40),
                          ),
                        ),
                        Positioned(
                          bottom: 4,
                          right: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.play_arrow, color: Colors.white, size: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          channelTitle,
                          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, color: Colors.black, size: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
