/// Human-readable file sizes.
///
/// Uses 1024-based units with the familiar KB/MB/GB labels — what a file
/// manager shows, which is what a user comparing this screen against their
/// storage settings will expect.
String formatBytes(int bytes) {
  if (bytes <= 0) return '0 KB';
  const unit = 1024;
  if (bytes < unit) return '$bytes B';
  if (bytes < unit * unit) {
    return '${(bytes / unit).toStringAsFixed(0)} KB';
  }
  if (bytes < unit * unit * unit) {
    final mb = bytes / (unit * unit);
    // One decimal below 10 MB, none above — "8.4 MB" is useful, "412.7 MB"
    // is just noise.
    return '${mb.toStringAsFixed(mb < 10 ? 1 : 0)} MB';
  }
  return '${(bytes / (unit * unit * unit)).toStringAsFixed(2)} GB';
}
