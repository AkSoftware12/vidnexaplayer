import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:open_filex/open_filex.dart';

class PdfAlbumScreen extends StatefulWidget {
  const PdfAlbumScreen({super.key});

  @override
  State<PdfAlbumScreen> createState() => _PdfAlbumScreenState();
}

class _PdfAlbumScreenState extends State<PdfAlbumScreen> {
  List<AssetEntity> _pdfs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPdfs();
  }

  Future<void> _loadPdfs() async {
    final permission = await PhotoManager.requestPermissionExtend();
    if (!permission.isAuth) {
      setState(() => _loading = false);
      return;
    }

    /// 🔥 COMMON = documents (PDF yahin milte hain)
    final albums = await PhotoManager.getAssetPathList(
      type: RequestType.common,
      hasAll: true,
    );

    List<AssetEntity> allFiles = [];

    for (final album in albums) {
      final files = await album.getAssetListPaged(
        page: 0,
        size: 1000,
      );
      allFiles.addAll(files);
    }

    /// ✅ ONLY PDF FILTER
    final pdfs = allFiles.where((e) {
      return e.title?.toLowerCase().endsWith('.pdf') ?? false;
    }).toList();

    /// 🔥 latest PDF first
    pdfs.sort(
          (a, b) => b.createDateTime.compareTo(a.createDateTime),
    );

    setState(() {
      _pdfs = pdfs;
      _loading = false;
    });
  }

  Future<void> _openPdf(AssetEntity pdf) async {
    final file = await pdf.file;
    if (file != null) {
      await OpenFilex.open(file.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF Files'),
        backgroundColor: Colors.redAccent,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _pdfs.isEmpty
          ? const Center(child: Text('No PDF Found'))
          : ListView.separated(
        itemCount: _pdfs.length,
        separatorBuilder: (_, __) =>
        const Divider(height: 1),
        itemBuilder: (_, i) {
          final pdf = _pdfs[i];
          return ListTile(
            leading: const Icon(
              Icons.picture_as_pdf,
              color: Colors.red,
            ),
            title: Text(
              pdf.title ?? 'PDF File',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              pdf.createDateTime
                  .toLocal()
                  .toString()
                  .split('.')[0],
            ),
            onTap: () => _openPdf(pdf),
          );
        },
      ),
    );
  }
}
