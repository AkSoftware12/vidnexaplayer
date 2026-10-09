import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../NotifyListeners/LanguageProvider/language_provider.dart';
import '../NotifyListeners/LanguageProvider/profile_strings.dart';
import 'package:provider/provider.dart';

/// Something new in this release that earns a "NEW" marker until the user
/// has been to it once.
///
/// The [key] is what is stored; give a feature a fresh key (e.g. `files_v3`)
/// the next time it changes enough to announce again.
enum NewFeature {
  languages('languages_v2'),
  textSize('text_size_v1'),
  files('files_v2'),
  vault('vault_v2'),
  pro('pro_monthly_v1'),
  stream('stream_v1');

  const NewFeature(this.key);
  final String key;
}

/// Which [NewFeature]s the user has not visited yet.
///
/// Everything starts "seen" until [load] has read storage, so a badge never
/// flashes on and off at start-up.
class WhatsNew extends ChangeNotifier {
  WhatsNew._();
  static final WhatsNew instance = WhatsNew._();

  static const String _prefix = 'whats_new_seen_';

  final Set<NewFeature> _unseen = {};

  bool isNew(NewFeature feature) => _unseen.contains(feature);

  /// Reads which features were already visited. Call once at start-up.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _unseen
        ..clear()
        ..addAll(NewFeature.values
            .where((f) => !(prefs.getBool('$_prefix${f.key}') ?? false)));
      notifyListeners();
    } catch (_) {
      // Leave everything "seen": no badges beats wrong badges.
    }
  }

  /// Hides [feature]'s marker for good. Cheap to call repeatedly.
  Future<void> markSeen(NewFeature feature) async {
    if (!_unseen.remove(feature)) return;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('$_prefix${feature.key}', true);
    } catch (_) {
      // Non-fatal: it reappears next launch at worst.
    }
  }
}

/// "NEW" pill shown next to an entry until [feature] is visited. Renders
/// nothing afterwards, so callers can place it unconditionally.
class NewBadge extends StatelessWidget {
  const NewBadge(this.feature, {super.key, this.onDark = false});

  final NewFeature feature;

  /// Use on coloured cards: a white pill instead of the pale red one.
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LocaleProvider>().locale.languageCode;
    return ListenableBuilder(
      listenable: WhatsNew.instance,
      builder: (context, _) {
        if (!WhatsNew.instance.isNew(feature)) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
          decoration: BoxDecoration(
            color: onDark ? Colors.white : const Color(0xFFFEE2E2),
            borderRadius: BorderRadius.circular(6),
            border: onDark ? null : Border.all(color: const Color(0xFFFCA5A5)),
          ),
          child: Text(
            ProfileStrings.t(lang, 'profile_badge_new'),
            textScaler: TextScaler.noScaling,
            style: const TextStyle(
              fontFamily: 'Outfit',
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: Color(0xFFDC2626),
              letterSpacing: 0.5,
            ),
          ),
        );
      },
    );
  }
}

/// A red dot for icon-only entries (app-bar buttons, bottom-bar tabs), same
/// rule as [NewBadge].
class NewDot extends StatelessWidget {
  const NewDot(this.feature, {super.key});

  final NewFeature feature;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: WhatsNew.instance,
      builder: (context, _) {
        if (!WhatsNew.instance.isNew(feature)) return const SizedBox.shrink();
        return Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: Colors.red.shade600,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 1.5),
          ),
        );
      },
    );
  }
}
