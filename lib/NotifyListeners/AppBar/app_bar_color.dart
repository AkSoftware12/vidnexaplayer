import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:videoplayer/HexColorCode/HexColor.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppBarColorProvider extends ChangeNotifier {
  Color _selectedColor = Colors.blue; // Default color
  final List<Color> colors = [
    HexColor('090040'),
    HexColor('471396'),
    HexColor('B13BFF'),
    HexColor('901E3E'),
    HexColor('511D43'),
    HexColor('410445'),
    HexColor('0C0950'),
    HexColor('005B41'),
    HexColor('008170'),
    HexColor('0B666A'),
    HexColor('03001C'),
  ];

  Color get selectedColor => _selectedColor;

  // Load saved color from SharedPreferences
  Future<void> loadColor() async {
    final prefs = await SharedPreferences.getInstance();
    final savedColor = prefs.getInt('appBarColor');
    if (savedColor != null) {
      _selectedColor = Color(savedColor);
      notifyListeners();
    }
  }

  // Save color to SharedPreferences
  Future<void> changeColor(Color color) async {
    _selectedColor = color;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('appBarColor', color.value); // Save color value
    notifyListeners();
  }

  // Reset to default color
  Future<void> resetColor() async {
    _selectedColor = Colors.grey.shade100; // Default color
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('appBarColor', _selectedColor.value); // Save default
    notifyListeners();
  }
}