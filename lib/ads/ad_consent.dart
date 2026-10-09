import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// GDPR / UK / Swiss consent through Google's User Messaging Platform (UMP).
///
/// AdMob requires a Google-certified CMP before serving ads to users in the
/// EEA, the UK and Switzerland, and the published privacy policy promises both
/// a consent form and a way to change the choice later from inside the app.
/// This class is both halves of that promise.
///
/// Nothing may request an ad until [canRequestAds] is true. Outside the
/// regulated regions UMP reports that straight away, so users elsewhere see no
/// form and no delay.
///
/// The form itself is configured in the AdMob console under
/// Privacy & messaging → GDPR. Without a published message there, UMP has
/// nothing to show and [canRequestAds] stays false for regulated users.
class AdConsent extends ChangeNotifier {
  AdConsent._();

  static final AdConsent instance = AdConsent._();

  bool _canRequestAds = false;

  /// Whether the ad SDK may be initialised and ads requested.
  bool get canRequestAds => _canRequestAds;

  bool _privacyOptionsRequired = false;

  /// Whether the "Privacy options" entry point must be shown in settings.
  ///
  /// UMP only reports `required` for users it asked for consent, so the entry
  /// stays hidden everywhere it would be meaningless.
  bool get privacyOptionsRequired => _privacyOptionsRequired;

  Future<void>? _gathering;

  /// Refreshes the consent status and shows the form if UMP says it is needed.
  ///
  /// Safe to call more than once: overlapping calls share one run.
  Future<void> gather() => _gathering ??= _gather().whenComplete(() {
        _gathering = null;
      });

  Future<void> _gather() async {
    // A consent given in an earlier session is already on disk. Checking it
    // before the network round-trip lets ads start without waiting for it.
    await _refresh();

    final updated = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () async {
        await ConsentForm.loadAndShowConsentFormIfRequired((FormError? error) {
          if (error != null) {
            debugPrint('UMP form error ${error.errorCode}: ${error.message}');
          }
        });
        if (!updated.isCompleted) updated.complete();
      },
      (FormError error) {
        // Offline, or no message configured. Fall back to whatever consent is
        // already stored; with none, ads simply stay off this session.
        debugPrint('UMP update failed ${error.errorCode}: ${error.message}');
        if (!updated.isCompleted) updated.complete();
      },
    );
    await updated.future;
    await _refresh();
  }

  /// Re-opens the consent form so the user can change their choice.
  Future<void> showPrivacyOptions() async {
    await ConsentForm.showPrivacyOptionsForm((FormError? error) {
      if (error != null) {
        debugPrint('UMP privacy options error ${error.errorCode}: '
            '${error.message}');
      }
    });
    await _refresh();
  }

  Future<void> _refresh() async {
    bool can = false;
    bool options = false;
    try {
      can = await ConsentInformation.instance.canRequestAds();
      options = await ConsentInformation.instance
              .getPrivacyOptionsRequirementStatus() ==
          PrivacyOptionsRequirementStatus.required;
    } catch (e) {
      debugPrint('UMP status read failed: $e');
    }
    if (can == _canRequestAds && options == _privacyOptionsRequired) return;
    _canRequestAds = can;
    _privacyOptionsRequired = options;
    notifyListeners();
  }
}
