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
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedColor = prefs.getInt('appBarColor');
      if (savedColor == null) return;
      final restored = Color(savedColor);
      if (restored == _selectedColor) return; // avoid a pointless rebuild
      _selectedColor = restored;
      notifyListeners();
    } catch (_) {
      // Keep the default colour.
    }
  }

  // Save color to SharedPreferences
  Future<void> changeColor(Color color) async {
    _selectedColor = color;
    notifyListeners();
    await _persist(color);
  }

  // Reset to default color
  Future<void> resetColor() async {
    _selectedColor = Colors.grey.shade100; // Default color
    notifyListeners();
    await _persist(_selectedColor);
  }

  Future<void> _persist(Color color) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // `Color.value` is deprecated; `toARGB32()` is the explicit conversion.
      await prefs.setInt('appBarColor', color.toARGB32());
    } catch (_) {
      // Non-fatal: the colour still changed for this session.
    }
  }
}