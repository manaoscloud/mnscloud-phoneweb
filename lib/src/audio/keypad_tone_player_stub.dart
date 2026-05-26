import 'package:flutter/services.dart';

class KeypadTonePlayer {
  void play(String key) {
    SystemSound.play(SystemSoundType.click);
  }

  void dispose() {}
}
