import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserModel with ChangeNotifier {
  String _name = "No Name";
  String? _imagePath;

  String get name => _name;
  String? get imagePath => _imagePath;

  UserModel() {
    _loadUser(); // jab model banega, saved data load hoga
  }

  Future<void> _loadUser() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    _name = prefs.getString("name") ?? "No Name";
    _imagePath = prefs.getString("imagePath");
    notifyListeners();
  }

  Future<void> updateUser(String name, String? imagePath) async {
    _name = name;
    _imagePath = imagePath;

    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString("name", _name);

    if (_imagePath != null) {
      await prefs.setString("imagePath", _imagePath!);
    }

    notifyListeners();
  }
}
