import 'package:disk_space_plus/disk_space_plus.dart';
import 'package:docman/docman.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import '../DirectoryFolder/directory_folder.dart' show FullScreenImageViewer;
import '../DirectoryFolder/file_browser/file_kind.dart';
import '../DirectoryFolder/media_store/duplicates_page.dart';
import '../DirectoryFolder/media_store/folder_list_page.dart';
import '../DirectoryFolder/media_store/media_list_page.dart';
import '../DirectoryFolder/media_store/media_store.dart';
import '../DirectoryFolder/media_store/storage_analyzer_page.dart';
import '../DirectoryFolder/file_browser/wireless_transfer_page.dart';
import '../LocalMusic/AUDIOCONTROLLER/global_audio_controller.dart';
import '../LocalMusic/FullScreenPlayer/full_player_screen.dart';
import '../VideoPLayer/4kPlayer/4k_player.dart';
import '../NotifyListeners/LanguageProvider/device_strings.dart';
import '../NotifyListeners/LanguageProvider/home_strings.dart';
import '../NotifyListeners/LanguageProvider/language_provider.dart';
import '../Utils/app_palette.dart';
import '../ads/app_open_ad_manager.dart';
import '../WhatsNew/whats_new.dart';

/// Accents for the Quick Access cards.
///
/// Each gradient crosses into a neighbouring hue rather than just darkening,
/// which is what makes the tiles read as bright rather than flat. The last
/// colour doubles as the accent of the screen the card opens.
const _kVideos = [Color(0xFFA855F7), Color(0xFF6366F1)];
const _kPhotos = [Color(0xFFFBBF24), Color(0xFFF97316)];
const _kMusic = [Color(0xFFF472B6), Color(0xFFEC4899)];
const _kDocs = [Color(0xFF22D3EE), Color(0xFF3B82F6)];
const _kFolders = [Color(0xFF2DD4BF), Color(0xFF0D9488)];
const _kApks = [Color(0xFFA3E635), Color(0xFF22C55E)];
const _kArchives = [Color(0xFFFB7185), Color(0xFFEF4444)];
const _kDownloads = [Color(0xFF818CF8), Color(0xFF8B5CF6)];

/// Accents for the Tools tiles.
const _kToolRecent = [Color(0xFF38BDF8), Color(0xFF6366F1)];
const _kToolAnalyzer = [Color(0xFFF59E0B), Color(0xFFEF4444)];
const _kToolDuplicates = [Color(0xFFE879F9), Color(0xFF9333EA)];
const _kToolWireless = [Color(0xFF34D399), Color(0xFF0EA5E9)];

/// The four Quick Access cards served by the system document picker.
enum _PickCard {
  docs([
    'application/pdf',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/vnd.ms-excel',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'application/vnd.ms-powerpoint',
    'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'application/vnd.oasis.opendocument.text',
    'application/vnd.oasis.opendocument.spreadsheet',
    'application/vnd.oasis.opendocument.presentation',
    'application/rtf',
    'application/epub+zip',
    'text/*',
  ], initDir: _kDocumentsRoot),
  apks(['application/vnd.android.package-archive'], initDir: _kDownloadDir),
  archives([
    'application/zip',
    'application/x-rar-compressed',
    'application/vnd.rar',
    'application/x-7z-compressed',
    'application/gzip',
    'application/x-tar',
  ], initDir: _kDownloadDir),
  // Everything, opened on the Download folder.
  downloads([], initDir: _kDownloadDir);

  const _PickCard(this.mimeTypes, {this.initDir});

  final List<String> mimeTypes;
  final String? initDir;
}

/// Where the picker opens. Without one it reopens wherever any picker in the
/// app was last left — often an empty WhatsApp folder from the status saver.
///
/// Both are *root* uris of the picker's own sections, not document uris.
/// Verified on an Android 16 device: the picker resolves an initial document
/// uri through `findDocumentPath`, which the media provider does not
/// implement, so `…/document/documents_root` silently falls back to the last
/// location; `…/root/documents_root` opens the section itself.
///
/// The "Downloads" section: everything downloaded, folders included.
const _kDownloadDir =
    'content://com.android.providers.downloads.documents/root/downloads';

/// The "Documents" section (Android 11+): every document on the device,
/// gathered by the system's media provider, which can see them all.
const _kDocumentsRoot =
    'content://com.android.providers.media.documents/root/documents_root';

class DeviceSpaceScreen extends StatefulWidget {
  const DeviceSpaceScreen({super.key, this.embedded = false});

  /// True when shown as the Files tab of the bottom bar. The home shell then
  /// already provides the app bar and the bottom banner, so this screen
  /// drops its own of both rather than stacking a second set.
  final bool embedded;

  @override
  State<DeviceSpaceScreen> createState() => _DeviceSpaceScreenState();
}

class _DeviceSpaceScreenState extends State<DeviceSpaceScreen> {
  final appOpenManager = AppOpenAdManager();

  double _totalDiskSpaceGB = 0;
  double _freeDiskSpaceGB = 0;
  bool _loading = true;

  /// Mounted SD cards / USB drives. Empty on most phones, which hides the
  /// Storage locations section entirely.
  List<RemovableVolume> _volumes = const [];

  static const double _bytesPerGb = 1024 * 1024 * 1024;

  @override
  void initState() {
    super.initState();
    WhatsNew.instance.markSeen(NewFeature.files);
    _initDiskSpace();
    _loadVolumes();
  }

  Future<void> _loadVolumes() async {
    final volumes = await MediaStoreRepo.instance.volumes();
    if (!mounted) return;
    setState(() => _volumes = volumes);
  }

  /// That card's folders only, under its own name.
  void _openVolume(RemovableVolume v, String lang) {
    _go(
      MaterialPageRoute(
        settings: const RouteSettings(name: 'SdCardFoldersScreen'),
        builder: (_) => FolderListPage(
          volume: v.volume,
          title: v.label.isEmpty ? DeviceStrings.t(lang, 'device_sd_card') : v.label,
        ),
      ),
    );
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
    _go(
      MaterialPageRoute(
        settings: RouteSettings(name: 'MediaList_${kind.wire}'),
        builder: (_) => MediaListPage(kind: kind, title: title, accent: accent),
      ),
    );
  }

  /// Pushes [route] once the interstitial has had its chance. The ad manager
  /// caps how often one actually shows, so most taps navigate immediately.
  void _go(Route<void> route) {
    appOpenManager.showInterstitialIfAllowed(
      onContinue: () {
        if (mounted) Navigator.push(context, route);
      },
    );
  }

  void _openFolders() {
    _go(
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
  ///
  /// So the card opens the system document picker, already filtered to what
  /// it names (or opened on Download/). It lists every matching file on the
  /// device with no folder to grant first, and needs no All-files access.
  /// Whatever is picked is opened: media in the app's own players, anything
  /// else in the app that claims its type.
  Future<void> _pickAndOpen(_PickCard card) async {
    final messenger = ScaffoldMessenger.of(context);
    final lang = context.read<LocaleProvider>().locale.languageCode;

    final List<DocumentFile> picked;
    try {
      picked = await DocMan.pick.documents(
        mimeTypes: card.mimeTypes,
        initDir: card.initDir,
        localOnly: true,
      );
    } catch (e) {
      debugPrint('Picker failed: $e');
      return;
    }
    if (picked.isEmpty || !mounted) return;

    final doc = picked.first;
    final kind = FileKind.of(doc.name);

    if (kind == FileKind.video) {
      Navigator.push(
        context,
        MaterialPageRoute(
          settings: const RouteSettings(name: 'VideoPlayerScreen'),
          builder: (_) => FullScreenVideoPlayerFixed(initialUrl: doc.uri),
        ),
      );
      return;
    }

    if (kind == FileKind.audio) {
      await GlobalAudioController().playExternalUri(doc.uri, title: doc.name);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          settings: const RouteSettings(name: 'MusicFullPlayerScreen'),
          builder: (_) => const FullPlayerScreen(),
        ),
      );
      return;
    }

    if (kind == FileKind.image) {
      // The in-app viewer reads a real path; a picked document only has a
      // content uri, so it goes through the cache first.
      final file = await doc.cache();
      if (file != null && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            settings: const RouteSettings(name: 'FullScreenImageViewer'),
            builder: (_) => FullScreenImageViewer(imagePath: file.path),
          ),
        );
        return;
      }
    }

    bool opened;
    try {
      opened = await doc.open();
    } catch (e) {
      debugPrint('Open failed: $e');
      opened = false;
    }
    if (!opened) {
      messenger.showSnackBar(
        SnackBar(content: Text(HomeStrings.t(lang, 'fb_open_failed'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    AppPalette.sync(context);
    final lang = context.watch<LocaleProvider>().locale.languageCode;

    return Scaffold(
      backgroundColor: AppPalette.surface,
      appBar: widget.embedded ? null : AppBar(
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

                const SizedBox(height: 16),
                appOpenManager.nativeWidget(),

                const SizedBox(height: 16),
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
                // Four to a row, so the eight cards fit in two rows. At this
                // width a card is ~77dp wide, hence the near-square ratio and
                // the centred, compact contents of [_QuickCard].
                GridView.count(
                  crossAxisCount: 4,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 1.18,
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
                      onTap: () => _pickAndOpen(_PickCard.docs),
                    ),
                    _QuickCard(
                      icon: Icons.android_rounded,
                      label: HomeStrings.t(lang, 'fb_cat_apks'),
                      colors: _kApks,
                      onTap: () => _pickAndOpen(_PickCard.apks),
                    ),
                    _QuickCard(
                      icon: Icons.folder_zip_rounded,
                      label: HomeStrings.t(lang, 'fb_cat_archives'),
                      colors: _kArchives,
                      onTap: () => _pickAndOpen(_PickCard.archives),
                    ),
                    _QuickCard(
                      icon: Icons.download_rounded,
                      label: HomeStrings.t(lang, 'fb_downloads'),
                      colors: _kDownloads,
                      onTap: () => _pickAndOpen(_PickCard.downloads),
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
                //
                // Two to a row, each tool in its own colour.
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.45,
                  children: [
                    _ToolTile(
                      icon: Icons.history_rounded,
                      title: HomeStrings.t(lang, 'fb_recent'),
                      subtitle: HomeStrings.t(lang, 'device_tools_recent'),
                      colors: _kToolRecent,
                      onTap: () => _go(
                        MaterialPageRoute(
                          settings:
                              const RouteSettings(name: 'RecentFilesScreen'),
                          builder: (_) => MediaListPage(
                            kind: MediaKind.all,
                            title: HomeStrings.t(lang, 'fb_recent'),
                            recentOnly: true,
                          ),
                        ),
                      ),
                    ),
                    _ToolTile(
                      icon: Icons.donut_large_rounded,
                      title: HomeStrings.t(lang, 'fb_analyzer'),
                      subtitle: HomeStrings.t(lang, 'device_tools_analyzer'),
                      colors: _kToolAnalyzer,
                      onTap: () => _go(
                        MaterialPageRoute(
                          settings: const RouteSettings(
                              name: 'StorageAnalyzerScreen'),
                          builder: (_) => const StorageAnalyzerPage(),
                        ),
                      ),
                    ),
                    _ToolTile(
                      icon: Icons.file_copy_rounded,
                      title: HomeStrings.t(lang, 'fb_duplicates'),
                      subtitle:
                          HomeStrings.t(lang, 'device_tools_duplicates'),
                      colors: _kToolDuplicates,
                      onTap: () => _go(
                        MaterialPageRoute(
                          settings:
                              const RouteSettings(name: 'DuplicatesScreen'),
                          builder: (_) => const DuplicatesPage(),
                        ),
                      ),
                    ),
                    _ToolTile(
                      icon: Icons.wifi_tethering_rounded,
                      title: HomeStrings.t(lang, 'fb_wireless'),
                      subtitle: HomeStrings.t(lang, 'device_tools_wireless'),
                      colors: _kToolWireless,
                      onTap: () => _go(
                        MaterialPageRoute(
                          settings: const RouteSettings(
                              name: 'WirelessTransferScreen'),
                          builder: (_) => const WirelessTransferPage(),
                        ),
                      ),
                    ),
                  ],
                ),

                // One row per mounted SD card / USB drive, and no section at
                // all without one. The row used to be a fixed "SD card, USB &
                // cloud" entry that opened the phone's own folder list, so it
                // led somewhere unrelated on every device.
                if (_volumes.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _SectionHeader(
                    title: DeviceStrings.t(lang, 'device_storage_locations'),
                  ),
                  const SizedBox(height: 10),
                  for (final v in _volumes) ...[
                    _LocationTile(
                      icon: Icons.sd_storage_rounded,
                      title: v.label.isEmpty
                          ? DeviceStrings.t(lang, 'device_sd_card')
                          : v.label,
                      subtitle: v.total <= 0
                          ? DeviceStrings.t(lang, 'device_sd_card_sub')
                          : DeviceStrings.t(lang, 'device_storage_used_of')
                              .replaceAll('{used}', gb(v.used / _bytesPerGb))
                              .replaceAll(
                                  '{total}', gb(v.total / _bytesPerGb)),
                      onTap: () => _openVolume(v, lang),
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              ],
            ),
      bottomNavigationBar:
          widget.embedded ? null : appOpenManager.bannerWidget(),
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

  /// Pink into violet into indigo — the brightest card on the screen, since
  /// it is the first thing the eye lands on.
  static const _colors = [
    Color(0xFFEC4899),
    Color(0xFF8B5CF6),
    Color(0xFF4F46E5),
  ];

  /// The fill of the usage bar and ring: white while there is room, warming
  /// to amber once the phone is nearly full.
  Color get _fill =>
      fraction >= 0.85 ? const Color(0xFFFDE68A) : Colors.white;

  @override
  Widget build(BuildContext context) {
    final percent = '${(fraction * 100).round()}%';

    // The glow sits outside the clipped Material, or the clip would cut it.
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: _colors[1].withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Ink(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: _colors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Stack(
              children: [
                // Soft bubbles for depth, clipped by the card's corners.
                const Positioned(
                  top: -40,
                  right: -30,
                  child: _Bubble(size: 130, alpha: 0.12),
                ),
                const Positioned(
                  bottom: -36,
                  left: 60,
                  child: _Bubble(size: 80, alpha: 0.08),
                ),
                const Positioned(
                  top: 12,
                  left: -18,
                  child: _Bubble(size: 40, alpha: 0.10),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Container(
                                  height: 38,
                                  width: 38,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.22),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color:
                                          Colors.white.withValues(alpha: 0.35),
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.smartphone_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontFamily: 'Poppins',
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              detail,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: LinearProgressIndicator(
                                value: fraction,
                                minHeight: 8,
                                backgroundColor:
                                    Colors.white.withValues(alpha: 0.22),
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(_fill),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Usage ring, on a frosted disc so it stands off the
                      // gradient behind it.
                      Container(
                        height: 76,
                        width: 76,
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox.expand(
                              child: CircularProgressIndicator(
                                value: fraction,
                                strokeWidth: 6,
                                strokeCap: StrokeCap.round,
                                backgroundColor:
                                    Colors.white.withValues(alpha: 0.22),
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(_fill),
                              ),
                            ),
                            Text(
                              percent,
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
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
        Flexible(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Poppins',
              color: AppPalette.textH,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
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

  /// A plain card: the surface colour of every other card in the app, a hairline
  /// border, and colour only in the small icon — so eight tiles side by side
  /// read as a calm grid rather than a wall of saturated blocks.
  @override
  Widget build(BuildContext context) {
    final accent = colors.last;
    return Material(
      color: AppPalette.card,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppPalette.border),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                height: 30,
                width: 30,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: accent, size: 16),
              ),
              const SizedBox(height: 4),
              // Shrinks to fit a quarter-width cell instead of cutting
              // longer translations ("Документы", "Arsip") short.
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: AppPalette.textH,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.size, required this.alpha});

  final double size;
  final double alpha;

  @override
  Widget build(BuildContext context) => Container(
        height: size,
        width: size,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: alpha),
          shape: BoxShape.circle,
        ),
      );
}

class _ToolTile extends StatelessWidget {
  const _ToolTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.colors,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = colors.last;
    return Material(
      color: AppPalette.card,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accent.withValues(alpha: 0.25)),
            gradient: LinearGradient(
              colors: [
                colors.first.withValues(alpha: 0.16),
                accent.withValues(alpha: 0.04),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
            children: [
              // Faint oversized copy of the icon, centred, for a bit of
              // texture behind the text.
              Positioned.fill(
                child: Center(
                  child: Icon(
                    icon,
                    size: 64,
                    color: accent.withValues(alpha: 0.08),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 34,
                      width: 34,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(11),
                        gradient: LinearGradient(
                          colors: colors,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.35),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(icon, color: Colors.white, size: 18),
                    ),
                    const Spacer(),
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        color: AppPalette.textH,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        color: AppPalette.textS,
                        fontSize: 10.5,
                        height: 1.2,
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

  /// The banner's gradient: teal into blue into violet, so it reads as one
  /// colourful strip rather than another grey row.
  static const _colors = [
    Color(0xFF14B8A6),
    Color(0xFF3B82F6),
    Color(0xFF8B5CF6),
  ];

  @override
  Widget build(BuildContext context) {
    // The glow sits outside the clipped Material, or the clip would cut it.
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: _colors[1].withValues(alpha: 0.30),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Ink(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: _colors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Stack(
              children: [
                // Soft bubbles for depth, clipped by the card's corners.
                const Positioned(
                  top: -26,
                  right: 40,
                  child: _Bubble(size: 70, alpha: 0.12),
                ),
                const Positioned(
                  bottom: -30,
                  right: -16,
                  child: _Bubble(size: 80, alpha: 0.10),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 14),
                  child: Row(
                    children: [
                      Container(
                        height: 44,
                        width: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Icon(icon, color: Colors.white, size: 22),
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
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              subtitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 11.5,
                                height: 1.25,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        height: 30,
                        width: 30,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.arrow_forward_rounded,
                          color: _colors[1],
                          size: 17,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
