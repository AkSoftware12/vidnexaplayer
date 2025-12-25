import 'dart:io';
import 'package:file_manager/file_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:photo_manager/photo_manager.dart';
import '../Photo/image_album.dart';
import '../VideoPLayer/4kPlayer/4k_player.dart';

class DirectoryFolder extends StatelessWidget {
  final FileManagerController controller = FileManagerController();

  DirectoryFolder({super.key});

  @override
  Widget build(BuildContext context) {
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
            // 🔥 Root check
            final isRoot = await controller.isRootDirectory();

            if (isRoot) {
              // ⬅️ Screen back
              Navigator.pop(context);
            } else {
              // 📁 Folder back
              await controller.goToParentDirectory();
            }
          },
        ),
      ),
      body: FileManager(
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
                    subtitle: _subtitle(entity),
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
  Widget _subtitle(FileSystemEntity entity) {
    return FutureBuilder<FileStat>(
      future: entity.stat(),
      builder: (_, snap) {
        if (!snap.hasData) return const SizedBox();
        if (FileManager.isFile(entity)) {
          return Text(FileManager.formatBytes(snap.data!.size));
        }
        return const Text("Folder");
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
                : const Center(
              child: Text(
                'Image not found',
                style: TextStyle(color: Colors.white),
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
                  color: Colors.black.withOpacity(0.55),
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

