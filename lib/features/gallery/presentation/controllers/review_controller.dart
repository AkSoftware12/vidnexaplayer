import 'package:flutter/foundation.dart';

import '../../domain/repositories/gallery_repository.dart';
import '../services/photo_signature_service.dart';

/// Shared behaviour of the two tools that delete photos.
///
/// The duplicate finder and the junk cleaner present different things, but the
/// dangerous half is identical: hold a selection, total its bytes, delete it in
/// one consented batch, then re-analyse. That half lives here so it is written
/// and reviewed once rather than twice.
///
/// Nothing is ever selected on the user's behalf. Both tools show suggestions —
/// a keeper, a bucket — but a photo only enters [selected] because someone
/// tapped it.
abstract class ReviewController extends ChangeNotifier {
  ReviewController({required this.repository});

  final GalleryRepository repository;

  final PhotoSignatureService signatures = PhotoSignatureService.instance;

  bool _loading = true;
  bool get loading => _loading;

  /// True while the signature pass is still running, so the UI can say
  /// "results so far" instead of presenting a partial scan as complete.
  bool _indexing = false;
  bool get indexing => _indexing;

  final Set<String> _selected = <String>{};
  Set<String> get selected => Set.unmodifiable(_selected);

  int get selectedCount => _selected.length;

  bool isSelected(String photoId) => _selected.contains(photoId);

  bool get hasSelection => _selected.isNotEmpty;

  /// Size on disk of one photo, from whatever the subclass is showing.
  int sizeOf(String photoId);

  /// Bytes the current selection would free.
  ///
  /// Summed over the selected ids, never by adding up group or bucket totals —
  /// a photo can appear in several buckets at once, and summing those would
  /// count the same file more than once.
  int get selectedBytes =>
      _selected.fold(0, (total, id) => total + sizeOf(id));

  /// Loads the tool's own results. Called by [refresh] once the index is ready.
  Future<void> analyse();

  /// Writes a one-line summary of the analysis just finished to
  /// [GalleryToolStatsStore], so the Tools tab can show what this tool found
  /// without re-running the scan to find it out.
  ///
  /// A no-op by default: a subclass with nothing worth quoting simply does not
  /// override it.
  Future<void> recordStats() async {}

  Future<void> refresh() async {
    _loading = true;
    _selected.clear();
    notifyListeners();

    // Incremental: a no-op when the library is already signed, a full pass the
    // first time. Either way the tool works from a current index rather than
    // silently reporting on stale data.
    _indexing = signatures.running || await signatures.signedCount() == 0;
    notifyListeners();

    await signatures.ensureSignatures();
    _indexing = false;
    notifyListeners();

    await analyse();
    await recordStats();
    _loading = false;
    notifyListeners();
  }

  void toggle(String photoId) {
    if (!_selected.remove(photoId)) _selected.add(photoId);
    notifyListeners();
  }

  void selectAllOf(Iterable<String> photoIds) {
    _selected.addAll(photoIds);
    notifyListeners();
  }

  void deselectAllOf(Iterable<String> photoIds) {
    _selected.removeAll(photoIds);
    notifyListeners();
  }

  void clearSelection() {
    _selected.clear();
    notifyListeners();
  }

  /// Deletes the selection in one batch and re-analyses.
  ///
  /// Returns how many photos were actually removed. Zero means the system
  /// consent dialog was declined — a normal outcome. The selection is kept
  /// intact in that case so the user can simply try again.
  Future<int> deleteSelected() async {
    if (_selected.isEmpty) return 0;

    final deleted = await repository.deletePhotos(_selected.toList());
    if (deleted.isEmpty) return 0;

    _selected.removeAll(deleted);
    _loading = true;
    notifyListeners();

    await analyse();
    await recordStats();
    _loading = false;
    notifyListeners();
    return deleted.length;
  }
}
