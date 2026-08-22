import 'package:country_codes/country_codes.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:videoplayer/Home/YoutubeScreen/playlistvideos.dart';
import '../../NotifyListeners/LanguageProvider/language_provider.dart';
import '../../NotifyListeners/LanguageProvider/video_strings.dart';

/// ✅ Full code with Hive cache (per user 24 hours me 1 bar API hit)
/// NOTE: main.dart me Hive.initFlutter() + Hive.openBox('yt_cache') required.
/// (Main.dart snippet is given at bottom)

class YouTubeTopPlaylists extends StatefulWidget {
  const YouTubeTopPlaylists({super.key});

  @override
  State<YouTubeTopPlaylists> createState() => _YouTubeTopPlaylistsState();
}

class _YouTubeTopPlaylistsState extends State<YouTubeTopPlaylists> {
  /// ⚠️ Supply at build time so the key is not sitting in source control:
  ///     flutter run --dart-define=YT_API_KEY=xxxx
  /// Also restrict the key to this app's package + SHA-1 in Google Cloud
  /// Console — anything shipped in an APK can be extracted.
  static const String _apiKey = String.fromEnvironment(
    'YT_API_KEY',
    defaultValue: 'AIzaSyAkbfVnNtAA0D3hNPmGA_cFxOGYnpnCZKI',
  );

  Box? _box;

  static const String _cacheKey = "yt_playlist_cache_v1";
  static const String _cacheTimeKey = "yt_playlist_cache_time_v1";
  static const Duration _cacheDuration = Duration(hours: 24);
  static const Duration _requestTimeout = Duration(seconds: 15);

  Map<String, List> categoryPlaylists = {};
  bool isLoading = true;

  /// Resolved from the device locale at runtime; 'IN' is only the fallback.
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
    // Opening the box here (instead of in a field initializer) means this
    // screen no longer throws if main.dart's Hive init failed.
    try {
      _box = Hive.isBoxOpen('yt_cache')
          ? Hive.box('yt_cache')
          : await Hive.openBox('yt_cache');
    } catch (e) {
      debugPrint('yt_cache unavailable: $e');
    }

    try {
      await CountryCodes.init();
      final Locale? deviceLocale = CountryCodes.getDeviceLocale();
      final detected = deviceLocale?.countryCode;
      // Was hardcoded to 'IN' with the device lookup commented out, so every
      // user worldwide got the Indian category list.
      if (detected != null && detected.isNotEmpty) {
        countryCode = detected.toUpperCase();
      }
      debugPrint('Country Code => $countryCode');
    } catch (e) {
      debugPrint('Country detection failed, using $countryCode: $e');
    }

    try {
      if (!await _loadFromCacheIfValid()) {
        await fetchAllCategories();
        await _saveCache();
      }
    } catch (e) {
      debugPrint('initCountryAndFetch error: $e');
    }

    if (mounted) setState(() => isLoading = false);
  }

  /// ✅ Load cache if within 24 hours
  Future<bool> _loadFromCacheIfValid() async {
    final box = _box;
    if (box == null) return false;

    try {
      final String? cacheJson = box.get(_cacheKey) as String?;
      final int? lastTimeMs = box.get(_cacheTimeKey) as int?;

      if (cacheJson == null || lastTimeMs == null) return false;

      final lastTime = DateTime.fromMillisecondsSinceEpoch(lastTimeMs);
      if (DateTime.now().difference(lastTime) > _cacheDuration) return false;

      final decoded = json.decode(cacheJson) as Map<String, dynamic>;
      final restored = decoded.map((k, v) => MapEntry(k, List.from(v as List)));
      if (restored.isEmpty) return false;

      if (!mounted) return false;
      setState(() => categoryPlaylists = restored);
      return true;
    } catch (e) {
      debugPrint('Cache read failed: $e');
      return false;
    }
  }

  /// ✅ Save cache after successful fetch
  Future<void> _saveCache() async {
    final box = _box;
    if (box == null || categoryPlaylists.isEmpty) return;
    try {
      await box.put(_cacheKey, json.encode(categoryPlaylists));
      await box.put(_cacheTimeKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('Cache write failed: $e');
    }
  }

  /// Pull-to-refresh. The body of this method used to be commented out, so the
  /// spinner span and nothing was ever refetched.
  Future<void> forceRefresh() async {
    if (isLoading) return;
    setState(() => isLoading = true);
    try {
      await fetchAllCategories();
      await _saveCache();
    } catch (e) {
      debugPrint('forceRefresh error: $e');
    }
    if (mounted) setState(() => isLoading = false);
  }

  Future<void> fetchAllCategories() async {
    final categories =
        countryCategoryMap[countryCode] ?? countryCategoryMap['US']!;

    // Build into a local map so a failed refresh doesn't blank the screen —
    // `categoryPlaylists.clear()` used to wipe the UI before the first response.
    final results = <String, List>{};
    for (final category in categories) {
      results[category] = await _fetchPlaylistsForCategory(category);
    }

    if (!mounted) return;
    setState(() => categoryPlaylists = results);
  }

  Future<List> _fetchPlaylistsForCategory(String query) async {
    final url = Uri.parse(
      'https://www.googleapis.com/youtube/v3/search'
      '?part=snippet&type=playlist&q=${Uri.encodeComponent(query)}'
      '&regionCode=$countryCode&maxResults=10&key=$_apiKey',
    );

    try {
      // Without a timeout a stalled connection left the screen spinning forever.
      final response = await http.get(url).timeout(_requestTimeout);
      if (response.statusCode != 200) {
        debugPrint('YouTube API error ${response.statusCode}');
        return const [];
      }
      final data = json.decode(response.body) as Map<String, dynamic>;
      return (data['items'] as List?) ?? const [];
    } catch (e) {
      debugPrint('fetchPlaylistsForCategory("$query") error: $e');
      return const [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LocaleProvider>().locale.languageCode;
    final categories = categoryPlaylists.keys.toList();

    return Scaffold(
      backgroundColor: Colors.white,

      // ✅ Pull to refresh (force refresh)
      body: RefreshIndicator(
        onRefresh: forceRefresh,
        child: isLoading
            ?  Center(
          child:CupertinoActivityIndicator(
            radius: 20,
            color: Colors.blue,
          ),
        )
            : (categories.isEmpty
            ? ListView(
          children: [
            const SizedBox(height: 200),
            Center(
              child: Text(
                VideoStrings.t(lang, 'yt_no_playlists_found'),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
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
                                apiKey: _apiKey,
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
                                color: Colors.blue.withValues(alpha:0.08),
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
                                          color: Colors.black.withValues(alpha:0.45),
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
