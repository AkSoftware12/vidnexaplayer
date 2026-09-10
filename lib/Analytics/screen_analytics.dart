import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
// material.dart (widgets.dart nahi) — TabController aur DefaultTabController
// dono material me hain, jo [TabScreenReporter] ko chahiye.
import 'package:flutter/material.dart';

/// Analytics kabhi UI ko na giraaye — plugin/platform error sirf log ho,
/// throw kabhi na ho. Har analytics call isi ke through jaati hai.
Future<void> safeLogAnalytics(Future<void> Function() action) async {
  try {
    await action();
  } catch (e) {
    if (kDebugMode) debugPrint('📊 analytics failed: $e');
  }
}

/// Ek hi jagah se: "user kis screen par gaya" + "kitni der ruka".
///
/// Do cheezein Firebase ko jaati hain:
///  * `screen_view` — jab screen khulti hai (Firebase console ka "Screens"
///    report isi se banta hai)
///  * `screen_time` — jab screen band/background hoti hai, uske saath
///    `screen_name`, `duration_seconds` aur `duration_ms`
///
/// Screen ka naam har `Navigator.push` apne
/// `MaterialPageRoute(settings: RouteSettings(name: '...'))` se deta hai.
/// Jo screens route nahi hain (bottom-nav aur TabBar ke tabs) woh khud
/// [setScreen] call karti hain.
class ScreenAnalytics with WidgetsBindingObserver {
  ScreenAnalytics._();

  static final ScreenAnalytics instance = ScreenAnalytics._();

  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  /// Navigator par tike hue named routes, neeche se upar. Top wali screen hi
  /// dikh rahi hai — pop ke baad timer isi se resume hota hai.
  final List<_ScreenEntry> _stack = <_ScreenEntry>[];

  /// Abhi jo screen report ho chuki hai.
  String? _currentScreen;

  /// Us screen par entry ka waqt. `null` matlab timer band hai (app
  /// background me hai), screen phir bhi wahi hai.
  DateTime? _enteredAt;

  /// Ek push ke turant baad agar us screen ka tab apna naam bhejta hai, to
  /// dono log ho jaate. Isliye naam ko thoda thehra kar bhejte hain — aakhri
  /// naam jeetta hai.
  Timer? _debounce;
  String? _pendingScreen;

  static const Duration _settleDelay = Duration(milliseconds: 250);

  String? get currentScreen => _currentScreen;

  /// main() se ek baar. Isse app background jaaye to bhi time sahi gina jaaye.
  void start() {
    WidgetsBinding.instance.addObserver(this);
  }

  /// Nayi screen dikhne lagi. Purani ka time yahin flush ho jaata hai.
  void enter(String screenName) {
    if (screenName == _currentScreen && _enteredAt != null) {
      // Wahi screen wapas — pending override cancel, warna niche wali
      // screen ka naam late me chala jaata.
      _debounce?.cancel();
      _pendingScreen = null;
      return;
    }
    _pendingScreen = screenName;
    _debounce?.cancel();
    _debounce = Timer(_settleDelay, _commit);
  }

  /// Bottom-nav / TabBar ka tab badla. Ye route nahi banta, isliye naam yahin
  /// se aata hai aur chalu route ka naam badal deta hai — taaki iske upar se
  /// koi screen khul kar band ho, to wapas isi tab ka naam resume ho.
  void setScreen(String screenName) {
    if (_stack.isNotEmpty) _stack.last.name = screenName;
    enter(screenName);
  }

  void _commit() {
    final next = _pendingScreen;
    _pendingScreen = null;
    if (next == null || next == _currentScreen) return;

    unawaited(_flush());
    _currentScreen = next;
    _enteredAt = DateTime.now();
    unawaited(_log(() => _analytics.logScreenView(
          screenName: next,
          screenClass: next,
        )));
    if (kDebugMode) debugPrint('📊 screen_view → $next');
  }

  /// Chalu screen ka time Firebase ko bhej kar timer band kar deta hai.
  Future<void> _flush() async {
    final screen = _currentScreen;
    final since = _enteredAt;
    _enteredAt = null;
    if (screen == null || since == null) return;

    final ms = DateTime.now().difference(since).inMilliseconds;
    // 1 second se kam wale sirf shor hain (screen ke upar se guzar jaana).
    if (ms < 1000) return;

    await _log(() => _analytics.logEvent(
          name: 'screen_time',
          parameters: <String, Object>{
            'screen_name': screen,
            'duration_seconds': ms ~/ 1000,
            'duration_ms': ms,
          },
        ));
    if (kDebugMode) {
      debugPrint(
          '📊 screen_time → $screen : ${(ms / 1000).toStringAsFixed(1)}s');
    }
  }

  /// App background/foreground. Background me bitaaya waqt screen ka waqt
  /// nahi hai — pause par flush, resume par timer dobara.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _debounce?.cancel();
        _pendingScreen = null;
        unawaited(_flush());
      case AppLifecycleState.resumed:
        if (_currentScreen != null && _enteredAt == null) {
          _enteredAt = DateTime.now();
        }
      case AppLifecycleState.inactive:
        break;
    }
  }

  Future<void> _log(Future<void> Function() action) => safeLogAnalytics(action);

  // --- Navigator ke liye (ScreenAnalyticsObserver hi ye call karta hai) ---

  void _pushRoute(Route<dynamic> route, String name) {
    _stack.add(_ScreenEntry(route, name));
    _syncToStack();
  }

  /// Naam se nahi, [Route] se dhoondhta hai. [setScreen] entry ka naam badal
  /// deta hai (tab switch par), isliye pop ke waqt `settings.name` se match
  /// karna kaam nahi karta — gallery ka Tools tab khol kar back dabao to
  /// entry milti hi nahi thi aur wapas aayi screen kabhi report hi nahi hoti.
  void _popRoute(Route<dynamic> route) {
    final before = _stack.length;
    _stack.removeWhere((entry) => identical(entry.route, route));
    // Bina naam wale dialog/bottom sheet hamare stack me the hi nahi.
    if (_stack.length == before) return;
    _syncToStack();
  }

  void _replaceRoute(Route<dynamic>? oldRoute, Route<dynamic>? newRoute,
      String? newName) {
    var touched = false;
    if (oldRoute != null) {
      final before = _stack.length;
      _stack.removeWhere((entry) => identical(entry.route, oldRoute));
      touched = _stack.length != before;
    }
    if (newRoute != null && newName != null) {
      _stack.add(_ScreenEntry(newRoute, newName));
      touched = true;
    }
    if (touched) _syncToStack();
  }

  void _syncToStack() {
    if (_stack.isEmpty) {
      _debounce?.cancel();
      _pendingScreen = null;
      unawaited(_flush());
      _currentScreen = null;
    } else {
      enter(_stack.last.name);
    }
  }
}

/// Ek tika hua route aur uska maujuda screen name. Naam badal sakta hai
/// (tab switch), route nahi — isliye pehchaan route se hoti hai.
class _ScreenEntry {
  _ScreenEntry(this.route, this.name);

  final Route<dynamic> route;
  String name;
}

/// `TabBar` / `TabBarView` wale tabs ko report karta hai.
///
/// Iske subtree me jo bhi [TabController] hai (aksar `DefaultTabController`)
/// uska index sunta hai aur [ScreenAnalytics.setScreen] ko naam bhejta hai —
/// pehli baar build hote hi bhi, taaki jis tab par user land karta hai woh
/// bhi report ho, sirf badle hue tab nahi.
///
/// Jahan controller khud State ke paas hai (jaise TabController ya
/// PageController field), wahan iski zaroorat nahi — seedha
/// `ScreenAnalytics.instance.setScreen(...)` call kar lena kaafi hai.
class TabScreenReporter extends StatefulWidget {
  const TabScreenReporter({
    super.key,
    required this.names,
    required this.child,
  });

  /// Tab index ke hisaab se screen names.
  final List<String> names;

  final Widget child;

  @override
  State<TabScreenReporter> createState() => _TabScreenReporterState();
}

class _TabScreenReporterState extends State<TabScreenReporter> {
  TabController? _controller;
  int? _reportedIndex;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = DefaultTabController.maybeOf(context);
    if (identical(controller, _controller)) return;
    _controller?.removeListener(_report);
    _controller = controller?..addListener(_report);
    _reportedIndex = null;
    _report();
  }

  void _report() {
    final controller = _controller;
    if (controller == null) return;
    // Tap ke baad indicator animate hote waqt controller baar baar notify
    // karta hai — sirf jam chuke index par report karte hain.
    if (controller.indexIsChanging) return;
    final index = controller.index;
    if (index == _reportedIndex) return;
    if (index < 0 || index >= widget.names.length) return;
    _reportedIndex = index;
    ScreenAnalytics.instance.setScreen(widget.names[index]);
  }

  @override
  void dispose() {
    _controller?.removeListener(_report);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// [ScreenAnalytics] ko Navigator se jodta hai. Sirf wahi routes ginta hai
/// jinke paas `RouteSettings.name` hai — bina naam ke dialogs aur bottom
/// sheets report ko ganda nahi karte.
class ScreenAnalyticsObserver extends NavigatorObserver {
  String? _nameOf(Route<dynamic>? route) {
    if (route is! PageRoute) return null;
    final name = route.settings.name;
    if (name == null || name.isEmpty) return null;
    // MaterialApp ka `home:` route hamesha '/' naam se aata hai — report me
    // '/' ka koi matlab nahi, isliye usko uske asli naam se bhejte hain.
    if (name == '/') return 'SplashScreen';
    return name;
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    final name = _nameOf(route);
    if (name != null) ScreenAnalytics.instance._pushRoute(route, name);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    ScreenAnalytics.instance._popRoute(route);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    ScreenAnalytics.instance._popRoute(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    ScreenAnalytics.instance
        ._replaceRoute(oldRoute, newRoute, _nameOf(newRoute));
  }
}
