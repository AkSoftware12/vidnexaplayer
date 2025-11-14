
import 'package:flutter/cupertino.dart';

class PlayPauseSync extends ChangeNotifier {
  bool isPlaying = false;

  void update(bool value) {
    isPlaying = value;
    notifyListeners();
  }
}