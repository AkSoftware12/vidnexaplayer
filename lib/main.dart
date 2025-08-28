import 'package:flutter/material.dart';
import 'package:flutter_portal/flutter_portal.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:upgrader/upgrader.dart';

import 'NotifyListeners/LanguageProvider/language_provider.dart';
import 'DarkMode/dark_mode.dart';
import 'Home/HomeBottomnavigation/home_bottomNavigation.dart';
import 'NotifyListeners/AppBar/app_bar_color.dart';
import 'OnboardScreen/onboarding_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // FOR TESTING ONLY - Clear settings every time app starts
  await Upgrader.clearSavedSettings(); // REMOVE this for release builds
  
  // Additional testing setup
  debugPrint('🔄 Upgrader settings cleared for testing');

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => ThemeProvider()),
        ChangeNotifierProvider(create: (context) => AppBarColorProvider()),
        ChangeNotifierProvider(create: (context) => LocaleProvider()),
      ],
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  final RouteObserver<PageRoute> _routeObserver = RouteObserver();

  MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Portal(
      child: Provider.value(
        value: _routeObserver,
        child: ScreenUtilInit(
          designSize: const Size(360, 690),
          minTextAdapt: true,
          splitScreenMode: true,
          builder: (_, child) {
            return Consumer<LocaleProvider>(
              builder: (context, localeProvider, child) {
                return MaterialApp(
                    debugShowCheckedModeBanner: false,
                    navigatorObservers: [_routeObserver],
                    title: '',
                    theme: Provider.of<ThemeProvider>(context).themeDataStyle,
                    locale: localeProvider.locale,
                    supportedLocales: const [
                      Locale('en', ''), // English
                      Locale('hi', ' '), // Hindi
                    ],
                    home: UpgradeAlert(
                      upgrader: Upgrader(
                        durationUntilAlertAgain: const Duration(milliseconds: 1),
                        debugLogging: true,
                        debugDisplayAlways: true,
                        debugDisplayOnce: false,
                      ),
                      child: AuthenticationWrapper(),
                    ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class AuthenticationWrapper extends StatefulWidget {
  @override
  State<AuthenticationWrapper> createState() => _AuthenticationWrapperState();
}

class _AuthenticationWrapperState extends State<AuthenticationWrapper> {
  bool isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    checkLoginStatus();
  }

  Future<void> checkLoginStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool loggedIn = prefs.getBool('isLoggedIn') ?? false;
    if (loggedIn) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeBottomNavigation()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => OnboardingScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
