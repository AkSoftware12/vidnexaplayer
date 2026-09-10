import 'package:flutter/material.dart';
import 'package:videoplayer/HexColorCode/HexColor.dart' show HexColor;

class ColorSelect {
  /// Mutable so [ThemeProvider] can re-point it when the accent changes.
  /// Read directly by ~116 call sites that predate the theme's colorScheme;
  /// see ThemeProvider._applyAccent for why this is a static bridge.
  static Color maineColor = HexColor('#4e14d1');
  static final maineColor2=HexColor('#081740');
  static final subtextColor=HexColor('#4B5563');
  static final titletextColor=HexColor('#111827');


  static const bottomSelColor=Colors.orange;
  static const bottomUnSelColor=Colors.grey;
  static const buttonColor=Colors.orange;
  static const textcolor=Colors.white;
  static const black=Colors.black;
  static const subtextcolor=Colors.grey;
  static const background=Colors.white;
  static const headingColor=Colors.grey;

}