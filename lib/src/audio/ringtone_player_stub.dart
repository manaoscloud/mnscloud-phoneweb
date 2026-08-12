import 'package:flutter/services.dart';

class RingtonePlayer {
  void start() {
    SystemSound.play(SystemSoundType.alert);
  }

  void stop() {}

  void dispose() {
    stop();
  }
}
