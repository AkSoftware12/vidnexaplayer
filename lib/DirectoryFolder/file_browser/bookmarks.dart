import 'dart:convert';

import 'package:docman/docman.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One saved place in the file tree.
class Bookmark {
  const Bookmark({required this.uri, required this.name});

  final String uri;
  final String name;

  Map<String, dynamic> toJson() => {'uri': uri, 'name': name};

  factory Bookmark.fromJson(Map<String, dynamic> json) => Bookmark(
        uri: json['uri'] as String? ?? '',
        name: json['name'] as String? ?? '',
      );
}

/// Favourites: folders the user pinned so they do not have to walk the tree
/// again.
///
/// Only the document URI is stored, not a path — a SAF uri is the only durable
/// handle there is, and it stays valid as long as the grant that covers it
/// does. A bookmark whose grant is gone resolves to null and is dropped on the
/// next read rather than sitting in the list as a row that does nothing.
class Bookmarks extends ChangeNotifier {
  Bookmarks._();
  static final Bookmarks instance = Bookmarks._();

  static const _prefsKey = 'file_browser_bookmarks_v1';

  List<Bookmark> _items = const [];
  bool _loaded = false;

  List<Bookmark> get items => _items;
  bool get isLoaded => _loaded;

  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    _items = _decode(prefs.getString(_prefsKey));
    _loaded = true;
    notifyListeners();
  }

  bool contains(String uri) => _items.any((b) => b.uri == uri);

  Future<void> toggle(DocumentFile dir) async {
    final existing = contains(dir.uri);
    final next = existing
        ? _items.where((b) => b.uri != dir.uri).toList()
        : [..._items, Bookmark(uri: dir.uri, name: dir.name)];
    await _save(next);
  }

  Future<void> remove(String uri) async {
    await _save(_items.where((b) => b.uri != uri).toList());
  }

  /// Resolves a bookmark to a live document, dropping it if the grant is gone.
  Future<DocumentFile?> resolve(Bookmark bookmark) async {
    try {
      final doc = await DocumentFile(uri: bookmark.uri).get();
      if (doc == null || !doc.exists) {
        await remove(bookmark.uri);
        return null;
      }
      return doc;
    } catch (_) {
      await remove(bookmark.uri);
      return null;
    }
  }

  Future<void> _save(List<Bookmark> next) async {
    _items = List.unmodifiable(next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKey,
      jsonEncode(next.map((b) => b.toJson()).toList()),
    );
    notifyListeners();
  }

  static List<Bookmark> _decode(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .whereType<Map<String, dynamic>>()
          .map(Bookmark.fromJson)
          .where((b) => b.uri.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }
}
