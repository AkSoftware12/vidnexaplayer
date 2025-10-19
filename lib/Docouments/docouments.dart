import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

class AllDevicePdfsScreen extends StatefulWidget {
  @override
  State<AllDevicePdfsScreen> createState() => _AllDevicePdfsScreenState();
}

class _AllDevicePdfsScreenState extends State<AllDevicePdfsScreen> {
  List<File> _pdfFiles = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchPdfs();
  }

  Future<void> _fetchPdfs() async {
    var status = await Permission.manageExternalStorage.request();
    if (status.isGranted) {
      var pdfs = await getAllPdfs("/storage/emulated/0/");
      setState(() {
        _pdfFiles = pdfs;
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('All Device PDFs')),
      body: _loading
          ? Center(child: CircularProgressIndicator())
          : ListView.builder(
        itemCount: _pdfFiles.length,
        itemBuilder: (context, index) {
          final file = _pdfFiles[index];
          return ListTile(
            title: Text(file.path.split('/').last),
            subtitle: Text(file.path),
            onTap: () {
              // PDF ko yahan open/view kar sakte hain
            },
          );
        },
      ),
    );
  }
}

Future<List<File>> getAllPdfs(String rootPath) async {
  final List<File> pdfFiles = [];
  final rootDir = Directory(rootPath);
  await for (var entity in rootDir.list(recursive: true, followLinks: false)) {
    if (entity is File && entity.path.toLowerCase().endsWith('.pdf')) {
      pdfFiles.add(entity);
    }
  }
  return pdfFiles;
}
