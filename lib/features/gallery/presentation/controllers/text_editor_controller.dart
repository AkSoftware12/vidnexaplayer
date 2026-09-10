import 'package:flutter/foundation.dart';

import '../../domain/entities/text_overlay.dart';

/// Holds the text layers placed on one photo.
///
/// Pure state — it knows nothing about how the overlays are drawn or exported.
/// The page owns the `RepaintBoundary`; this owns what goes inside it.
class TextEditorController extends ChangeNotifier {
  final List<TextOverlay> _overlays = [];
  List<TextOverlay> get overlays => List.unmodifiable(_overlays);

  String? _selectedId;
  String? get selectedId => _selectedId;

  TextOverlay? get selected {
    final id = _selectedId;
    if (id == null) return null;
    for (final overlay in _overlays) {
      if (overlay.id == id) return overlay;
    }
    return null;
  }

  bool get isEmpty => _overlays.isEmpty;

  /// Monotonic, so ids stay unique even after deletions.
  int _nextId = 0;

  TextOverlay add(String text) {
    final overlay = TextOverlay(
      id: 'overlay-${_nextId++}',
      text: text,
      // New layers land slightly above centre — dead centre tends to sit on
      // the subject's face.
      dy: 0.42,
    );
    _overlays.add(overlay);
    _selectedId = overlay.id;
    notifyListeners();
    return overlay;
  }

  void select(String? id) {
    if (_selectedId == id) return;
    _selectedId = id;
    notifyListeners();
  }

  void update(String id, TextOverlay Function(TextOverlay) change) {
    final index = _overlays.indexWhere((overlay) => overlay.id == id);
    if (index < 0) return;
    _overlays[index] = change(_overlays[index]);
    notifyListeners();
  }

  /// Applies [change] to whatever is selected. Every style control goes
  /// through here, so none of them need to know which layer is active.
  void updateSelected(TextOverlay Function(TextOverlay) change) {
    final id = _selectedId;
    if (id == null) return;
    update(id, change);
  }

  void remove(String id) {
    _overlays.removeWhere((overlay) => overlay.id == id);
    if (_selectedId == id) _selectedId = null;
    notifyListeners();
  }

  /// Moves the selected layer to the end of the list, which is the top of the
  /// stack — tapping a layer should bring it in front of the others.
  void bringToFront(String id) {
    final index = _overlays.indexWhere((overlay) => overlay.id == id);
    if (index < 0 || index == _overlays.length - 1) return;
    final overlay = _overlays.removeAt(index);
    _overlays.add(overlay);
    notifyListeners();
  }
}
