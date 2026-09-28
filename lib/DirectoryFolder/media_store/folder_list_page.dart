import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../NotifyListeners/LanguageProvider/home_strings.dart';
import '../../NotifyListeners/LanguageProvider/language_provider.dart';
import '../../Utils/app_palette.dart';
import '../file_browser/file_kind.dart';
import 'media_list_page.dart';
import 'media_store.dart';

/// Every folder that holds files, biggest first.
///
/// No folder picker. The old Folders tab could not show anything until the user
/// walked the system picker to a directory and granted it; this is built from
/// the paths MediaStore already records, so it opens straight into the list.
///
/// Tapping a row opens that folder's files in a [MediaListPage] — a separate
/// screen rather than a panel inside this one, which is the shape asked for.
class FolderListPage extends StatefulWidget {
  const FolderListPage({super.key, this.accent = const Color(0xFF6C4DF6)});

  final Color accent;

  @override
  State<FolderListPage> createState() => _FolderListPageState();
}

class _FolderListPageState extends State<FolderListPage> {
  List<MediaFolder> _folders = const [];
  bool _loading = true;
  String _query = '';
  bool _searchOpen = false;
  final TextEditingController _searchCtrl = TextEditingController();

  String get _lang => context.read<LocaleProvider>().locale.languageCode;
  String _t(String key) => HomeStrings.t(_lang, key);

  @override
  void initState() {
    super.initState();
    final cached = MediaStoreRepo.instance.cachedFolders;
    if (cached != null) {
      _folders = cached;
      _loading = false;
    }
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({bool refresh = false}) async {
    final rows = await MediaStoreRepo.instance.folders(refresh: refresh);
    if (!mounted) return;
    setState(() {
      _folders = rows;
      _loading = false;
    });
  }

  List<MediaFolder> get _visible {
    if (_query.isEmpty) return _folders;
    final q = _query.toLowerCase();
    return _folders
        .where((f) => f.path.toLowerCase().contains(q))
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    AppPalette.sync(context);
    final rows = _visible;

    return Scaffold(
      backgroundColor: AppPalette.surface,
      appBar: AppBar(
        backgroundColor: AppPalette.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppPalette.textH,
        titleSpacing: 0,
        title: _searchOpen
            ? TextField(
                controller: _searchCtrl,
                autofocus: true,
                style: TextStyle(fontSize: 14, color: AppPalette.textH),
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: _t('fb_search_hint'),
                  hintStyle: TextStyle(fontSize: 14, color: AppPalette.textS),
                ),
                onChanged: (v) => setState(() => _query = v.trim()),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _t('fb_tab_folders'),
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppPalette.textH,
                    ),
                  ),
                  if (!_loading)
                    Text(
                      _t('fb_items_count')
                          .replaceAll('{count}', '${rows.length}'),
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 10.5,
                        color: AppPalette.textS,
                      ),
                    ),
                ],
              ),
        actions: [
          IconButton(
            tooltip: _t('fb_search_hint'),
            onPressed: () => setState(() {
              _searchOpen = !_searchOpen;
              if (!_searchOpen) {
                _query = '';
                _searchCtrl.clear();
              }
            }),
            icon: Icon(_searchOpen ? Icons.close_rounded : Icons.search_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: widget.accent,
        onRefresh: () => _load(refresh: true),
        child: _loading
            ? Center(child: CircularProgressIndicator(color: widget.accent))
            : rows.isEmpty
                ? ListView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 120,
                    ),
                    children: [
                      Icon(
                        Icons.folder_off_rounded,
                        size: 44,
                        color: AppPalette.textS,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        _query.isEmpty
                            ? _t('fb_no_files')
                            : _t('fb_no_matches'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppPalette.textS,
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                    itemCount: rows.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (context, i) {
                      final folder = rows[i];
                      return _FolderTile(
                        folder: folder,
                        accent: widget.accent,
                        itemsLabel: _t('fb_items_count'),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            settings: const RouteSettings(
                              name: 'FolderFilesScreen',
                            ),
                            builder: (_) => MediaListPage(
                              kind: MediaKind.all,
                              title: folder.name,
                              accent: widget.accent,
                              folderPath: folder.path,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}

class _FolderTile extends StatelessWidget {
  const _FolderTile({
    required this.folder,
    required this.accent,
    required this.itemsLabel,
    required this.onTap,
  });

  final MediaFolder folder;
  final Color accent;
  final String itemsLabel;
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Row(
            children: [
              Container(
                height: 42,
                width: 42,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.folder_rounded, color: accent, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      folder.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppPalette.textH,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${itemsLabel.replaceAll('{count}', '${folder.count}')}'
                      '  ·  ${formatBytes(folder.bytes)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10.5, color: AppPalette.textS),
                    ),
                    const SizedBox(height: 2),
                    // The full relative path, because folder names repeat:
                    // three different apps all ship a "Media" directory.
                    Text(
                      folder.path,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 9.5,
                        color: AppPalette.textS.withValues(alpha: 0.75),
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
