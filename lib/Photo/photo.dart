import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:provider/provider.dart';

import 'full_image.dart';





class SimpleExamplePage extends StatefulWidget {
  const SimpleExamplePage();

  @override
  _SimpleExamplePageState createState() => _SimpleExamplePageState();
}

class _SimpleExamplePageState extends State<SimpleExamplePage> {
  final int _sizePerPage = 50;

  AssetPathEntity? _path;
  List<AssetEntity>? _entities;
  int _totalEntitiesCount = 0;

  int _page = 0;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMoreToLoad = true;

  Future<void> _requestAssets() async {
    setState(() {
      _isLoading = true;
    });
    // Request permissions.
    final PermissionState ps = await PhotoManager.requestPermissionExtend();
    if (!mounted) {
      return;
    }
    // Further requests can be only proceed with authorized or limited.
    if (!ps.hasAccess) {
      setState(() {
        _isLoading = false;
      });
      // showToast('Permission is not accessible.');
      return;
    }
    // Customize your own filter options.
    final PMFilter filter = FilterOptionGroup(
      imageOption: const FilterOption(
        sizeConstraint: SizeConstraint(ignoreSize: true),
      ),
    );
    // Obtain assets using the path entity.
    final List<AssetPathEntity> paths = await PhotoManager.getAssetPathList(
      onlyAll: true,
      filterOption: filter,
    );
    if (!mounted) {
      return;
    }
    // Return if not paths found.
    if (paths.isEmpty) {
      setState(() {
        _isLoading = false;
      });
      // showToast('No paths found.');
      return;
    }
    setState(() {
      _path = paths.first;
    });
    _totalEntitiesCount = await _path!.assetCountAsync;
    final List<AssetEntity> entities = await _path!.getAssetListPaged(
      page: 0,
      size: _sizePerPage,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _entities = entities;
      _isLoading = false;
      _hasMoreToLoad = _entities!.length < _totalEntitiesCount;
    });
  }

  Future<void> _loadMoreAsset() async {
    final List<AssetEntity> entities = await _path!.getAssetListPaged(
      page: _page + 1,
      size: _sizePerPage,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _entities!.addAll(entities);
      _page++;
      _hasMoreToLoad = _entities!.length < _totalEntitiesCount;
      _isLoadingMore = false;
    });
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }
    if (_path == null) {
      return const Center(child: Text('Request paths first.'));
    }
    if (_entities == null || _entities!.isEmpty) {
      return const Center(child: Text('No assets found on this device.'));
    }

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 4.0,
        crossAxisSpacing: 4.0,
      ),
      itemCount: _entities!.length + (_isLoadingMore ? 1 : 0), // Add 1 for loading indicator
      itemBuilder: (BuildContext context, int index) {
        // Trigger loading more assets when nearing the end
        if (index == _entities!.length - 8 && !_isLoadingMore && _hasMoreToLoad) {
          _loadMoreAssetSafely(); // Call a safer version of _loadMoreAsset
        }

        // Show loading indicator at the end
        if (index == _entities!.length && _isLoadingMore) {
          return const Center(child: CircularProgressIndicator.adaptive());
        }

        // Build image item
        final AssetEntity entity = _entities![index];
        return ImageItemWidget(
          key: ValueKey(entity.id), // Unique key for recycling
          entity: entity,
          entities: _entities!, // Fix: Use _entities instead of assetList
          option: const ThumbnailOption(size: ThumbnailSize(200, 200)),
        );
      },
    );
  }

  Future<void> _loadMoreAssetSafely() async {
    if (_isLoadingMore || !_hasMoreToLoad) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      // Example: Fetch more assets (replace with your actual logic)
      final newAssets = await _path!.getAssetListPaged(page: 1, size: 20);
      if (newAssets.isEmpty) {
        setState(() {
          _hasMoreToLoad = false;
        });
      } else {
        setState(() {
          _entities!.addAll(newAssets);
        });
      }
    } catch (e) {
      // Handle errors (e.g., show a snackbar)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load more assets: $e')),
      );
    } finally {
      setState(() {
        _isLoadingMore = false;
      });
    }
  }
  @override
  void initState() {
    super.initState();
    _requestAssets();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Gallery',style: TextStyle(
        color: Colors.white
      ),),backgroundColor: Colors.black,),
      body: Column(
        children: <Widget>[
          //  Padding(
          //   padding: EdgeInsets.all(8.0),
          //   child: Text(
          //     _totalEntitiesCount.toString(),
          //     style: TextStyle(color: Colors.black),
          //   ),
          // ),
          Expanded(child: _buildBody(context)),
        ],
      ),
      // floatingActionButton: FloatingActionButton(
      //   onPressed: _requestAssets,
      //   child: const Icon(Icons.developer_board),
      // ),
    );
  }
}

class ImageItemWidget extends StatelessWidget {
  final AssetEntity entity;
  final List<AssetEntity> entities; // List of all images
  final ThumbnailOption option;

  const ImageItemWidget({
    Key? key,
    required this.entity,
    required this.entities,
    required this.option,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FullImageScreen(
              entity: entity,
              entities: entities,
              initialIndex: entities.indexOf(entity), // Pass the initial index
            ),
          ),
        );
      },
      child: FutureBuilder<Uint8List?>(
        future: entity.thumbnailDataWithOption(option),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return const Center(child: Icon(Icons.error));
          } else if (!snapshot.hasData || snapshot.data == null) {
            return const Center(child: Icon(Icons.image_not_supported));
          } else {
            return Padding(
              padding: const EdgeInsets.all(4.0),
              child: ClipRRect(
                borderRadius: const BorderRadius.all(Radius.circular(10)),
                child: Image.memory(
                  snapshot.data!,
                  fit: BoxFit.cover,
                ),
              ),
            );
          }
        },
      ),
    );
  }
}