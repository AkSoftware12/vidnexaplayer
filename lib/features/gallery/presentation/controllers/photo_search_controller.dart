import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../voice_search/data/datasources/speech_recognition_datasource.dart';
import '../../domain/entities/gallery_query.dart';
import '../../domain/entities/photo_entity.dart';
import '../../domain/parser/gallery_query_parser.dart';
import '../../domain/repositories/gallery_repository.dart';
import '../services/photo_signature_service.dart';

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

  final PhotoSignatureService _signatures = PhotoSignatureService.instance;

  Timer? _debounceTimer;

  /// Number of the newest search; see [_applyQuery].
  int _request = 0;
  bool _disposed = false;

  /// True while the signature index is being brought up to date for a query
  /// that depends on it — results may still grow.
  bool _indexing = false;
  bool get indexing => _indexing;

  /// Set once the index has been caught up on this screen, so later queries
  /// do not each start another (no-op) pass.
  bool _indexChecked = false;

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
    _request++; // a search still in flight must not refill the cleared list
    _searching = false;
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
    // The speech plugin keeps calling back after the page is gone: dispose()
    // stops the recognizer, which delivers a final result and a "done" status
    // to these closures. Each one bails out once the controller is disposed.
    final result = await _speech.startListening(
      onResult: (text, isFinal) {
        if (_disposed) return;
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
        if (_disposed) return;
        _listening = false;
        notifyListeners();
      },
      onError: (message) {
        if (_disposed) return;
        _listening = false;
        _speechError = message;
        notifyListeners();
      },
    );

    // The page closed while the mic was starting (e.g. during the permission
    // dialog): dispose() already ran its stop(), so close the session that
    // has just opened instead of leaving the mic on.
    if (_disposed) {
      if (result == SpeechStartResult.listening) unawaited(_speech.stop());
      return;
    }

    _listening = result == SpeechStartResult.listening;
    if (!_listening) _speechError = _messageFor(result);
    notifyListeners();
  }

  /// Safety net for every async path in this class (search, indexing, mic):
  /// a late completion after the page closed must not notify a disposed
  /// notifier.
  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _debounceTimer?.cancel();
    _speech.stop();
    super.dispose();
  }

  Future<void> _run(String text) async {
    if (text.trim().isEmpty) {
      _request++; // a search still in flight must not refill the cleared list
      _searching = false;
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
    // Each search takes a number; only the newest may publish. Searches are
    // not equally fast — a colour query reads the whole signature table — so
    // without this a slow earlier query could land after a later one and
    // replace its results with ones for text the user had already changed.
    final request = ++_request;
    final query = _query;
    _searching = true;
    notifyListeners();

    if (query.needsSignatures) _ensureIndex();

    final results = query.isEmpty
        ? const <PhotoEntity>[]
        : await repository.searchPhotos(query);
    if (_disposed || request != _request) return;

    _results = results;
    _searching = false;
    _hasSearched = true;
    notifyListeners();
  }

  /// Colour, brightness and size answers come from the signature index, and
  /// photos not yet in it are left out. Searching on a fresh install (or after
  /// new photos arrived) therefore came back short or empty with no hint why.
  ///
  /// So a query that needs the index makes sure it is complete — once per
  /// screen, since the pass is incremental and a no-op once caught up — and
  /// re-runs itself when photos were added, while [indexing] lets the page
  /// say that results are still filling in.
  void _ensureIndex() {
    if (_indexing || _indexChecked) return;
    _indexing = true;

    // Joins a pass that is already running (the gallery's background one, or
    // another tool's) and raises it to full speed, since the user is now
    // waiting on it.
    unawaited(
      _signatures.ensureSignatures().then((signed) => _onIndexDone(signed > 0)),
    );
  }

  void _onIndexDone(bool changed) {
    if (_disposed) return;
    _indexing = false;
    _indexChecked = true;
    if (changed && _query.needsSignatures) {
      unawaited(_applyQuery());
    } else {
      notifyListeners();
    }
  }

  String? _messageFor(SpeechStartResult result) => switch (result) {
        SpeechStartResult.listening => null,
        SpeechStartResult.permissionDenied => 'mic_permission_denied',
        SpeechStartResult.permissionPermanentlyDenied =>
          'mic_permission_blocked',
        SpeechStartResult.unavailable => 'mic_unavailable',
      };
}
