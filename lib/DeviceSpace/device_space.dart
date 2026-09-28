import 'package:disk_space_plus/disk_space_plus.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import '../DirectoryFolder/media_store/duplicates_page.dart';
import '../DirectoryFolder/media_store/folder_list_page.dart';
import '../DirectoryFolder/media_store/media_list_page.dart';
import '../DirectoryFolder/media_store/media_store.dart';
import '../DirectoryFolder/media_store/saf_docs_page.dart';
import '../DirectoryFolder/media_store/storage_analyzer_page.dart';
import '../DirectoryFolder/file_browser/wireless_transfer_page.dart';
import '../NotifyListeners/LanguageProvider/device_strings.dart';
import '../NotifyListeners/LanguageProvider/home_strings.dart';
import '../NotifyListeners/LanguageProvider/language_provider.dart';
import '../Utils/app_palette.dart';
import '../ads/app_open_ad_manager.dart';

/// Accents for the Quick Access cards.
///
/// Deliberately the same five hues the file browser already uses for its tab
/// indicators, so a card and the tab it opens are recognisably the same thing.
const _kVideos = [Color(0xFF8B5CF6), Color(0xFF6D28D9)];
const _kPhotos = [Color(0xFFFB923C), Color(0xFFEA580C)];
const _kMusic = [Color(0xFFF472B6), Color(0xFFE11D48)];
const _kDocs = [Color(0xFF60A5FA), Color(0xFF2563EB)];
const _kFolders = [Color(0xFF34D399), Color(0xFF059669)];
const _kApks = [Color(0xFF4ADE80), Color(0xFF16A34A)];
const _kArchives = [Color(0xFFA8A29E), Color(0xFF78716C)];
const _kDownloads = [Color(0xFF38BDF8), Color(0xFF0284C7)];

class DeviceSpaceScreen extends StatefulWidget {
  const DeviceSpaceScreen({super.key});

  @override
  State<DeviceSpaceScreen> createState() => _DeviceSpaceScreenState();
}

class _DeviceSpaceScreenState extends State<DeviceSpaceScreen> {
  final appOpenManager = AppOpenAdManager();

  double _totalDiskSpaceGB = 0;
  double _freeDiskSpaceGB = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _initDiskSpace();
  }

  Future<void> _initDiskSpace() async {
    // Reading free/total disk space needs no storage permission at all.
    // The old code requested MANAGE_EXTERNAL_STORAGE (All-Files Access) here,
    // which requires a Play Console declaration and is grounds for rejection.
    try {
      final disk = DiskSpacePlus();
      final totalMB = await disk.getTotalDiskSpace ?? 0;
      final freeMB = await disk.getFreeDiskSpace ?? 0;

      if (!mounted) return;

      setState(() {
        _totalDiskSpaceGB = totalMB / 1024; // MB → GB
        _freeDiskSpaceGB = freeMB / 1024;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Disk space error: $e');
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  String gb(double value) => value.toStringAsFixed(1);

  double get _usedGB =>
      (_totalDiskSpaceGB - _freeDiskSpaceGB).clamp(0, _totalDiskSpaceGB);

  /// 0..1. Guarded against the zero total a failed disk read leaves behind —
  /// otherwise this is a NaN, and a NaN reaches `CircularProgressIndicator`
  /// as an assertion failure rather than an empty ring.
  double get _usedFraction =>
      _totalDiskSpaceGB <= 0 ? 0 : (_usedGB / _totalDiskSpaceGB).clamp(0, 1);

  /// Opens one kind of file on its own screen.
  ///
  /// Was `_openBrowser(int tab)`, which pushed the five-tab browser and asked
  /// it to land on a tab. Every card went to the same place and the user had to
  /// re-find what they had just tapped; now each card opens exactly what it
  /// names, with no tab strip and no folder to grant first.
  void _openKind(MediaKind kind, String title, Color accent) {
    Navigator.push(
      context,
      MaterialPageRoute(
        settings: RouteSettings(name: 'MediaList_${kind.wire}'),
        builder: (_) => MediaListPage(kind: kind, title: title, accent: accent),
      ),
    );
  }

  void _openFolders() {
    Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: 'FolderListScreen'),
        builder: (_) => const FolderListPage(),
      ),
    );
  }

  /// Documents, apks, archives and downloads.
  ///
  /// These four do not go through MediaStore like the cards above them, and
  /// not by choice — measured on this device, a MediaStore query that returns
  /// 4 500 photos returns zero pdfs, because scoped storage hides other apps'
  /// non-media files from an app that has not been granted All-files access.
  /// [SafDocsPage] carries the explanation and the one folder grant that makes
  /// them readable.
  void _openDocs(String title, Color accent) {
    Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: 'DocumentsScreen'),
        builder: (_) => SafDocsPage(title: title, accent: accent),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    AppPalette.sync(context);
    final lang = context.watch<LocaleProvider>().locale.languageCode;

    return Scaffold(
      backgroundColor: AppPalette.surface,
      appBar: AppBar(
        backgroundColor: AppPalette.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppPalette.textH,
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              DeviceStrings.t(lang, 'device_appbar_title'),
              style: TextStyle(
                fontFamily: 'Poppins',
                color: AppPalette.textH,
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              DeviceStrings.t(lang, 'device_appbar_subtitle'),
              style: TextStyle(
                fontFamily: 'Poppins',
                color: AppPalette.textS,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 20),
              children: [
                _StorageHero(
                  title: DeviceStrings.t(lang, 'device_internal_storage'),
                  detail: DeviceStrings.t(lang, 'device_storage_used_of')
                      .replaceAll('{used}', gb(_usedGB))
                      .replaceAll('{total}', gb(_totalDiskSpaceGB)),
                  fraction: _usedFraction,
                  onTap: _openFolders,
                ),

                const SizedBox(height: 20),
                _SectionHeader(
                  title: DeviceStrings.t(lang, 'device_quick_access'),
                  actionLabel: DeviceStrings.t(lang, 'device_see_all'),
                  onAction: _openFolders,
                ),
                const SizedBox(height: 10),

                // Eight cards, each opening one screen of exactly what it says.
                // APKs, Archives and Downloads used to be buried a level deeper
                // inside a "Categories" screen; reading them straight out of
                // MediaStore costs no more than the others, so they are cards.
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  // Wider than tall: with no file count under the label there
                  // is nothing to fill a square, and five square cards left a
                  // band of empty gradient in the middle of each one.
                  childAspectRatio: 1.32,
                  children: [
                    _QuickCard(
                      icon: Icons.movie_rounded,
                      label: HomeStrings.t(lang, 'fb_tab_videos'),
                      colors: _kVideos,
                      onTap: () => _openKind(MediaKind.video, HomeStrings.t(lang, 'fb_tab_videos'), _kVideos.last),
                    ),
                    _QuickCard(
                      icon: Icons.photo_rounded,
                      label: HomeStrings.t(lang, 'fb_tab_photos'),
                      colors: _kPhotos,
                      onTap: () => _openKind(MediaKind.image, HomeStrings.t(lang, 'fb_tab_photos'), _kPhotos.last),
                    ),
                    _QuickCard(
                      icon: Icons.music_note_rounded,
                      label: HomeStrings.t(lang, 'fb_tab_music'),
                      colors: _kMusic,
                      onTap: () => _openKind(MediaKind.audio, HomeStrings.t(lang, 'fb_tab_music'), _kMusic.last),
                    ),
                    _QuickCard(
                      icon: Icons.description_rounded,
                      label: HomeStrings.t(lang, 'fb_tab_docs'),
                      colors: _kDocs,
                      onTap: () => _openDocs(HomeStrings.t(lang, 'fb_tab_docs'), _kDocs.last),
                    ),
                    _QuickCard(
                      icon: Icons.android_rounded,
                      label: HomeStrings.t(lang, 'fb_cat_apks'),
                      colors: _kApks,
                      onTap: () =>
                          _openDocs(HomeStrings.t(lang, 'fb_cat_apks'), _kApks.last),
                    ),
                    _QuickCard(
                      icon: Icons.folder_zip_rounded,
                      label: HomeStrings.t(lang, 'fb_cat_archives'),
                      colors: _kArchives,
                      onTap: () => _openDocs(
                          HomeStrings.t(lang, 'fb_cat_archives'),
                          _kArchives.last),
                    ),
                    _QuickCard(
                      icon: Icons.download_rounded,
                      label: HomeStrings.t(lang, 'fb_downloads'),
                      colors: _kDownloads,
                      onTap: () => _openDocs(
                          HomeStrings.t(lang, 'fb_downloads'),
                          _kDownloads.last),
                    ),
                    _QuickCard(
                      icon: Icons.folder_rounded,
                      label: HomeStrings.t(lang, 'fb_tab_folders'),
                      colors: _kFolders,
                      onTap: _openFolders,
                    ),
                  ],
                ),

                const SizedBox(height: 20),
                _SectionHeader(
                  title: HomeStrings.t(lang, 'device_tools'),
                ),
                const SizedBox(height: 10),

                // The separate "Categories" screen that used to head this list
                // is gone: it was a second way to reach Images/Videos/Audio/
                // Documents, which the cards above already open directly. What
                // it uniquely offered — APKs and archives — became cards too.
                _LocationTile(
                  icon: Icons.history_rounded,
                  title: HomeStrings.t(lang, 'fb_recent'),
                  subtitle: HomeStrings.t(lang, 'device_tools_recent'),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      settings: const RouteSettings(name: 'RecentFilesScreen'),
                      builder: (_) => MediaListPage(
                        kind: MediaKind.all,
                        title: HomeStrings.t(lang, 'fb_recent'),
                        recentOnly: true,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _LocationTile(
                  icon: Icons.donut_large_rounded,
                  title: HomeStrings.t(lang, 'fb_analyzer'),
                  subtitle: HomeStrings.t(lang, 'device_tools_analyzer'),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      settings:
                          const RouteSettings(name: 'StorageAnalyzerScreen'),
                      builder: (_) => const StorageAnalyzerPage(),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _LocationTile(
                  icon: Icons.file_copy_rounded,
                  title: HomeStrings.t(lang, 'fb_duplicates'),
                  subtitle: HomeStrings.t(lang, 'device_tools_duplicates'),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      settings: const RouteSettings(name: 'DuplicatesScreen'),
                      builder: (_) => const DuplicatesPage(),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _LocationTile(
                  icon: Icons.wifi_tethering_rounded,
                  title: HomeStrings.t(lang, 'fb_wireless'),
                  subtitle: HomeStrings.t(lang, 'device_tools_wireless'),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      settings:
                          const RouteSettings(name: 'WirelessTransferScreen'),
                      builder: (_) => const WirelessTransferPage(),
                    ),
                  ),
                ),

                const SizedBox(height: 20),
                _SectionHeader(
                  title: DeviceStrings.t(lang, 'device_storage_locations'),
                ),
                const SizedBox(height: 10),

                // No SD card / OTG / Cloud rows with sizes beside them.
                //
                // Nothing in the app can read those volumes' capacity — a card
                // reading "28.6 GB of 64 GB" would be a number made up in the
                // widget. Android's own picker already lists every one of them
                // (removable volumes and signed-in cloud providers alike), so
                // this row sends the user there instead of imitating it.
                _LocationTile(
                  icon: Icons.sd_storage_rounded,
                  title: DeviceStrings.t(lang, 'device_other_locations'),
                  subtitle: DeviceStrings.t(lang, 'device_other_locations_sub'),
                  onTap: _openFolders,
                ),
              ],
            ),
      bottomNavigationBar: appOpenManager.bannerWidget(),
    );
  }
}

/// The big storage card at the top: how full the phone is, and a way in.
class _StorageHero extends StatelessWidget {
  const _StorageHero({
    required this.title,
    required this.detail,
    required this.fraction,
    required this.onTap,
  });

  final String title;
  final String detail;
  final double fraction;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4F46E5).withValues(alpha: 0.3),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(16, 16, 14, 16),
          child: Row(
            children: [
              Container(
                height: 46,
                width: 46,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.smartphone_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      detail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 11.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: fraction,
                        minHeight: 6,
                        backgroundColor: Colors.white.withValues(alpha: 0.22),
                        valueColor:
                            const AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              SizedBox(
                height: 52,
                width: 52,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      height: 52,
                      width: 52,
                      child: CircularProgressIndicator(
                        value: fraction,
                        strokeWidth: 4,
                        backgroundColor: Colors.white.withValues(alpha: 0.22),
                        valueColor:
                            const AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    Text(
                      '${(fraction * 100).round()}%',
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontFamily: 'Poppins',
            color: AppPalette.textH,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (actionLabel != null && onAction != null)
          InkWell(
            onTap: onAction,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Text(
                actionLabel!,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  color: Color(0xFF6D28D9),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _QuickCard extends StatelessWidget {
  const _QuickCard({
    required this.icon,
    required this.label,
    required this.colors,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final List<Color> colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 34,
                width: 34,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: Colors.white, size: 18),
              ),
              const Spacer(),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  color: Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LocationTile extends StatelessWidget {
  const _LocationTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppPalette.card,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Container(
                height: 40,
                width: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF6D28D9).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: const Color(0xFF6D28D9),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        color: AppPalette.textH,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        color: AppPalette.textS,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: AppPalette.textS,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
