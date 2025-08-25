import 'package:flutter/material.dart';
import 'package:flutter_portal/flutter_portal.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'AppDemo/Test1/test1.dart';
import 'NotifyListeners/LanguageProvider/language_provider.dart';
import 'DarkMode/dark_mode.dart';
import 'Home/HomeBottomnavigation/home_bottomNavigation.dart';
import 'NotifyListeners/AppBar/app_bar_color.dart';
import 'OnboardScreen/onboarding_screen.dart';

void main() {

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
                  // localizationsDelegates: [
                  //   AppLocalizations.delegate,
                  //   GlobalMaterialLocalizations.delegate,
                  //   GlobalWidgetsLocalizations.delegate,
                  //   GlobalCupertinoLocalizations.delegate,
                  // ],
                  supportedLocales: [
                    Locale('en', ''), // English
                    Locale('hi', ''), // Hindi
                  ],
                  home: AuthenticationWrapper(),
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
  // final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;


  bool isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    checkLoginStatus();
  }





  Future<void> checkLoginStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    // Check if user credentials exist
    bool loggedIn = prefs.getBool('isLoggedIn') ?? false;
    if (loggedIn) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) =>  const HomeBottomNavigation()),
      );
      // Navigator.pushReplacement(
      //   context,
      //   MaterialPageRoute(builder: (context) =>  const Test1Screen()),
      // );
    } else {
      // If user is not logged in, navigate to login page
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => OnboardingScreen()),
      );
    }
  }
  @override
  Widget build(BuildContext context) {
    // You can show a loading indicator or splash screen here
    return Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}