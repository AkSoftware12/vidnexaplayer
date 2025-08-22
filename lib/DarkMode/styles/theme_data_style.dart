import 'package:flutter/material.dart';

class ThemeDataStyle {
  
  static ThemeData light = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.light(
      background: Colors.grey.shade100,
      primary: Colors.white,
      secondary: Colors.black,
        onPrimary: Colors.black

    ),
  );

  static ThemeData dark = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.dark(
      background: Colors.white,
      primary: Colors.white,
      secondary: Colors.white,
      onPrimary: Colors.grey
    ),
  );

}