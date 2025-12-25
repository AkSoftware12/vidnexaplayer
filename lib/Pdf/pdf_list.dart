import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:open_filex/open_filex.dart';

class PdfListScreen extends StatefulWidget {
  final AssetPathEntity album;

  const PdfListScreen({super.key, required this.album});

  @override
  State<PdfListScreen> createState() => _PdfListScreenState();
}

class _PdfListScreenState extends State<PdfListScreen> {
  List<AssetEntity> _pdfs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPdfs();
  }

  Future<void> _loadPdfs() async {
    final files = await widget.album.getAssetListPaged(
      page: 0,
      size: 1000,
    );

    /// 🔥 PDF FILTER (SDK 3.x SAFE)
    final pdfs = files.where((asset) {
      return asset.title?.toLowerCase().endsWith('.pdf') ?? false;
    }).toList();

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
        title: Text(widget.album.name),
        backgroundColor: Colors.redAccent,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _pdfs.isEmpty
          ? const Center(child: Text('No PDF Files'))
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
            title:
            Text(pdf.title ?? 'PDF File'),
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
