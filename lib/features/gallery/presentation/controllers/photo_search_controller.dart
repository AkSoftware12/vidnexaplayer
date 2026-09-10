import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../voice_search/data/datasources/speech_recognition_datasource.dart';
import '../../domain/entities/gallery_query.dart';
import '../../domain/entities/photo_entity.dart';
import '../../domain/parser/gallery_query_parser.dart';
import '../../domain/repositories/gallery_repository.dart';

/// Drives smart search.
///
/// Reuses `features/voice_search`'s [SpeechRecognitionDatasource] for the
/// microphone — it already handles permission and turns the plugin's raw error
/// codes into readable messages — and its command parser, through
/// [GalleryQueryParser], for dates, folders, sizes and extensions.
class PhotoSearchController extends ChangeNotifier {
  PhotoSearchController({
    required this.repository,
    SpeechRecognitionDatasource? speech,
    GalleryQueryParser? parser,
  })  : _speech = speech ?? SpeechRecognitionDatasource(),
        _parser = parser ?? GalleryQueryParser();

  /// Long enough that typing a word does not run a filter pass per keystroke,
  /// short enough to feel immediate.
  static const _debounce = Duration(milliseconds: 320);

  final GalleryRepository repository;
  final SpeechRecognitionDatasource _speech;
  final GalleryQueryParser _parser;

  Timer? _debounceTimer;

  String _rawText = '';
  String get rawText => _rawText;

  GalleryQuery _query = GalleryQuery.empty;
  GalleryQuery get query => _query;

  List<PhotoEntity> _results = const [];
  List<PhotoEntity> get results => _results;

  bool _searching = false;
  bool get searching => _searching;

  /// True once a search has actually run, so the page can tell "no results"
  /// apart from "nothing asked yet".
  bool _hasSearched = false;
  bool get hasSearched => _hasSearched;

  bool _listening = false;
  bool get listening => _listening;

  String? _speechError;
  String? get speechError => _speechError;

  /// Live partial transcript while the mic is open.
  String _partial = '';
  String get partial => _partial;

  void onTextChanged(String text) {
    _rawText = text;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounce, () => _run(text));
    notifyListeners();
  }

  /// Runs immediately, skipping the debounce — for the keyboard's search key
  /// and for a finished voice result.
  Future<void> submit(String text) async {
    _debounceTimer?.cancel();
    _rawText = text;
    await _run(text);
  }

  /// Drops one facet from the active query and re-filters, without touching
  /// the raw text — the chip row's ✕ removes a filter, it does not rewrite
  /// what the user typed.
  Future<void> removeFacet(GalleryQuery reduced) async {
    _query = reduced;
    await _applyQuery();
  }

  Future<void> clear() async {
    _debounceTimer?.cancel();
    _rawText = '';
    _query = GalleryQuery.empty;
    _results = const [];
    _hasSearched = false;
    notifyListeners();
  }

  Future<void> toggleMic() async {
    if (_listening) {
      await _speech.stop();
      _listening = false;
      notifyListeners();
      return;
    }

    _speechError = null;
    _partial = '';
    final result = await _speech.startListening(
      onResult: (text, isFinal) {
        _partial = text;
        if (isFinal) {
          _listening = false;
          _partial = '';
          submit(text);
        } else {
          notifyListeners();
        }
      },
      onDone: () {
        _listening = false;
        notifyListeners();
      },
      onError: (message) {
        _listening = false;
        _speechError = message;
        notifyListeners();
      },
    );

    _listening = result == SpeechStartResult.listening;
    if (!_listening) _speechError = _messageFor(result);
    notifyListeners();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _speech.stop();
    super.dispose();
  }

  Future<void> _run(String text) async {
    if (text.trim().isEmpty) {
      _query = GalleryQuery.empty;
      _results = const [];
      _hasSearched = false;
      notifyListeners();
      return;
    }
    _query = _parser.parse(text);
    await _applyQuery();
  }

  Future<void> _applyQuery() async {
    _searching = true;
    notifyListeners();

    _results = _query.isEmpty
        ? const []
        : await repository.searchPhotos(_query);

    _searching = false;
    _hasSearched = true;
    notifyListeners();
  }

  String? _messageFor(SpeechStartResult result) => switch (result) {
        SpeechStartResult.listening => null,
        SpeechStartResult.permissionDenied => 'mic_permission_denied',
        SpeechStartResult.permissionPermanentlyDenied =>
          'mic_permission_blocked',
        SpeechStartResult.unavailable => 'mic_unavailable',
      };
}
