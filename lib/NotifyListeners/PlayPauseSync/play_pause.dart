
import 'package:cupertino_ui/cupertino_ui.dart';

class PlayPauseSync extends ChangeNotifier {
  bool isPlaying = false;

  void update(bool value) {
    isPlaying = value;
    notifyListeners();
  }
}