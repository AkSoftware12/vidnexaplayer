import 'dart:io';
import 'package:file_manager/file_manager.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../NotifyListeners/LanguageProvider/home_strings.dart';
import '../NotifyListeners/LanguageProvider/language_provider.dart';
import '../Utils/safe_storage.dart';
import '../VideoPLayer/4kPlayer/4k_player.dart';

/// Folder browser.
///
/// Nothing here may touch `FileManager.getStorageList()` or the controller
/// methods that call it (`isRootDirectory`, `goToParentDirectory`): that is
/// the `RangeError (end): Invalid value` of crash 5, and it fires from three
/// different entry points inside the package. Instead this screen resolves its
/// roots through [SafeStorage] first and hands the package a controller whose
/// path is already set — which is the one branch where the package's own
/// initState skips its storage lookup entirely.
///
/// It was also a StatelessWidget holding a `FileManagerController` in a field,
/// so every rebuild built a fresh controller while the package's State kept
/// (and eventually disposed) the first one.
class DirectoryFolder extends StatefulWidget {
  const DirectoryFolder({super.key});

  @override
  State<DirectoryFolder> createState() => _DirectoryFolderState();
}

class _DirectoryFolderState extends State<DirectoryFolder> {
  final FileManagerController controller = FileManagerController();

  /// Roots from [SafeStorage], used for the "am I at the top?" test that
  /// `controller.isRootDirectory()` would otherwise answer.
  List<Directory> _roots = const [];
  bool _loading = true;
  bool _permissionDenied = false;

  @override
  void initState() {
    super.initState();
    _resolveRoots();
  }

  @override
  void dispose() {
    // The package's own State disposes this controller when the FileManager
    // widget is in the tree. It never is while _loading / _permissionDenied,
    // so those paths would leak the notifiers without this.
    if (_roots.isEmpty) controller.dispose();
    super.dispose();
  }

  Future<void> _resolveRoots() async {
    final granted = await SafeStorage.hasStoragePermission();
    if (!mounted) return;

    if (!granted) {
      setState(() {
        _loading = false;
        _permissionDenied = true;
        _roots = const [];
      });
      return;
    }

    final roots = await SafeStorage.getStorageList();
    if (!mounted) return;

    setState(() {
      _roots = roots;
      _loading = false;
      _permissionDenied = false;
      // Seeding the path is what keeps the package off its own
      // getStorageList() when FileManager mounts below.
      if (roots.isNotEmpty) controller.setCurrentPath = roots.first.path;
    });
  }

  Future<void> _requestPermission() async {
    final granted = await SafeStorage.requestStoragePermission();
    if (!mounted) return;
    if (granted) {
      setState(() => _loading = true);
      await _resolveRoots();
    } else {
      await openAppSettings();
    }
  }

  /// Back handling without `controller.isRootDirectory()`.
  Future<bool> _goBack() async {
    final current = controller.getCurrentPath;
    if (current.isEmpty) return true;
    if (_roots.any((r) => r.path == current)) return true;

    final parent = Directory(current).parent;
    // Refuse to climb above a known root even if the path is unexpected.
    if (parent.path == current) return true;
    controller.openDirectory(parent);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LocaleProvider>().locale.languageCode;
    return Scaffold(
      appBar: AppBar(
        title: ValueListenableBuilder<String>(
          valueListenable: controller.titleNotifier,
          builder: (context, title, _) =>
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () async {
            final leaveScreen = await _goBack();
            if (leaveScreen && context.mounted) Navigator.pop(context);
          },
        ),
      ),
      body: _body(lang),
    );
  }

  Widget _body(String lang) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_permissionDenied) {
      return _MessageView(
        icon: Icons.folder_off_outlined,
        title: HomeStrings.t(lang, 'dir_permission_title'),
        body: HomeStrings.t(lang, 'dir_permission_body'),
        actionLabel: HomeStrings.t(lang, 'dir_permission_grant'),
        onAction: _requestPermission,
      );
    }
    if (_roots.isEmpty) {
      return _MessageView(
        icon: Icons.sd_card_alert_outlined,
        title: HomeStrings.t(lang, 'dir_no_storage'),
        actionLabel: HomeStrings.t(lang, 'dir_retry'),
        onAction: () {
          setState(() => _loading = true);
          _resolveRoots();
        },
      );
    }
    return _fileManager(lang);
  }

  Widget _fileManager(String lang) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leaveScreen = await _goBack();
        if (leaveScreen && mounted) Navigator.pop(context);
      },
      child: FileManager(
        controller: controller,
        builder: (context, snapshot) {
          final List<FileSystemEntity> entities = snapshot;
          return ListView.builder(
            itemCount: entities.length,
            itemBuilder: (context, index) {
              final entity = entities[index];
              return Column(
                children: [
                  ListTile(
                    leading: Container(
                      height: 50.sp,
                      width: 50.sp,
                      decoration: BoxDecoration(
                        color: Colors.deepPurple,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        FileManager.isFile(entity)
                            ? Icons.play_arrow_rounded
                            : Icons.folder_open_rounded,
                        color: Colors.white,
                      ),
                    ),
                    title: Text(
                      FileManager.basename(entity,
                          showFileExtension: true),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: _subtitle(entity, lang),
                    onTap: () async {
                      if (FileManager.isDirectory(entity)) {
                        controller.openDirectory(entity);
                        return;
                      }

                      final path = entity.path.toLowerCase();

                      final isVideo = path.endsWith('.mp4') ||
                          path.endsWith('.mkv') ||
                          path.endsWith('.avi') ||
                          path.endsWith('.mov');

                      final isImage = path.endsWith('.png') ||
                          path.endsWith('.jpg') ||
                          path.endsWith('.webp') ||
                          path.endsWith('.jpeg');

                      if (!isVideo && !isImage) return;

                      // 🖼 IMAGE → direct open (NO AssetEntity)
                      if (isImage) {
                        if (!context.mounted) return;

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            settings: const RouteSettings(name: 'FullScreenImageViewer'),
                            builder: (_) => FullScreenImageViewer(
                              imagePath: entity.path,
                            ),
                          ),
                        );
                        return;
                      }

                      // 🎥 VIDEO → AssetEntity required
                      if (isVideo) {
                        final asset = await _getAssetFromPath(entity.path);
                        if (asset == null || !context.mounted) return;

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            settings: const RouteSettings(name: 'VideoPlayerScreen'),
                            builder: (_) => FullScreenVideoPlayerFixed(
                              videos: [asset],
                              initialIndex: 0,
                            ),
                          ),
                        );
                      }
                    },
                  ),
                  Divider(height: 1, color: Colors.grey.shade300),
                ],
              );
            },
          );
        },
      ),
    );
  }

  // ---------------- SUBTITLE ----------------

  Widget _subtitle(FileSystemEntity entity, String lang) {
    return FutureBuilder<FileStat>(
      future: entity.stat(),
      builder: (_, snap) {
        if (!snap.hasData) return const SizedBox();
        if (FileManager.isFile(entity)) {
          return Text(FileManager.formatBytes(snap.data!.size));
        }
        return Text(HomeStrings.t(lang, 'dir_folder_label'));
      },
    );
  }

  // ---------------- FILE PATH → ASSET ----------------
  Future<AssetEntity?> _getAssetFromPath(String path) async {
    final permission = await PhotoManager.requestPermissionExtend();
    if (!permission.isAuth) return null;

    final albums = await PhotoManager.getAssetPathList(
      type: RequestType.video,
      hasAll: true,
    );

    for (final album in albums) {
      final count = await album.assetCountAsync;
      final assets = await album.getAssetListRange(
        start: 0,
        end: count,
      );

      for (final asset in assets) {
        final file = await asset.file;
        if (file?.path == path) {
          return asset;
        }
      }
    }
    return null;
  }
}







/// Empty / permission state for the folder browser.
///
/// The screen used to have neither: a denied permission and a device with no
/// readable volume both fell through to the package's error page, which just
/// prints the exception.
class _MessageView extends StatelessWidget {
  const _MessageView({
    required this.icon,
    required this.title,
    required this.actionLabel,
    required this.onAction,
    this.body,
  });

  final IconData icon;
  final String title;
  final String? body;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: Colors.grey.shade500),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: scheme.secondary,
              ),
            ),
            if (body != null) ...[
              const SizedBox(height: 8),
              Text(
                body!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}

class FullScreenImageViewer extends StatefulWidget {
  final String imagePath;

  const FullScreenImageViewer({
    super.key,
    required this.imagePath,
  });

  @override
  State<FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<FullScreenImageViewer> {
  bool _showUI = true;

  @override
  Widget build(BuildContext context) {
    final file = File(widget.imagePath);
    final lang = context.watch<LocaleProvider>().locale.languageCode;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 🖼 FULL SCREEN IMAGE
          Positioned.fill(
            child: file.existsSync()
                ? GestureDetector(
              onTap: () => setState(() => _showUI = !_showUI),
              child: InteractiveViewer(
                minScale: 1.0,
                maxScale: 4.0,
                child: SizedBox(
                  width: double.infinity,
                  height: double.infinity,
                  child: Image.file(
                    file,
                    fit: BoxFit.cover, // 🔥 gallery style
                  ),
                ),
              ),
            )
                : Center(
              child: Text(
                HomeStrings.t(lang, 'dir_image_not_found'),
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),


          AnimatedPositioned(
            duration: const Duration(milliseconds: 200),
            top: _showUI ? 40 : -60,
            left: 16,
            child: SafeArea(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: Container(
                  color: Colors.black.withValues(alpha:0.55),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

