import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:docman/docman.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:videoplayer/Analytics/screen_analytics.dart';
import 'package:videoplayer/StatusSaverScreen/status_saver.dart';
import 'package:videoplayer/Utils/color.dart';

import '../NotifyListeners/LanguageProvider/device_strings.dart';
import '../NotifyListeners/LanguageProvider/language_provider.dart';
import '../ads/app_open_ad_manager.dart';
import '../ads/rewarded_unlock.dart';
import '../ads/rewarded_unlock_prompt.dart';
import '../Utils/animated_progress_indicator.dart';
import '../Utils/app_palette.dart';
import '../VideoPLayer/4kPlayer/4k_player.dart';

const _prefsTreeUriKey = 'whatsapp_tree_uri';
const _prefsDownloadsKey = 'downloaded_statuses_v1';
const _galleryAlbumName = 'Status Saver';

/// Document URI for WhatsApp's status folder on primary storage.
///
/// Handed to the folder picker as its starting point. The path is the modern
/// scoped-storage location — WhatsApp moved out of `/WhatsApp/Media` years ago
/// — and `%3A` / `%2F` are the encoded `:` and `/` that the external-storage
/// provider expects in a document id.
const _whatsAppStatusesTreeUri =
    'content://com.android.externalstorage.documents/document/'
    'primary%3AAndroid%2Fmedia%2Fcom.whatsapp%2FWhatsApp%2FMedia%2F.Statuses';

/// The one accent this screen leans on: selected tab, connected-folder state,
/// primary buttons. It was previously retyped as a literal in a half-dozen
/// places, which is how three of them ended up slightly different teals.
const _kAccent = Color(0xFF0F766E);

/// Saved / downloaded green — the only other colour with a meaning attached.
const _kSaved = Color(0xFF16A34A);

class StatusItem {
  const StatusItem({
    required this.name,
    required this.modifiedAt,
    required this.isVideo,
    this.localFile,
    this.document,
  });

  final String name;
  final DateTime? modifiedAt;
  final bool isVideo;
  final File? localFile;
  final DocumentFile? document;

  bool get isImage => !isVideo;
  String get typeLabel => isVideo ? 'Video' : 'Image';
  // Falls back to `name` instead of `localFile!.path` — nothing enforces
  // "at least one of document/localFile is non-null" as an invariant, so a
  // bare `!` here would crash on any future call site that doesn't follow
  // today's construction convention.
  String get id => document?.uri ?? localFile?.path ?? name;

  Future<File?> previewFile() async {
    if (localFile != null) return localFile;
    if (document == null) return null;

    if (isVideo) {
      return document!.thumbnailFile(width: 512, height: 512, quality: 80);
    }
    return document!.cache(imageQuality: 80);
  }

  Future<File?> cacheFile() async {
    if (localFile != null) return localFile;
    return document?.cache();
  }

  Future<void> share({String shareTitle = 'Share status'}) async {
    if (document != null) {
      await document!.share(title: shareTitle);
      return;
    }

    if (localFile == null) return;

    final tempDoc = DocumentFile(
      uri: localFile!.path,
      name: name,
      exists: true,
      type: isVideo ? 'video/mp4' : 'image/jpeg',
    );
    await tempDoc.share(title: shareTitle);
  }
}

class DownloadedStatus {
  const DownloadedStatus({
    required this.id,
    required this.name,
    required this.isVideo,
    required this.savedAt,
  });

  final String id;
  final String name;
  final bool isVideo;
  final DateTime savedAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'isVideo': isVideo,
    'savedAt': savedAt.toIso8601String(),
  };

  factory DownloadedStatus.fromJson(Map<String, dynamic> json) {
    return DownloadedStatus(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Status',
      isVideo: json['isVideo'] as bool? ?? false,
      savedAt:
      DateTime.tryParse(json['savedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class DirectAccessResult {
  const DirectAccessResult({
    required this.permissionGranted,
    required this.statuses,
  });

  final bool permissionGranted;
  final List<StatusItem> statuses;
}

enum AccessMode { directPermission, saf }

enum HomeStage { permission, waiting, ready }

class StatusSaverHomePage extends StatefulWidget {
  const StatusSaverHomePage({super.key});

  @override
  State<StatusSaverHomePage> createState() => _StatusSaverHomePageState();
}

class _StatusSaverHomePageState extends State<StatusSaverHomePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  static const List<String> _tabScreenNames = <String>[
    'StatusSaverScreen_All',
    'StatusSaverScreen_Images',
    'StatusSaverScreen_Videos',
    'StatusSaverScreen_Downloads',
  ];

  void _reportTab(int index) {
    if (index < 0 || index >= _tabScreenNames.length) return;
    ScreenAnalytics.instance.setScreen(_tabScreenNames[index]);
  }

  final Map<String, Future<File?>> _previewFutures = {};
  final Map<String, StatusItem> _statusById = {};

  bool _loading = true;
  bool _refreshing = false;
  bool _selectingFolder = false;

  String? _error;
  String? _folderHint;

  AccessMode? _accessMode;

  List<StatusItem> _allStatuses = const [];
  List<DownloadedStatus> _downloads = const [];
  Set<String> _downloadedIds = <String>{};

  DocumentFile? _selectedDirectory;
  DocumentFile? _statusesDirectory;

  HomeStage get _stage {
    if (_accessMode == null) return HomeStage.permission;
    if (_allStatuses.isEmpty) return HomeStage.waiting;
    return HomeStage.ready;
  }

  List<StatusItem> get _imageStatuses =>
      _allStatuses.where((item) => item.isImage).toList();

  List<StatusItem> get _videoStatuses =>
      _allStatuses.where((item) => item.isVideo).toList();

  bool get _isSafMode => _accessMode == AccessMode.saf;
  bool get _isDirectMode => _accessMode == AccessMode.directPermission;

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 4, vsync: this)
      ..addListener(() {
        if (!mounted) return;
        setState(() {});
        // Chaaron tab ek hi route par hain — Firebase ko naam yahan se jaata
        // hai. `indexIsChanging` ke dauraan controller baar baar notify karta
        // hai, isliye sirf jam chuke index par report karte hain.
        if (!_tabController.indexIsChanging) _reportTab(_tabController.index);
      });

    _reportTab(_tabController.index);

    unawaited(_bootstrap());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _loadDownloadsFromPrefs();

      // 1) Pehle saved picker folder restore karo
      final prefs = await SharedPreferences.getInstance();
      final savedUri = prefs.getString(_prefsTreeUriKey);

      if (savedUri != null && savedUri.isNotEmpty) {
        final restored = await DocumentFile(uri: savedUri).get();
        if (restored != null && restored.exists && restored.isDirectory) {
          await _loadSafStatuses(restored, saveSelection: false);
          return;
        } else {
          await prefs.remove(_prefsTreeUriKey);
        }
      }

      // 2) Folder restore na ho tab direct permission check karo
      final directResult = await _tryDirectPermissionFlow(
        showErrors: false,
        requestIfNeeded: false,
      );

      if (directResult.permissionGranted && directResult.statuses.isNotEmpty) {
        _setDirectState(directResult.statuses);
        return;
      }

      if (directResult.permissionGranted) {
        _setWaitingState(
          accessMode: AccessMode.directPermission,
          statuses: const [],
          folderHint: DeviceStrings.t(_langCode, 'wa_hint_access_allowed_watch'),
          clearDirectories: true,
        );
        return;
      }

      if (!mounted) return;
      setState(() {
        _loading = false;
        _accessMode = null;
        _allStatuses = const [];
        _folderHint = DeviceStrings.t(_langCode, 'wa_hint_allow_access_first');
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  Future<void> _loadDownloadsFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsDownloadsKey);

    if (raw == null || raw.isEmpty) return;

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      final downloads = decoded
          .map(
            (entry) => DownloadedStatus.fromJson(
          Map<String, dynamic>.from(entry as Map),
        ),
      )
          .where((entry) => entry.id.isNotEmpty)
          .toList()
        ..sort((a, b) => b.savedAt.compareTo(a.savedAt));

      _downloads = downloads;
      _downloadedIds = downloads.map((entry) => entry.id).toSet();
    } catch (_) {
      _downloads = const [];
      _downloadedIds = <String>{};
    }
  }

  Future<void> _persistDownloads() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(_downloads.map((item) => item.toJson()).toList());
    await prefs.setString(_prefsDownloadsKey, raw);
  }

  Future<bool> _hasDirectPermissions() async {
    if (!Platform.isAndroid) return false;

    final photosStatus = await Permission.photos.status;
    final videosStatus = await Permission.videos.status;
    final storageStatus = await Permission.storage.status;

    return storageStatus.isGranted ||
        (photosStatus.isGranted && videosStatus.isGranted);
  }

  Future<bool> _requestDirectPermissionsOnce() async {
    if (!Platform.isAndroid) return false;

    if (await _hasDirectPermissions()) return true;

    final photos = await Permission.photos.request();
    final videos = await Permission.videos.request();

    if (photos.isGranted && videos.isGranted) {
      return true;
    }

    final storage = await Permission.storage.request();

    return storage.isGranted ||
        ((await Permission.photos.status).isGranted &&
            (await Permission.videos.status).isGranted);
  }

  Future<DirectAccessResult> _tryDirectPermissionFlow({
    required bool showErrors,
    required bool requestIfNeeded,
  }) async {
    final granted = requestIfNeeded
        ? await _requestDirectPermissionsOnce()
        : await _hasDirectPermissions();

    if (!granted) {
      if (showErrors && mounted) {
        setState(() {
          _error = DeviceStrings.t(_langCode, 'wa_error_permission_not_granted');
          _folderHint = DeviceStrings.t(_langCode, 'wa_hint_allow_or_select_folder');
          _accessMode = null;
        });
      }
      return const DirectAccessResult(
        permissionGranted: false,
        statuses: [],
      );
    }

    final statuses = await _loadDirectStatuses();

    if (statuses.isEmpty && showErrors && mounted) {
      setState(() {
        _error = null;
        _folderHint = DeviceStrings.t(_langCode, 'wa_hint_access_available_no_statuses');
      });
    }

    return DirectAccessResult(
      permissionGranted: true,
      statuses: statuses,
    );
  }

  Future<List<StatusItem>> _loadDirectStatuses() async {
    final candidateDirs = <String>[
      '/storage/emulated/0/WhatsApp/Media/.Statuses',
      '/storage/emulated/0/WhatsApp Business/Media/.Statuses',
      '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/.Statuses',
      '/storage/emulated/0/Android/media/com.whatsapp.w4b/WhatsApp Business/Media/.Statuses',
    ];

    final files = <FileSystemEntity>[];

    for (final dirPath in candidateDirs) {
      final dir = Directory(dirPath);
      if (!await dir.exists()) continue;

      try {
        files.addAll(await dir.list().toList());
      } catch (error) {
        // Logged, not swallowed. This is where Android's scoped-storage block
        // actually surfaces, and an empty `catch` here is what made the screen
        // look like "WhatsApp has no statuses" rather than "this path is not
        // readable on your Android version" — which sent the diagnosis in
        // entirely the wrong direction.
        debugPrint('StatusSaver: cannot list $dirPath — $error');
      }
    }

    final statuses = files
        .whereType<File>()
        .where((file) {
      final name =
      file.path.split(Platform.pathSeparator).last.toLowerCase();
      return name.endsWith('.jpg') ||
          name.endsWith('.jpeg') ||
          name.endsWith('.png') ||
          name.endsWith('.webp') ||
          name.endsWith('.mp4');
    })
        .map((file) {
      final stat = file.statSync();
      final name = file.path.split(Platform.pathSeparator).last;

      return StatusItem(
        name: name,
        modifiedAt: stat.modified,
        isVideo: name.toLowerCase().endsWith('.mp4'),
        localFile: file,
      );
    })
        .toList()
      ..sort(
            (a, b) => (b.modifiedAt ?? DateTime(1970))
            .compareTo(a.modifiedAt ?? DateTime(1970)),
      );

    return statuses;
  }

  void _indexStatuses(List<StatusItem> statuses) {
    _statusById
      ..clear()
      ..addEntries(statuses.map((item) => MapEntry(item.id, item)));
  }

  void _setDirectState(List<StatusItem> statuses) {
    if (!mounted) return;

    _previewFutures.clear();
    _indexStatuses(statuses);

    setState(() {
      _loading = false;
      _accessMode = AccessMode.directPermission;
      _allStatuses = statuses;
      _error = null;
      _folderHint = DeviceStrings.t(_langCode, 'wa_hint_statuses_loaded');
      _selectedDirectory = null;
      _statusesDirectory = null;
    });
  }

  void _setWaitingState({
    required AccessMode accessMode,
    required List<StatusItem> statuses,
    required String folderHint,
    required bool clearDirectories,
    DocumentFile? selectedDirectory,
    DocumentFile? statusesDirectory,
  }) {
    if (!mounted) return;

    _previewFutures.clear();
    _indexStatuses(statuses);

    setState(() {
      _loading = false;
      _accessMode = accessMode;
      _allStatuses = statuses;
      _error = null;
      _folderHint = folderHint;
      _selectedDirectory = clearDirectories ? null : selectedDirectory;
      _statusesDirectory = clearDirectories ? null : statusesDirectory;
    });
  }

  Future<void> _pickFolder() async {
    if (_selectingFolder) return;

    setState(() {
      _selectingFolder = true;
      _error = null;
    });

    try {
      // Open the picker already standing in WhatsApp's `.Statuses` folder, so
      // the user taps Allow once instead of walking down five nested
      // directories to a hidden one they cannot see by default.
      //
      // `initDir` becomes `DocumentsContract.EXTRA_INITIAL_URI`. It is a hint,
      // not a guarantee — the system may ignore it — but the fallback is the
      // ordinary picker, which is exactly where the user was starting before.
      final picked = await DocMan.pick.directory(
        initDir: _selectedDirectory?.uri ?? _whatsAppStatusesTreeUri,
      );

      if (picked == null) {
        if (!mounted) return;
        setState(() => _selectingFolder = false);
        return;
      }

      await _loadSafStatuses(picked, saveSelection: true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _selectingFolder = false;
        _loading = false;
        _error = '${DeviceStrings.t(_langCode, 'wa_error_folder_selection_failed_prefix')}$e';
      });
    }
  }

  Future<void> _loadSafStatuses(
      DocumentFile selected, {
        required bool saveSelection,
      }) async {
    setState(() {
      _loading = true;
      _selectingFolder = false;
      _error = null;
    });

    try {
      final statusesDir = await _resolveStatusesDirectory(selected);

      if (statusesDir == null) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _selectedDirectory = selected;
          _statusesDirectory = null;
          _allStatuses = const [];
          _accessMode = AccessMode.saf;
          _error = DeviceStrings.t(_langCode, 'wa_error_statuses_folder_not_found');
        });
        return;
      }

      final files = await statusesDir.listDocuments(
        extensions: const ['jpg', 'jpeg', 'png', 'webp', 'mp4'],
      );

      final statuses = files
          .where((file) => file.isFile)
          .where((file) => !file.name.startsWith('.'))
          .map(
            (file) => StatusItem(
          name: file.name,
          modifiedAt: file.lastModifiedDate,
          isVideo: file.name.toLowerCase().endsWith('.mp4'),
          document: file,
        ),
      )
          .toList()
        ..sort(
              (a, b) => (b.modifiedAt ?? DateTime(1970))
              .compareTo(a.modifiedAt ?? DateTime(1970)),
        );

      if (saveSelection) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_prefsTreeUriKey, selected.uri);
      }

      _previewFutures.clear();
      _indexStatuses(statuses);

      if (!mounted) return;
      setState(() {
        _loading = false;
        _accessMode = AccessMode.saf;
        _selectedDirectory = selected;
        _statusesDirectory = statusesDir;
        _allStatuses = statuses;
        _folderHint = statuses.isEmpty
            ? DeviceStrings.t(_langCode, 'wa_hint_folder_connected_watch')
            : DeviceStrings.t(_langCode, 'wa_hint_folder_connected_reliable');
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '${DeviceStrings.t(_langCode, 'wa_error_unable_load_statuses_prefix')}$e';
      });
    }
  }

  Future<DocumentFile?> _resolveStatusesDirectory(DocumentFile selected) async {
    if (!selected.exists || !selected.isDirectory) return null;

    if (selected.name == '.Statuses') {
      return selected;
    }

    Future<DocumentFile?> child(DocumentFile parent, String name) =>
        parent.find(name);

    final directStatuses = await child(selected, '.Statuses');
    if (directStatuses != null && directStatuses.isDirectory) {
      return directStatuses;
    }

    final mediaDir = await child(selected, 'Media');
    if (mediaDir != null && mediaDir.isDirectory) {
      final statuses = await child(mediaDir, '.Statuses');
      if (statuses != null && statuses.isDirectory) return statuses;
    }

    final whatsappDir = await child(selected, 'WhatsApp');
    if (whatsappDir != null && whatsappDir.isDirectory) {
      final media = await child(whatsappDir, 'Media');
      final statuses = media == null ? null : await child(media, '.Statuses');
      if (statuses != null && statuses.isDirectory) return statuses;
    }

    final businessDir = await child(selected, 'WhatsApp Business');
    if (businessDir != null && businessDir.isDirectory) {
      final media = await child(businessDir, 'Media');
      final statuses = media == null ? null : await child(media, '.Statuses');
      if (statuses != null && statuses.isDirectory) return statuses;
    }

    final androidDir = await child(selected, 'Android');
    final mediaRoot = androidDir == null
        ? await child(selected, 'media')
        : await child(androidDir, 'media');

    if (mediaRoot != null && mediaRoot.isDirectory) {
      for (final packageName in ['com.whatsapp', 'com.whatsapp.w4b']) {
        final packageDir = await child(mediaRoot, packageName);
        if (packageDir == null || !packageDir.isDirectory) continue;

        for (final appDirName in ['WhatsApp', 'WhatsApp Business']) {
          final appDir = await child(packageDir, appDirName);
          if (appDir == null || !appDir.isDirectory) continue;

          final media = await child(appDir, 'Media');
          if (media == null || !media.isDirectory) continue;

          final statuses = await child(media, '.Statuses');
          if (statuses != null && statuses.isDirectory) return statuses;
        }
      }
    }

    return null;
  }

  Future<void> _refresh() async {
    if (_refreshing) return;

    setState(() => _refreshing = true);

    try {
      if (_isSafMode && _selectedDirectory != null) {
        await _loadSafStatuses(_selectedDirectory!, saveSelection: false);
      } else if (_isDirectMode) {
        final result = await _tryDirectPermissionFlow(
          showErrors: false,
          requestIfNeeded: false,
        );

        if (result.permissionGranted && result.statuses.isNotEmpty) {
          _setDirectState(result.statuses);
        } else if (result.permissionGranted) {
          _setWaitingState(
            accessMode: AccessMode.directPermission,
            statuses: const [],
            folderHint: DeviceStrings.t(_langCode, 'wa_hint_still_no_statuses'),
            clearDirectories: true,
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _refreshing = false);
      }
    }
  }

  Future<void> _enableDirectPermissionMode() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await _tryDirectPermissionFlow(
      showErrors: true,
      requestIfNeeded: true,
    );

    if (result.permissionGranted && result.statuses.isNotEmpty) {
      _setDirectState(result.statuses);
      return;
    }

    if (result.permissionGranted) {
      _setWaitingState(
        accessMode: AccessMode.directPermission,
        statuses: const [],
        folderHint: DeviceStrings.t(_langCode, 'wa_hint_access_granted_watch'),
        clearDirectories: true,
      );
      return;
    }

    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _clearSavedFolder() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsTreeUriKey);

    if (!mounted) return;
    setState(() {
      _selectedDirectory = null;
      _statusesDirectory = null;
      _accessMode = null;
      _allStatuses = const [];
      _error = null;
      _folderHint = DeviceStrings.t(_langCode, 'wa_hint_folder_reset');
      _loading = false;
      _previewFutures.clear();
      _statusById.clear();
    });
  }

  Future<File?> _previewFile(StatusItem item) {
    return _previewFutures.putIfAbsent(item.id, item.previewFile);
  }

  bool _isDownloaded(StatusItem item) => _downloadedIds.contains(item.id);

  /// Current language code, read (not watched) — used from event handlers
  /// and async callbacks outside `build()`.
  String get _langCode => context.read<LocaleProvider>().locale.languageCode;

  String _typeLabel(bool isVideo, String lang) =>
      DeviceStrings.t(lang, isVideo ? 'wa_type_video' : 'wa_type_image');

  Future<void> _saveStatus(StatusItem item) async {
    // Saving is the one thing here that costs anything — it copies the file
    // out of WhatsApp's folder and into the gallery — so it is what the
    // rewarded ad buys. One ad opens a 30-minute window for *all* saves, not
    // one ad per status: charging per file would mean four ads to save four
    // statuses, which is the kind of pacing that gets an app uninstalled.
    //
    // Premium skips this entirely (see ensureRewardedUnlock).
    final unlocked = await ensureRewardedUnlock(
      context,
      feature: RewardedUnlock.statusSaver,
      titleKey: 'rewarded_status_saver_title',
      bodyKey: 'rewarded_status_saver_body',
    );
    if (!unlocked || !mounted) return;

    try {
      final file = await item.cacheFile();
      if (file == null) throw DeviceStrings.t(_langCode, 'wa_file_unavailable');

      if (item.isVideo) {
        await Gal.putVideo(file.path, album: _galleryAlbumName);
      } else {
        await Gal.putImage(file.path, album: _galleryAlbumName);
      }

      final record = DownloadedStatus(
        id: item.id,
        name: item.name,
        isVideo: item.isVideo,
        savedAt: DateTime.now(),
      );

      final updated = [
        record,
        ..._downloads.where((entry) => entry.id != item.id),
      ];

      // Update the fields regardless of `mounted` — persistence below must
      // still happen even if the user navigated away right as the save
      // finished. Only the `setState` UI-rebuild call needs the guard.
      _downloads = updated;
      _downloadedIds = updated.map((entry) => entry.id).toSet();
      if (mounted) setState(() {});

      await _persistDownloads();

      if (!mounted) return;
      final lang = _langCode;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            DeviceStrings.t(lang, 'wa_saved_to_gallery')
                .replaceAll('{type}', _typeLabel(item.isVideo, lang)),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${DeviceStrings.t(_langCode, 'wa_save_failed_prefix')}$e')),
      );
    }
  }

  Future<void> _shareStatus(StatusItem item) async {
    try {
      await item.share(shareTitle: DeviceStrings.t(_langCode, 'wa_share_status_title'));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${DeviceStrings.t(_langCode, 'wa_share_failed_prefix')}$e')),
      );
    }
  }

  // Future<void> _openPreview(StatusItem item) async {
  //
  //   await Navigator.of(context).push(
  //     MaterialPageRoute(
  //       builder: (_) => StatusPreviewPage(item: item),
  //     ),
  //   );
  // }

  Future<void> _openPreview(StatusItem item) async {
    if (item.isVideo) {
      try {
        final file = await item.cacheFile();

        if (file == null || !await file.exists()) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(DeviceStrings.t(_langCode, 'wa_video_not_found'))),
          );
          return;
        }

        // `cacheFile()` copies through a platform channel and `exists()` is a
        // second IO hop — the screen can be popped in between, and pushing
        // onto a dead Navigator throws.
        if (!mounted) return;

        await Navigator.push(
          context,
          MaterialPageRoute(
            settings: const RouteSettings(name: 'VideoPlayerScreen'),
            builder: (_) => FullScreenVideoPlayerFixed(
              videos: const [],
              initialIndex: 0,
              initialUrl: Uri.file(file.path).toString(),
            ),
          ),
        );
        return;
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${DeviceStrings.t(_langCode, 'wa_unable_open_video_prefix')}$e')),
        );
        return;
      }
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: 'StatusPreviewScreen'),
        builder: (_) => StatusPreviewPage(item: item),
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    AppPalette.sync(context);
    final lang = context.watch<LocaleProvider>().locale.languageCode;
    final imageCount = _imageStatuses.length;
    final videoCount = _videoStatuses.length;

    return Scaffold(
      backgroundColor: AppPalette.surface,
      appBar: AppBar(
        backgroundColor: ColorSelect.maineColor2,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DeviceStrings.t(lang, 'wa_title'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    DeviceStrings.t(lang, 'wa_subtitle'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white70,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _refreshing ? null : _refresh,
            icon: _refreshing
                ? const SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
                : const Icon(Icons.refresh_rounded, color: Colors.white),
          ),
          IconButton(
            onPressed: (){
              Navigator.push(context, MaterialPageRoute(builder: (context) => StatusSaverScreen(), settings: const RouteSettings(name: 'StatusSaverGuideScreen')));

            },
            icon:  const Icon(Icons.info, color: Colors.white),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Container(
            alignment: Alignment.centerLeft,
            color: AppPalette.card,
            padding: const EdgeInsets.fromLTRB(8, 2, 8, 8),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              padding: EdgeInsets.zero,
              tabAlignment: TabAlignment.start,
              dividerColor: Colors.transparent,
              labelColor: Colors.white,
              unselectedLabelColor: AppPalette.textS,

              // A filled pill says "you are here" at a glance. The 2px
              // underline it replaces sat under a scrollable strip of four
              // similar-looking labels and was easy to miss entirely.
              indicator: BoxDecoration(
                color: _kAccent,
                borderRadius: BorderRadius.circular(999),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              overlayColor: WidgetStateProperty.all(Colors.transparent),
              splashBorderRadius: BorderRadius.circular(999),
              labelPadding: const EdgeInsets.only(right: 6),
              tabs: [
                _tab(DeviceStrings.t(lang, 'wa_tab_all'), _allStatuses.length),
                _tab(DeviceStrings.t(lang, 'wa_tab_images'), imageCount),
                _tab(DeviceStrings.t(lang, 'wa_tab_videos'), videoCount),
                _tab(DeviceStrings.t(lang, 'wa_tab_downloads'), _downloads.length),
              ],
            ),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.only(bottom: 50.0),
        child: TabBarView(
          controller: _tabController,
          physics: const BouncingScrollPhysics(),
          children: [
            _buildBody(_allStatuses),
            _buildBody(_imageStatuses),
            _buildBody(_videoStatuses),
            _buildDownloadsTab(),
          ],
        ),
      ),
    );
  }

  Tab _tab(String label, int count) {
    return Tab(
      height: 36,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 7),

            // The count rides in its own translucent chip rather than in
            // "(12)" brackets, so it stays legible both on the teal pill and
            // on the card behind it — the tint is drawn from the label colour
            // the TabBar already hands down for the current state.
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: const Color(0xFF808A99).withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(List<StatusItem> statuses) {
    if (_loading) {
      return Center(child: AnimatedProgressIndicator());
    }

    final lang = _langCode;

    if (_stage == HomeStage.permission) {
      return _InfoState(
        icon: Icons.lock_open_rounded,
        title: DeviceStrings.t(lang, 'wa_permission_title'),
        message: DeviceStrings.t(lang, 'wa_permission_message'),
        primaryLabel: DeviceStrings.t(lang, 'wa_allow_access'),
        onPrimary: _enableDirectPermissionMode,
        secondaryLabel: DeviceStrings.t(lang, 'wa_pick_folder'),
        onSecondary: _pickFolder,
      );
    }

    if (_stage == HomeStage.waiting) {
      // On Android 13+ direct file access to another app's
      // `Android/media/.../.Statuses` does not work at all: READ_MEDIA_* grants
      // MediaStore access, not filesystem access, and WhatsApp deliberately
      // keeps that hidden folder out of MediaStore. Picking the folder through
      // SAF is the only route that works — verified on a device holding six
      // statuses that direct access reported as zero.
      //
      // So once a direct scan has come back empty, Pick Folder becomes the
      // primary action. Leading with Refresh sent the user round a loop that
      // could never succeed, and the old copy blamed WhatsApp for it.
      final needsFolder = !_isSafMode;

      return _InfoState(
        icon: needsFolder
            ? Icons.folder_open_rounded
            : Icons.visibility_rounded,
        title: DeviceStrings.t(
          lang,
          needsFolder ? 'wa_pick_folder_title' : 'wa_waiting_title',
        ),
        message: DeviceStrings.t(
          lang,
          needsFolder ? 'wa_pick_folder_message' : 'wa_waiting_message',
        ),
        primaryLabel: DeviceStrings.t(
          lang,
          needsFolder ? 'wa_pick_folder' : 'wa_refresh',
        ),
        onPrimary: needsFolder ? _pickFolder : _refresh,
        secondaryLabel: DeviceStrings.t(
          lang,
          needsFolder ? 'wa_refresh' : 'wa_change_folder',
        ),
        onSecondary: needsFolder ? _refresh : _pickFolder,
      );
    }

    if (statuses.isEmpty) {
      return _InfoState(
        icon: Icons.filter_alt_off_rounded,
        title: DeviceStrings.t(lang, 'wa_empty_filter_title'),
        message: DeviceStrings.t(lang, 'wa_empty_filter_message'),
        primaryLabel: DeviceStrings.t(lang, 'wa_refresh'),
        onPrimary: _refresh,
      );
    }

    return Column(
      children: [
        _buildAccessBanner(context),

        // Native ad above the grid, not inside it: a grid cell is a tap target
        // for saving a status, and an ad sitting among them would collect
        // mis-taps that AdMob counts as clicks. It disappears on its own for
        // premium users — NativeAdCard gates itself.
        AppOpenAdManager().nativeCompactWidget(
          margin: const EdgeInsets.fromLTRB(8, 4, 8, 0),
        ),

        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 24),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.72,
            ),
            itemCount: statuses.length,
            itemBuilder: (context, index) {
              final item = statuses[index];
              return _StatusCard(
                item: item,
                previewFuture: _previewFile(item),
                isDownloaded: _isDownloaded(item),
                onOpen: () => _openPreview(item),
                onSave: () => _saveStatus(item),
                onShare: () => _shareStatus(item),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDownloadsTab() {
    if (_downloads.isEmpty) {
      return _InfoState(
        icon: Icons.download_done_rounded,
        title: DeviceStrings.t(_langCode, 'wa_no_downloads_title'),
        message: DeviceStrings.t(_langCode, 'wa_no_downloads_message'),
        primaryLabel: DeviceStrings.t(_langCode, 'wa_view_statuses'),
        onPrimary: () => _tabController.animateTo(0),
      );
    }

    // ListView.builder, not ListView(children: [...]): the old version called
    // `_previewFile()` for EVERY saved status on every rebuild and held all of
    // the resulting decoded thumbnails alive at once. On a device with a few
    // hundred saved statuses that is the java.lang.OutOfMemoryError. Index 0
    // is the access banner so it scrolls with the list as before.
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
      itemCount: _downloads.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) return _buildAccessBanner(context);

        final item = _downloads[index - 1];
        final source = _statusById[item.id];

        return _DownloadTile(
          item: item,
          previewFuture: source == null ? null : _previewFile(source),
          onTap: source == null ? null : () => _openPreview(source),
        );
      },
    );
  }

  /// Shows the access/error panel only when there is something to report.
  ///
  /// The full panel used to be commented out at both call sites, which meant
  /// `_error` — set in 15+ places ("Media permission was not granted",
  /// "Folder selection failed", "Unable to load statuses", …) — was never shown
  /// to the user. Failures looked like an empty screen.
  Widget _buildAccessBanner(BuildContext context) {
    if (_error == null && _folderHint == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: _buildAccessPanel(context),
    );
  }

  Widget _buildAccessPanel(BuildContext context) {
    final lang = _langCode;

    final statusText = switch (_stage) {
      HomeStage.permission => DeviceStrings.t(lang, 'wa_status_access_required'),
      HomeStage.waiting => DeviceStrings.t(lang, 'wa_status_waiting_for_statuses'),
      HomeStage.ready => DeviceStrings.t(lang, 'wa_status_available'),
    };

    final modeText = _isDirectMode
        ? DeviceStrings.t(lang, 'wa_mode_direct')
        : _isSafMode
        ? DeviceStrings.t(lang, 'wa_mode_folder')
        : DeviceStrings.t(lang, 'wa_mode_none');

    // One compact status strip instead of a tall card.
    //
    // The old panel repeated itself — a full-width "Change Folder" button and
    // a "Reset folder" link that do nearly the same job — and that button
    // rendered as an empty outline, because an OutlinedButton with no explicit
    // foreground took its colour from the app theme and came out invisible on
    // this white surface. Both are replaced by one labelled action.
    final connected = _statusesDirectory != null;
    final accent =
        connected ? _kAccent : const Color(0xFFB45309);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppPalette.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  connected
                      ? Icons.folder_special_rounded
                      : Icons.folder_off_rounded,
                  color: accent,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppPalette.textH,
                      ),
                    ),
                    Text(
                      connected
                          ? '${DeviceStrings.t(lang, 'wa_connected_folder_prefix')}'
                              '${_statusesDirectory!.name}'
                          : modeText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppPalette.textS,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _StatChip(
                icon: Icons.check_circle_rounded,
                label: DeviceStrings.t(lang, 'wa_saved_count')
                    .replaceAll('{count}', '${_downloads.length}'),
                color: _kSaved,
              ),
            ],
          ),

          // Errors still get their own line; a hint that only repeats the
          // folder name above does not.
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(0xFFB91C1C),
                fontWeight: FontWeight.w600,
              ),
            ),
          ] else if (_folderHint != null && !connected) ...[
            const SizedBox(height: 8),
            Text(
              _folderHint!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],

          const SizedBox(height: 10),
          Row(
            children: [
              if (!_isSafMode) ...[
                Expanded(
                  child: FilledButton(
                    onPressed: _loading ? null : _enableDirectPermissionMode,
                    style: FilledButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(DeviceStrings.t(lang, 'wa_allow_access')),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: OutlinedButton(
                  onPressed: _selectingFolder ? null : _pickFolder,
                  style: OutlinedButton.styleFrom(
                    // Explicit, not inherited — this is the bug that produced
                    // an empty-looking button.
                    foregroundColor: accent,
                    side: BorderSide(color: accent.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    _selectingFolder
                        ? DeviceStrings.t(lang, 'wa_opening')
                        : _isSafMode
                            ? DeviceStrings.t(lang, 'wa_change_folder')
                            : DeviceStrings.t(lang, 'wa_pick_folder'),
                  ),
                ),
              ),

              // Forgetting the saved folder is a different thing from picking
              // another one, and it is the only way out if the grant ever goes
              // stale — so it stays reachable, just as an icon rather than a
              // second full-width button competing with the one beside it.
              if (_isSafMode) ...[
                const SizedBox(width: 6),
                IconButton(
                  onPressed: _clearSavedFolder,
                  icon: const Icon(Icons.link_off_rounded, size: 20),
                  color: AppPalette.textS,
                  tooltip: DeviceStrings.t(lang, 'wa_reset_folder'),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.item,
    required this.previewFuture,
    required this.isDownloaded,
    required this.onOpen,
    required this.onSave,
    required this.onShare,
  });

  final StatusItem item;
  final Future<File?> previewFuture;
  final bool isDownloaded;
  final VoidCallback onOpen;
  final VoidCallback onSave;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    AppPalette.sync(context);
    final lang = context.watch<LocaleProvider>().locale.languageCode;

    // The whole tile is the thumbnail now.
    //
    // The old card spent nearly half its height on a filename
    // ("IMG-20260910-WA0007.jpg"), a date and two bordered text buttons — four
    // rows of chrome around a postage-stamp preview, on a screen whose entire
    // job is letting you recognise a status by looking at it. The image goes
    // full-bleed and everything else floats over a scrim at the bottom, which
    // roughly doubles the visible preview at the same cell size.
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Material(
        color: AppPalette.raised,
        child: InkWell(
          onTap: onOpen,
          child: Stack(
            fit: StackFit.expand,
            children: [
              FutureBuilder<File?>(
                future: previewFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(
                      child: SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  }

                  final file = snapshot.data;
                  if (file == null) {
                    return Center(
                      child: Icon(
                        item.isVideo
                            ? Icons.videocam_rounded
                            : Icons.image_rounded,
                        size: 40,
                        color: AppPalette.textS,
                      ),
                    );
                  }

                  return Image.file(file, fit: BoxFit.cover);
                },
              ),

              // Scrim: without it, white labels vanish over a bright status.
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 96,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.78),
                        Colors.black.withValues(alpha: 0.34),
                        Colors.transparent,
                      ],
                      stops: const [0, 0.55, 1],
                    ),
                  ),
                ),
              ),

              if (item.isVideo)
                const Center(
                  child: Icon(
                    Icons.play_circle_fill_rounded,
                    size: 46,
                    color: Colors.white70,
                  ),
                ),

              // Type marker, top-right — an icon carries it, so the word
              // "Video" no longer competes with the preview.
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    item.isVideo
                        ? Icons.videocam_rounded
                        : Icons.photo_rounded,
                    size: 14,
                    color: Colors.white,
                    semanticLabel: item.isVideo
                        ? DeviceStrings.t(lang, 'wa_type_video')
                        : DeviceStrings.t(lang, 'wa_type_image'),
                  ),
                ),
              ),

              Positioned(
                top: 8,
                left: 8,
                child: AnimatedScale(
                  scale: isDownloaded ? 1 : 0,
                  curve: Curves.easeOutBack,
                  duration: const Duration(milliseconds: 220),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _kSaved,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.check_rounded,
                          size: 12,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          DeviceStrings.t(lang, 'wa_saved'),
                          style: const TextStyle(
                            fontSize: 10,
                            height: 1.2,
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              Positioned(
                left: 10,
                right: 8,
                bottom: 8,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.modifiedAt == null
                            ? DeviceStrings.t(lang, 'wa_unknown_date')
                            : _formatDate(item.modifiedAt!),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    _GlassAction(
                      icon: Icons.share_rounded,
                      tooltip: DeviceStrings.t(lang, 'wa_share'),
                      onTap: onShare,
                    ),
                    const SizedBox(width: 6),
                    _GlassAction(
                      icon: isDownloaded
                          ? Icons.check_rounded
                          : Icons.download_rounded,
                      tooltip: isDownloaded
                          ? DeviceStrings.t(lang, 'wa_saved')
                          : DeviceStrings.t(lang, 'wa_save'),
                      background: isDownloaded ? _kSaved : _kAccent,
                      onTap: isDownloaded ? null : onSave,
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

/// Round action button that sits on top of a thumbnail.
///
/// Kept opaque rather than genuinely translucent: a `BackdropFilter` per button
/// would mean two extra render-to-texture passes in every one of the grid
/// cells on screen, and this grid already scrolls decoded bitmaps.
class _GlassAction extends StatelessWidget {
  const _GlassAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.background,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final base = background ?? Colors.black;
    final disabled = onTap == null;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: base.withValues(
          alpha: background == null ? 0.45 : (disabled ? 0.75 : 1),
        ),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 32,
            height: 32,
            child: Icon(icon, size: 16, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class _DownloadTile extends StatelessWidget {
  const _DownloadTile({
    required this.item,
    this.previewFuture, this.onTap,
  });

  final DownloadedStatus item;
  final Future<File?>? previewFuture;
  final VoidCallback? onTap;


  @override
  Widget build(BuildContext context) {
    AppPalette.sync(context);
    final lang = context.watch<LocaleProvider>().locale.languageCode;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        // Was hardcoded white, which turned this list into a stack of glaring
        // white slabs the moment the app was in dark mode.
        color: AppPalette.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppPalette.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onTap,

        contentPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 6,
        ),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            height: 52,
            width: 52,
            child: previewFuture == null
                ? _DownloadPlaceholder(isVideo: item.isVideo)
                : FutureBuilder<File?>(
              future: previewFuture,
              builder: (context, snapshot) {
                final file = snapshot.data;
                if (snapshot.connectionState != ConnectionState.done ||
                    file == null) {
                  return _DownloadPlaceholder(isVideo: item.isVideo);
                }
                return Image.file(file, fit: BoxFit.cover);
              },
            ),
          ),
        ),
        // Not `item.name`.
        //
        // The gallery saver names its files by content hash, so every row's
        // headline was 40 characters of "841927da637e42cbab8f9b2db2dd5055…"
        // — the widest, boldest text on the screen, and unreadable. The type
        // is the only thing about the name a user could act on; the date
        // underneath is what actually distinguishes one row from the next.
        title: Text(
          DeviceStrings.t(
            lang,
            item.isVideo ? 'wa_type_video' : 'wa_type_image',
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppPalette.textH,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Text(
            DeviceStrings.t(lang, 'wa_saved_on')
                .replaceAll('{date}', _formatDate(item.savedAt)),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppPalette.textS,
            ),
          ),
        ),

        // Every row in this tab is downloaded by definition, so the word was
        // pure repetition down the whole list — a tick is enough.
        trailing: Container(
          height: 28,
          width: 28,
          decoration: BoxDecoration(
            color: _kSaved.withValues(alpha: 0.14),
            shape: BoxShape.circle,
          ),
          child: Tooltip(
            message: DeviceStrings.t(lang, 'wa_downloaded'),
            child: const Icon(
              Icons.check_rounded,
              size: 17,
              color: _kSaved,
            ),
          ),
        ),
      ),
    );
  }
}

class _DownloadPlaceholder extends StatelessWidget {
  const _DownloadPlaceholder({required this.isVideo});

  final bool isVideo;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppPalette.raised,
      child: Icon(
        isVideo ? Icons.videocam_rounded : Icons.image_rounded,
        color: AppPalette.textS,
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoState extends StatelessWidget {
  const _InfoState({
    required this.icon,
    required this.title,
    required this.message,
    required this.primaryLabel,
    required this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });

  final IconData icon;
  final String title;
  final String message;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    AppPalette.sync(context);

    // Every colour here used to be a light-mode literal — including a
    // `TextStyle(color: Colors.black)` on the secondary button, which put
    // black text on a dark background. All of it now comes from the palette.
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 92,
              width: 92,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    _kAccent.withValues(alpha: 0.20),
                    _kAccent.withValues(alpha: 0.06),
                  ],
                ),
                border: Border.all(color: _kAccent.withValues(alpha: 0.22)),
              ),
              child: Icon(icon, size: 40, color: _kAccent),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppPalette.textH,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppPalette.textS,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: 240,
              height: 46,
              child: FilledButton(
                onPressed: onPrimary,
                style: FilledButton.styleFrom(
                  backgroundColor: _kAccent,
                  foregroundColor: Colors.white,
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(primaryLabel),
              ),
            ),
            if (secondaryLabel != null && onSecondary != null) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: 240,
                height: 46,
                child: OutlinedButton(
                  onPressed: onSecondary,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppPalette.textB,
                    side: BorderSide(color: AppPalette.border),
                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(secondaryLabel!),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class StatusPreviewPage extends StatefulWidget {
  const StatusPreviewPage({
    super.key,
    required this.item,
  });

  final StatusItem item;

  @override
  State<StatusPreviewPage> createState() => _StatusPreviewPageState();
}

class _StatusPreviewPageState extends State<StatusPreviewPage> {
  File? _file;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_prepare());
  }

  Future<void> _prepare() async {
    try {
      final file = await widget.item.cacheFile();
      if (!mounted) return;

      if (file == null) {
        throw DeviceStrings.t(
          context.read<LocaleProvider>().locale.languageCode,
          'wa_preview_file_unavailable',
        );
      }

      setState(() {
        _file = file;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LocaleProvider>().locale.languageCode;

    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: Text(
          widget.item.isVideo
              ? DeviceStrings.t(lang, 'wa_type_video')
              : DeviceStrings.t(lang, 'wa_type_image'),
        ),
      ),
      body: Center(child: _buildPreview(lang)),
    );
  }

  Widget _buildPreview(String lang) {
    if (_loading) {
      return const CircularProgressIndicator(color: Colors.white);
    }

    final error = _error;
    if (error != null) {
      return Padding(
        padding: const EdgeInsets.all(28),
        child: Text(
          error,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, height: 1.4),
        ),
      );
    }

    final file = _file;
    if (file == null) {
      return Padding(
        padding: const EdgeInsets.all(28),
        child: Text(
          DeviceStrings.t(lang, 'wa_preview_unavailable'),
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, height: 1.4),
        ),
      );
    }

    // Video statuses used to be handed to `Image.file`, which can never decode
    // an mp4 — the preview was always a broken-image box.
    if (widget.item.isVideo) {
      return FullScreenVideoPlayerFixed(
        videos: const [],
        initialUrl: Uri.file(file.path).toString(),
      );
    }

    // Pinch-to-zoom: a status is often a screenshot of text, and a
    // fit-to-screen still was not readable on a phone.
    return InteractiveViewer(
      minScale: 1,
      maxScale: 4,
      child: Image.file(file, fit: BoxFit.contain),
    );
  }
}

String _formatDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  final year = date.year.toString();
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final minute = date.minute.toString().padLeft(2, '0');
  final suffix = date.hour >= 12 ? 'PM' : 'AM';
  return '$day/$month/$year  $hour:$minute $suffix';
}
