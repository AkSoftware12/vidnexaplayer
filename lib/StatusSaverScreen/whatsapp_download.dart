import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:docman/docman.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:videoplayer/StatusSaverScreen/status_saver.dart';
import 'package:videoplayer/Utils/color.dart';

import '../Photo/image_album.dart';
import '../VideoPLayer/4kPlayer/4k_player.dart';

const _prefsTreeUriKey = 'whatsapp_tree_uri';
const _prefsDownloadsKey = 'downloaded_statuses_v1';
const _galleryAlbumName = 'Status Saver';

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
  String get id => document?.uri ?? localFile!.path;

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

  Future<void> share() async {
    if (document != null) {
      await document!.share(title: 'Share status');
      return;
    }

    if (localFile == null) return;

    final tempDoc = DocumentFile(
      uri: localFile!.path,
      name: name,
      exists: true,
      type: isVideo ? 'video/mp4' : 'image/jpeg',
    );
    await tempDoc.share(title: 'Share status');
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
        if (mounted) {
          setState(() {});
        }
      });

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
          folderHint:
          'Access is allowed. Open WhatsApp, watch at least one status, then return here and tap Refresh.',
          clearDirectories: true,
        );
        return;
      }

      if (!mounted) return;
      setState(() {
        _loading = false;
        _accessMode = null;
        _allStatuses = const [];
        _folderHint =
        'Allow access first. If hidden statuses are blocked on your device, use folder selection.';
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
          _error = 'Media permission was not granted.';
          _folderHint =
          'Allow access or select the WhatsApp media folder manually.';
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
        _folderHint =
        'Access is available, but no visible statuses were found yet. Open WhatsApp and watch a status first.';
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
      } catch (_) {}
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
      _folderHint =
      'Statuses loaded. Refresh after viewing new statuses in WhatsApp.';
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
      final picked = await DocMan.pick.directory(
        initDir: _selectedDirectory?.uri,
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
        _error = 'Folder selection failed: $e';
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
          _error =
          'The .Statuses folder was not found. Select WhatsApp/Media or Android/media/.../Media.';
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
            ? 'Folder connected. Open WhatsApp, view a status, then come back and refresh.'
            : 'Folder connected. This mode is reliable on Android 11 and above.';
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Unable to load statuses: $e';
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
            folderHint:
            'Still no statuses found. Open WhatsApp, view a status, then return and refresh again.',
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
        folderHint:
        'Access granted. Open WhatsApp, watch any status, then come back and tap Refresh.',
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
      _folderHint = 'Folder reset. Pick the folder again if needed.';
      _loading = false;
      _previewFutures.clear();
      _statusById.clear();
    });
  }

  Future<File?> _previewFile(StatusItem item) {
    return _previewFutures.putIfAbsent(item.id, item.previewFile);
  }

  bool _isDownloaded(StatusItem item) => _downloadedIds.contains(item.id);

  Future<void> _saveStatus(StatusItem item) async {
    try {
      final file = await item.cacheFile();
      if (file == null) throw 'File unavailable';

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

      setState(() {
        _downloads = updated;
        _downloadedIds = updated.map((entry) => entry.id).toSet();
      });

      await _persistDownloads();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${item.typeLabel} saved to gallery.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    }
  }

  Future<void> _shareStatus(StatusItem item) async {
    try {
      await item.share();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Share failed: $e')),
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
            const SnackBar(content: Text('Video file not found')),
          );
          return;
        }

        await Navigator.push(
          context,
          MaterialPageRoute(
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
          SnackBar(content: Text('Unable to open video: $e')),
        );
        return;
      }
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StatusPreviewPage(item: item),
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    final imageCount = _imageStatuses.length;
    final videoCount = _videoStatuses.length;

    return Scaffold(
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
                    'Status Saver',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'Allow access to view and save statuses.',
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
              Navigator.push(context, MaterialPageRoute(builder: (context) => StatusSaverScreen()));

            },
            icon:  const Icon(Icons.info, color: Colors.white),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(40),
          child: Container(
            alignment: Alignment.centerLeft,
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              padding: EdgeInsets.zero,
              tabAlignment: TabAlignment.start,
              labelColor: const Color(0xFF0F172A),
              unselectedLabelColor: const Color(0xFF64748B),
              indicatorColor: const Color(0xFF0F766E),
              indicatorSize: TabBarIndicatorSize.label,
              labelPadding: const EdgeInsets.symmetric(horizontal: 12),
              tabs: [
                _tab('All', _allStatuses.length),
                _tab('Images', imageCount),
                _tab('Videos', videoCount),
                _tab('Downloads', _downloads.length),
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
    return Tab(text: '$label ($count)');
  }

  Widget _buildBody(List<StatusItem> statuses) {
    if (_loading) {
      return Center(child: AnimatedProgressIndicator());
    }

    if (_stage == HomeStage.permission) {
      return _InfoState(
        icon: Icons.lock_open_rounded,
        title: 'Allow access to load statuses',
        message:
        'On first launch, allow media access. If your device still hides the status folder, use Pick Folder.',
        primaryLabel: 'Allow Access',
        onPrimary: _enableDirectPermissionMode,
        secondaryLabel: 'Pick Folder',
        onSecondary: _pickFolder,
      );
    }

    if (_stage == HomeStage.waiting) {
      return _InfoState(
        icon: Icons.visibility_rounded,
        title: 'No statuses found yet',
        message:
        'Open WhatsApp, watch any status, then return here and tap Refresh. New statuses will appear automatically after refresh.',
        primaryLabel: 'Refresh',
        onPrimary: _refresh,
        secondaryLabel: _isSafMode ? 'Change Folder' : 'Pick Folder',
        onSecondary: _pickFolder,
      );
    }

    if (statuses.isEmpty) {
      return _InfoState(
        icon: Icons.filter_alt_off_rounded,
        title: 'Nothing in this filter',
        message:
        'Try another tab or refresh after viewing more statuses in WhatsApp.',
        primaryLabel: 'Refresh',
        onPrimary: _refresh,
      );
    }

    return Column(
      children: [
        _buildAccessBanner(context),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(5, 5, 5, 24),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 0.76,
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
        title: 'No downloads yet',
        message: 'Saved statuses will appear here with a green check mark.',
        primaryLabel: 'View statuses',
        onPrimary: () => _tabController.animateTo(0),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(5, 5, 5, 10),
      children: [
        _buildAccessBanner(context),
        ...List.generate(_downloads.length, (index) {
          final item = _downloads[index];
          final source = _statusById[item.id];

          return Padding(
            padding: const EdgeInsets.only(bottom: 0),
            child: _DownloadTile(
              item: item,
              previewFuture: source == null ? null : _previewFile(source),
              onTap: source == null
                  ? null
                  : () => _openPreview(source),
            ),
          );
        }),
      ],
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
    final statusText = switch (_stage) {
      HomeStage.permission => 'Access required',
      HomeStage.waiting => 'Waiting for statuses',
      HomeStage.ready => 'Statuses available',
    };

    final modeText = _isDirectMode
        ? 'Direct permission mode'
        : _isSafMode
        ? 'Folder access mode'
        : 'No access selected';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusText,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      modeText,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
              ),
              _StatChip(
                icon: Icons.check_circle_rounded,
                label: '${_downloads.length} saved',
                color: const Color(0xFF16A34A),
              ),
            ],
          ),
          if (_statusesDirectory != null) ...[
            const SizedBox(height: 10),
            Text(
              'Connected folder: ${_statusesDirectory!.name}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(0xFF334155),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (_folderHint != null) ...[
            const SizedBox(height: 10),
            Text(
              _folderHint!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(0xFF0F766E),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(0xFFB91C1C),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              if (!_isSafMode) ...[
                Expanded(
                  child: FilledButton(
                    onPressed: _loading ? null : _enableDirectPermissionMode,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF0F766E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Allow Access'),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: OutlinedButton(
                  onPressed: _selectingFolder ? null : _pickFolder,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(
                    _selectingFolder
                        ? 'Opening...'
                        : _isSafMode
                        ? 'Change Folder'
                        : 'Pick Folder',
                  ),
                ),
              ),
            ],
          ),
          if (_isSafMode) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _clearSavedFolder,
                child: const Text('Reset folder'),
              ),
            ),
          ],
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
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onOpen,
        child: Padding(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(5),
                        child: FutureBuilder<File?>(
                          future: previewFuture,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState !=
                                ConnectionState.done) {
                              return Container(
                                color: const Color(0xFFE2E8F0),
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              );
                            }

                            final file = snapshot.data;
                            if (file == null) {
                              return Container(
                                color: const Color(0xFFE2E8F0),
                                child: Icon(
                                  item.isVideo
                                      ? Icons.play_circle_fill_rounded
                                      : Icons.image_rounded,
                                  size: 44,
                                  color: const Color(0xFF475569),
                                ),
                              );
                            }

                            return Image.file(file, fit: BoxFit.cover);
                          },
                        ),
                      ),
                    ),
                    Positioned(
                      top: 10,
                      left: 10,
                      child: AnimatedOpacity(
                        opacity: isDownloaded ? 1 : 0,
                        duration: const Duration(milliseconds: 180),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF16A34A),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.check_rounded,
                                size: 14,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Saved',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha:0.6),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          item.typeLabel,
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 5),
              Text(
                item.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 1),
              Text(
                item.modifiedAt == null
                    ? 'Unknown date'
                    : _formatDate(item.modifiedAt!),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 30, // 🔥 height kam ki
                      child: OutlinedButton.icon(
                        onPressed: onShare,
                        icon: const Icon(Icons.share_rounded, size: 16,color: Colors.black,), // 🔥 icon small
                        label: const Text(
                          'Share',
                          style: TextStyle(fontSize: 12, color: Colors.black), // 🔥 font small
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                          minimumSize: Size.zero, // 🔥 extra space remove
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap, // 🔥 compact touch
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: SizedBox(
                      height: 30,
                      child: OutlinedButton.icon(
                        onPressed: isDownloaded ? null : onSave,
                        icon: Icon(
                          isDownloaded
                              ? Icons.check_circle_rounded
                              : Icons.download_rounded,
                          size: 16,
                          color: ColorSelect.maineColor2,
                        ),
                        label: Text(
                          isDownloaded ? 'Saved' : 'Save',
                          style:  TextStyle(fontSize: 12,color: ColorSelect.maineColor2),
                        ),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ),
                  ),
                ],
              )            ],
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(5),
      ),
      child: ListTile(
        onTap: onTap,

        contentPadding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 0,
        ),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: SizedBox(
            height: 56,
            width: 56,
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
        title: Text(
          item.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0F172A),
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            'Saved on ${_formatDate(item.savedAt)}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: const Color(0xFF64748B),
            ),
          ),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFDCFCE7),
            borderRadius: BorderRadius.circular(999),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_circle_rounded,
                size: 16,
                color: Color(0xFF16A34A),
              ),
              SizedBox(width: 6),
              Text('Downloaded'),
            ],
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
      color: const Color(0xFFE2E8F0),
      child: Icon(
        isVideo ? Icons.videocam_rounded : Icons.image_rounded,
        color: const Color(0xFF475569),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha:0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 78,
              width: 78,
              decoration: BoxDecoration(
                color: const Color(0xFFCCFBF1),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                icon,
                size: 38,
                color: const Color(0xFF0F766E),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: 220,
              child: FilledButton(
                onPressed: onPrimary,
                child: Text(primaryLabel),
              ),
            ),
            if (secondaryLabel != null && onSecondary != null) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: 220,
                child: OutlinedButton(
                  onPressed: onSecondary,
                  child: Text(secondaryLabel!,style: TextStyle(color: Colors.black),),
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
      if (file == null) throw 'Preview file unavailable';

      if (!mounted) return;
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
    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: Text(widget.item.typeLabel),
      ),
      body: Center(child: _buildPreview()),
    );
  }

  Widget _buildPreview() {
    if (_loading) {
      return const CircularProgressIndicator(color: Colors.white);
    }

    final error = _error;
    if (error != null) {
      return Text(error, style: const TextStyle(color: Colors.white));
    }

    final file = _file;
    if (file == null) {
      return const Text(
        'Preview unavailable',
        style: TextStyle(color: Colors.white),
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

    return Image.file(file, fit: BoxFit.contain);
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