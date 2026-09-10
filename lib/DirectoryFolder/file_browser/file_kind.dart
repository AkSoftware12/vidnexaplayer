import 'package:flutter/material.dart';

/// How a file is presented in the browser: which icon, which accent, and which
/// bucket the Documents tab filters on.
///
/// Extension-based rather than MIME-based on purpose. SAF hands back a MIME
/// type, but a huge share of real-world files on Android arrive as
/// `application/octet-stream` (anything a downloader wrote without sniffing the
/// content), and the extension is then the only usable signal.
enum FileKind {
  folder,
  video,
  image,
  audio,
  pdf,
  document,
  spreadsheet,
  presentation,
  text,
  archive,
  apk,
  other;

  /// Extensions that count as "a document" for the Documents tab. Media is
  /// deliberately excluded — Videos/Photos/Music have their own tabs backed by
  /// MediaStore, which is faster and needs no folder pick.
  static const Set<FileKind> documentKinds = {
    FileKind.pdf,
    FileKind.document,
    FileKind.spreadsheet,
    FileKind.presentation,
    FileKind.text,
    FileKind.archive,
    FileKind.apk,
  };

  static const Map<String, FileKind> _byExtension = {
    // video
    'mp4': FileKind.video, 'mkv': FileKind.video, 'avi': FileKind.video,
    'mov': FileKind.video, 'wmv': FileKind.video, 'flv': FileKind.video,
    'webm': FileKind.video, '3gp': FileKind.video, 'm4v': FileKind.video,
    'ts': FileKind.video, 'mpg': FileKind.video, 'mpeg': FileKind.video,
    // image
    'jpg': FileKind.image, 'jpeg': FileKind.image, 'png': FileKind.image,
    'gif': FileKind.image, 'webp': FileKind.image, 'bmp': FileKind.image,
    'heic': FileKind.image, 'heif': FileKind.image, 'svg': FileKind.image,
    // audio
    'mp3': FileKind.audio, 'm4a': FileKind.audio, 'wav': FileKind.audio,
    'flac': FileKind.audio, 'aac': FileKind.audio, 'ogg': FileKind.audio,
    'opus': FileKind.audio, 'wma': FileKind.audio, 'amr': FileKind.audio,
    // documents
    'pdf': FileKind.pdf,
    'doc': FileKind.document, 'docx': FileKind.document,
    'odt': FileKind.document, 'rtf': FileKind.document,
    'xls': FileKind.spreadsheet, 'xlsx': FileKind.spreadsheet,
    'csv': FileKind.spreadsheet, 'ods': FileKind.spreadsheet,
    'ppt': FileKind.presentation, 'pptx': FileKind.presentation,
    'odp': FileKind.presentation,
    'txt': FileKind.text, 'md': FileKind.text, 'log': FileKind.text,
    'json': FileKind.text, 'xml': FileKind.text, 'html': FileKind.text,
    'epub': FileKind.text,
    'zip': FileKind.archive, 'rar': FileKind.archive, '7z': FileKind.archive,
    'tar': FileKind.archive, 'gz': FileKind.archive,
    'apk': FileKind.apk,
  };

  /// Classifies by the part after the last dot. Returns [FileKind.other] for
  /// anything unrecognised, including names with no extension at all.
  static FileKind of(String name) {
    final dot = name.lastIndexOf('.');
    if (dot < 0 || dot == name.length - 1) return FileKind.other;
    final ext = name.substring(dot + 1).toLowerCase();
    return _byExtension[ext] ?? FileKind.other;
  }

  bool get isDocument => documentKinds.contains(this);

  IconData get icon => switch (this) {
        FileKind.folder => Icons.folder_rounded,
        FileKind.video => Icons.play_circle_fill_rounded,
        FileKind.image => Icons.image_rounded,
        FileKind.audio => Icons.music_note_rounded,
        FileKind.pdf => Icons.picture_as_pdf_rounded,
        FileKind.document => Icons.description_rounded,
        FileKind.spreadsheet => Icons.table_chart_rounded,
        FileKind.presentation => Icons.slideshow_rounded,
        FileKind.text => Icons.article_rounded,
        FileKind.archive => Icons.folder_zip_rounded,
        FileKind.apk => Icons.android_rounded,
        FileKind.other => Icons.insert_drive_file_rounded,
      };

  Color get color => switch (this) {
        FileKind.folder => const Color(0xFF6C4DF6),
        FileKind.video => const Color(0xFFFF7043),
        FileKind.image => const Color(0xFFEC407A),
        FileKind.audio => const Color(0xFF7E57C2),
        FileKind.pdf => const Color(0xFFE53935),
        FileKind.document => const Color(0xFF1E88E5),
        FileKind.spreadsheet => const Color(0xFF2E7D32),
        FileKind.presentation => const Color(0xFFEF6C00),
        FileKind.text => const Color(0xFF546E7A),
        FileKind.archive => const Color(0xFF8D6E63),
        FileKind.apk => const Color(0xFF43A047),
        FileKind.other => const Color(0xFF78909C),
      };
}

/// `1536` -> `1.5 KB`. Returns an empty string for a non-positive size, which
/// is what SAF reports when it simply does not know.
String formatBytes(int bytes) {
  if (bytes <= 0) return '';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  final digits = value >= 100 || unit == 0 ? 0 : 1;
  return '${value.toStringAsFixed(digits)} ${units[unit]}';
}
