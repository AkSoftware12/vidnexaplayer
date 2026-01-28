import 'package:country_codes/country_codes.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:videoplayer/Home/YoutubeScreen/playlistvideos.dart';

/// ✅ Full code with Hive cache (per user 24 hours me 1 bar API hit)
/// NOTE: main.dart me Hive.initFlutter() + Hive.openBox('yt_cache') required.
/// (Main.dart snippet is given at bottom)

class YouTubeTopPlaylists extends StatefulWidget {
  const YouTubeTopPlaylists({super.key});

  @override
  State<YouTubeTopPlaylists> createState() => _YouTubeTopPlaylistsState();
}

class _YouTubeTopPlaylistsState extends State<YouTubeTopPlaylists> {
  final String apiKey = "AIzaSyAkbfVnNtAA0D3hNPmGA_cFxOGYnpnCZKI";

  final Box _box = Hive.box('yt_cache');

  static const String _cacheKey = "yt_playlist_cache_v1";
  static const String _cacheTimeKey = "yt_playlist_cache_time_v1";
  static const Duration _cacheDuration = Duration(hours: 24);

  Map<String, List> categoryPlaylists = {};
  bool isLoading = true;

  // Default country
  String countryCode = 'IN';

  // Country-wise category queries
  final Map<String, List<String>> countryCategoryMap = {
    "IN": ["Bollywood Songs", "Punjabi Hits", "Romantic Songs", "Lofi Chill Beats"],
    "US": ["Top English Pop", "Hip Hop Hits", "Workout Music", "Lofi Chill Beats"],
    "GB": ["UK Top Music", "British Pop", "Indie Hits", "Lofi Chill Beats"],
    "FR": ["French Hits", "Top Music France", "Romantic Songs FR", "Lofi Chill Beats"],
  };

  @override
  void initState() {
    super.initState();
    initCountryAndFetch();
  }

  Future<void> initCountryAndFetch() async {
    try {
      await CountryCodes.init();
      final Locale? deviceLocale = CountryCodes.getDeviceLocale();
      // ✅ if you want device country:
      // countryCode = deviceLocale?.countryCode ?? 'US';

      debugPrint('Country Code => $countryCode');

      // ✅ 1) Try cache (no API hit)
      final loadedFromCache = await _loadFromCacheIfValid();

      // ✅ 2) If cache invalid/empty => API hit once
      if (!loadedFromCache) {
        await fetchAllCategories();
        await _saveCache();
      }
    } catch (e) {
      debugPrint("initCountryAndFetch error: $e");
      // fallback to API if something fails
      await fetchAllCategories();
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

    // Expired
    if (diff > _cacheDuration) return false;

    final Map<String, dynamic> decoded = json.decode(cacheJson);

    setState(() {
      categoryPlaylists = decoded.map((k, v) => MapEntry(k, List.from(v)));
    });

    return true;
  }

  /// ✅ Save cache after successful fetch
  Future<void> _saveCache() async {
    final String jsonString = json.encode(categoryPlaylists);
    await _box.put(_cacheKey, jsonString);
    await _box.put(_cacheTimeKey, DateTime.now().millisecondsSinceEpoch);
  }

  /// ✅ Optional: Force refresh (manual)
  Future<void> forceRefresh() async {
    setState(() => isLoading = true);
    // await fetchAllCategories();
    // await _saveCache();
    if (mounted) setState(() => isLoading = false);
  }

  Future<void> fetchAllCategories() async {
    categoryPlaylists.clear();

    final categories = countryCategoryMap[countryCode] ?? countryCategoryMap['US']!;
    for (var category in categories) {
      await fetchPlaylistsForCategory(category);
    }
  }

  Future<void> fetchPlaylistsForCategory(String query) async {
    final url = Uri.parse(
      'https://www.googleapis.com/youtube/v3/search'
          '?part=snippet&type=playlist&q=${Uri.encodeComponent(query)}'
          '&regionCode=$countryCode&maxResults=10&key=$apiKey',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final items = data["items"] as List? ?? [];

        setState(() {
          categoryPlaylists[query] = items;
        });
      } else {
        debugPrint("API error ${response.statusCode}: ${response.body}");
        setState(() {
          categoryPlaylists[query] = [];
        });
      }
    } catch (e) {
      debugPrint("fetchPlaylistsForCategory error: $e");
      setState(() {
        categoryPlaylists[query] = [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = categoryPlaylists.keys.toList();

    return Scaffold(
      backgroundColor: Colors.white,

      // ✅ Pull to refresh (force refresh)
      body: RefreshIndicator(
        onRefresh: forceRefresh,
        child: isLoading
            ? const Center(
          child: CircularProgressIndicator(color: Colors.redAccent),
        )
            : (categories.isEmpty
            ? ListView(
          children: const [
            SizedBox(height: 200),
            Center(
              child: Text(
                "No playlists found",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        )
            : ListView(
          padding: const EdgeInsets.only(bottom: 16),
          children: categories.map((category) {
            final playlists = categoryPlaylists[category] ?? [];

            if (playlists.isEmpty) return const SizedBox.shrink();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 🔥 Category Title
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          category,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),

                      // 👉 Right Arrow
                      InkWell(
                        onTap: () {
                          debugPrint("View all clicked for $category");
                        },
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 14,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // 🔥 Playlist Row
                SizedBox(
                  height: 210,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: playlists.length,
                    itemBuilder: (context, index) {
                      final playlist = playlists[index] as Map<String, dynamic>;
                      final snippet = (playlist["snippet"] ?? {}) as Map<String, dynamic>;

                      final title = (snippet["title"] ?? "").toString();
                      final channelTitle = (snippet["channelTitle"] ?? "").toString();

                      final thumbnails = (snippet["thumbnails"] ?? {}) as Map<String, dynamic>;
                      final medium = (thumbnails["medium"] ?? {}) as Map<String, dynamic>;
                      final thumbnail = (medium["url"] ?? "").toString();

                      final idObj = (playlist["id"] ?? {}) as Map<String, dynamic>;
                      final playlistId = (idObj["playlistId"] ?? "").toString();

                      if (playlistId.isEmpty) return const SizedBox.shrink();

                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => YouTubePlaylistVideos(
                                playlistId: playlistId,
                                playlistTitle: title,
                                apiKey: apiKey,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          width: 170,
                          margin: EdgeInsets.only(
                            left: index == 0 ? 10 : 5,
                            right: index == playlists.length - 1 ? 16 : 0,
                            bottom: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.withOpacity(0.08),
                                blurRadius: 10,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 🔥 Thumbnail with Play Icon
                              Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(5),
                                    ),
                                    child: thumbnail.isEmpty
                                        ? Container(
                                      height: 110,
                                      width: double.infinity,
                                      color: Colors.grey.shade200,
                                      child: const Icon(Icons.image_not_supported),
                                    )
                                        : Image.network(
                                      thumbnail,
                                      height: 110,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        height: 110,
                                        width: double.infinity,
                                        color: Colors.grey.shade200,
                                        child: const Icon(Icons.broken_image),
                                      ),
                                    ),
                                  ),
                                  Positioned.fill(
                                    child: Center(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.45),
                                          shape: BoxShape.circle,
                                        ),
                                        padding: const EdgeInsets.all(8),
                                        child: const Icon(
                                          Icons.play_arrow_rounded,
                                          color: Colors.white,
                                          size: 36,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              // 🔥 Title
                              Padding(
                                padding: const EdgeInsets.all(10),
                                child: Text(
                                  title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),

                              // 🔥 Channel Name
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                child: Text(
                                  channelTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          }).toList(),
        )),
      ),

      // ✅ Optional: refresh icon on appbar (if you want)
      // appBar: AppBar(
      //   title: const Text("Top Playlists"),
      //   actions: [
      //     IconButton(
      //       icon: const Icon(Icons.refresh),
      //       onPressed: forceRefresh,
      //     )
      //   ],
      // ),
    );
  }
}
