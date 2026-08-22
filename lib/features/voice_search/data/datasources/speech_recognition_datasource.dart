import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart';

enum SpeechStartResult {
  listening,
  permissionDenied,
  permissionPermanentlyDenied,
  unavailable,
}

/// Thin wrapper around the `speech_to_text` plugin.
///
/// Handles microphone permission (via `permission_handler`, same package the
/// rest of the app already uses — see `Permission/permission_page.dart`) and
/// translates the plugin's raw error codes into user-facing messages so
/// nothing above this layer ever has to look at a `SpeechRecognitionError`.
///
/// Recognition itself runs through the device's speech engine — this class
/// never sends audio, recognized text, or video data to any server this app
/// controls. Whether the OS engine recognizes fully on-device depends on the
/// device/OS (see the feature's Limitations notes).
class SpeechRecognitionDatasource {
  final SpeechToText _speech = SpeechToText();
  bool _initialized = false;

  bool get isListening => _speech.isListening;

  Future<SpeechStartResult> startListening({
    required void Function(String text, bool isFinal) onResult,
    required void Function() onDone,
    required void Function(String friendlyMessage) onError,
    String? localeId,
  }) async {
    final permissionResult = await _ensureMicPermission();
    if (permissionResult != null) return permissionResult;

    if (!_initialized) {
      _initialized = await _speech.initialize(
        onError: (e) => onError(_friendlyError(e.errorMsg)),
        onStatus: (status) {
          if (status == SpeechToText.doneStatus ||
              status == SpeechToText.notListeningStatus) {
            onDone();
          }
        },
      );
    }
    if (!_initialized) return SpeechStartResult.unavailable;

    // Defensive: Android's native SpeechRecognizer throws a "busy"/audio
    // error if `listen()` is called again before a previous session has
    // fully torn down — real-device testing hit exactly this starting a
    // second search right after the first. Every `VoiceSearchPage` visit
    // creates a fresh `SpeechRecognitionDatasource`, so `_speech.isListening`
    // on *this* instance can't see a still-tearing-down session from a
    // previous one — cancel unconditionally instead. It's a documented
    // no-op when nothing is active, on both the Dart and native side.
    await _speech.cancel();

    try {
      await _speech.listen(
        onResult: (r) => onResult(r.recognizedWords, r.finalResult),
        // Without explicit bounds some devices/OEM ROMs never fire the
        // plugin's own silence-timeout — real-device testing showed the mic
        // staying in "listening" indefinitely (background noise kept
        // resetting whatever internal silence timer the OS uses), so the
        // controller's `onDone` callback never ran and a search never
        // started. `pauseFor` ends the session after a real pause in
        // speech; `listenFor` is a hard cap so it can never hang forever.
        listenOptions: SpeechListenOptions(
          partialResults: true,
          cancelOnError: true,
          listenMode: ListenMode.search,
          localeId: localeId,
          pauseFor: const Duration(seconds: 3),
          listenFor: const Duration(seconds: 20),
        ),
      );
    } catch (_) {
      return SpeechStartResult.unavailable;
    }
    return SpeechStartResult.listening;
  }

  Future<void> stop() => _speech.stop();

  Future<void> cancel() => _speech.cancel();

  /// Returns a [SpeechStartResult] if permission could not be secured, or
  /// `null` if the microphone is ready to use.
  Future<SpeechStartResult?> _ensureMicPermission() async {
    final status = await Permission.microphone.status;
    if (status.isGranted) return null;
    if (status.isPermanentlyDenied) {
      return SpeechStartResult.permissionPermanentlyDenied;
    }

    final requested = await Permission.microphone.request();
    if (requested.isGranted) return null;
    return requested.isPermanentlyDenied
        ? SpeechStartResult.permissionPermanentlyDenied
        : SpeechStartResult.permissionDenied;
  }

  String _friendlyError(String errorMsg) {
    switch (errorMsg) {
      case 'error_no_match':
        return "Didn't catch that. Please try again.";
      case 'error_speech_timeout':
        return 'No speech detected. Try again.';
      case 'error_network':
      case 'error_network_timeout':
        return 'A network issue interrupted voice search. Try again.';
      case 'error_audio':
      case 'error_client':
      case 'error_busy':
        return 'Microphone is unavailable right now. Please try again.';
      default:
        return 'Something went wrong with voice search. Please try again.';
    }
  }
}
