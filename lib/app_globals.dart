import 'package:flutter/material.dart';

/// MaterialApp ka navigator key — context ke bina navigate/dialog ke liye
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Route changes sunne ke liye (RouteAware widgets isse subscribe karte hain)
final RouteObserver<PageRoute<dynamic>> routeObserver =
RouteObserver<PageRoute<dynamic>>();

/// Kahin se bhi current context chahiye ho to
BuildContext? get globalContext => navigatorKey.currentContext;