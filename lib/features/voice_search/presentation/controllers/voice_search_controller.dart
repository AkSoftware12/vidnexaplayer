import 'package:flutter/foundation.dart';

import '../../data/datasources/speech_recognition_datasource.dart';
import '../../domain/entities/media_kind.dart';
import '../../domain/entities/video_entity.dart';
import '../../domain/entities/video_search_query.dart';
import '../../domain/parser/voice_command_parser.dart';
import '../../domain/repositories/video_search_repository.dart';
import '../../domain/usecases/search_videos_usecase.dart';

enum VoiceSearchState {
  idle,
  listening,
  processing,
  searching,
  results,
  noResults,
  permissionDenied,
  speechError,
}

/// Drives the voice search screen's state machine.
///
/// A plain `ChangeNotifier` — matches the app's existing Provider pattern
/// (see `VideoProvider` in `Home/HomeScreen/home2.dart`) — but scoped to the
/// `VoiceSearchPage` route rather than registered globally in `main.dart`,
/// since most sessions never open it.
class VoiceSearchController extends ChangeNotifier {
  VoiceSearchController({
    required VideoSearchRepository repository,
    SpeechRecognitionDatasource? speech,
    VoiceCommandParser? parser,
  })  : _repository = repository,
        _searchUseCase = SearchVideosUseCase(repository),
        _speech = speech ?? SpeechRecognitionDatasource(),
        _parser = parser ?? VoiceCommandParser();

  static const _pageSize = 40;

  final VideoSearchRepository _repository;
  final SearchVideosUseCase _searchUseCase;
  final SpeechRecognitionDatasource _speech;
  final VoiceCommandParser _parser;

  VoiceSearchState _state = VoiceSearchState.idle;
  VoiceSearchState get state => _state;

  String _recognizedText = '';
  String get recognizedText => _recognizedText;

  /// Live/interim recognition text while [state] is [VoiceSearchState.listening].
  String _partialText = '';
  String get partialText => _partialText;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  VideoSearchQuery? _lastQuery;
  VideoSearchQuery? get lastQuery => _lastQuery;

  List<VideoEntity> _results = const [];
  List<VideoEntity> get results => _results;

  bool _isLoadingMore = false;
  bool get isLoadingMore => _isLoadingMore;

  bool _hasMore = true;
  bool get hasMore => _hasMore;

  Future<void> startListening({String? localeId}) async {
    _partialText = '';
    _recognizedText = '';
    _errorMessage = null;
    _setState(VoiceSearchState.listening);

    final result = await _speech.startListening(
      localeId: localeId,
      onResult: (text, isFinal) {
        _partialText = text;
        if (isFinal) _recognizedText = text;
        notifyListeners();
      },
      onDone: () {
        // The plugin's "done" status fires both when speech naturally ends
        // and right after an explicit stop() — only react to it once, and
        // only if we're still mid-listen (a manual stopListening() may have
        // already moved the state machine on).
        if (_state == VoiceSearchState.listening) {
          _finishListening();
        }
      },
      onError: (message) {
        _errorMessage = message;
        _setState(VoiceSearchState.speechError);
      },
    );

    switch (result) {
      case SpeechStartResult.listening:
        return;
      case SpeechStartResult.permissionDenied:
      case SpeechStartResult.permissionPermanentlyDenied:
        _setState(VoiceSearchState.permissionDenied);
        return;
      case SpeechStartResult.unavailable:
        _errorMessage = 'Speech recognition is not available on this device.';
        _setState(VoiceSearchState.speechError);
        return;
    }
  }

  Future<void> stopListening() async {
    await _speech.stop();
    if (_state == VoiceSearchState.listening) {
      await _finishListening();
    }
  }

  Future<void> _finishListening() async {
    final text = _recognizedText.isNotEmpty ? _recognizedText : _partialText;
    if (text.trim().isEmpty) {
      _errorMessage = 'No speech detected. Please try again.';
      _setState(VoiceSearchState.speechError);
      return;
    }
    await runTextQuery(text);
  }

  /// Parses [text] and searches the local index. Public so the "no results"
  /// screen's example-command chips can trigger the same flow as speech.
  Future<void> runTextQuery(String text) async {
    _recognizedText = text;
    _setState(VoiceSearchState.processing);

    final query = _parser.parse(text);
    _lastQuery = query;

    _setState(VoiceSearchState.searching);
    try {
      final results = await _searchUseCase(query, offset: 0, limit: _pageSize);
      _results = results;
      _hasMore = results.length == _pageSize;
      _setState(
        results.isEmpty ? VoiceSearchState.noResults : VoiceSearchState.results,
      );
    } catch (_) {
      _errorMessage = 'Something went wrong while searching your videos.';
      _setState(VoiceSearchState.speechError);
    }
  }

  Future<void> loadMore() async {
    if (_isLoadingMore || !_hasMore || _lastQuery == null) return;
    _isLoadingMore = true;
    notifyListeners();
    try {
      final more = await _searchUseCase(
        _lastQuery!,
        offset: _results.length,
        limit: _pageSize,
      );
      _results = [..._results, ...more];
      _hasMore = more.length == _pageSize;
    } catch (_) {
      // Keep whatever is already on screen — a failed "load more" shouldn't
      // wipe existing results.
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  /// Drops a row that turned out to point at a file no longer on disk.
  Future<void> removeStale(MediaKind kind, String id) async {
    await _repository.removeStaleEntry(kind, id);
    _results = _results.where((v) => v.id != id || v.mediaKind != kind).toList();
    if (_results.isEmpty) {
      _setState(VoiceSearchState.noResults);
    } else {
      notifyListeners();
    }
  }

  void reset() {
    _speech.cancel();
    _partialText = '';
    _recognizedText = '';
    _errorMessage = null;
    _results = const [];
    _lastQuery = null;
    _hasMore = true;
    _setState(VoiceSearchState.idle);
  }

  void _setState(VoiceSearchState next) {
    _state = next;
    notifyListeners();
  }

  @override
  void dispose() {
    _speech.cancel();
    super.dispose();
  }
}
