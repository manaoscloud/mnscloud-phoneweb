import 'dart:async';

import 'package:web/web.dart' as web;

class RingtonePlayer {
  web.AudioContext? _audioContext;
  Timer? _timer;

  void start() {
    if (_timer != null) return;

    _playBurst();
    _timer = Timer.periodic(const Duration(milliseconds: 1800), (_) {
      _playBurst();
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() {
    stop();
    _audioContext?.close();
    _audioContext = null;
  }

  void _playBurst() {
    final context = _context();
    if (context == null) return;

    final now = context.currentTime;
    _tone(context, now, 0.42);
    _tone(context, now + 0.54, 0.42);
  }

  void _tone(web.AudioContext context, num startAt, num duration) {
    final gain = context.createGain();
    gain.gain.setValueAtTime(0.0001, startAt);
    gain.gain.exponentialRampToValueAtTime(0.055, startAt + 0.04);
    gain.gain.exponentialRampToValueAtTime(0.0001, startAt + duration);
    gain.connect(context.destination);

    for (final frequency in const [440, 480]) {
      final oscillator = context.createOscillator();
      oscillator.type = 'sine';
      oscillator.frequency.setValueAtTime(frequency, startAt);
      oscillator.connect(gain);
      oscillator.start(startAt);
      oscillator.stop(startAt + duration);
    }
  }

  web.AudioContext? _context() {
    final existing = _audioContext;
    if (existing != null) {
      if (existing.state == 'suspended') {
        existing.resume();
      }
      return existing;
    }

    try {
      final context = web.AudioContext();
      if (context.state == 'suspended') {
        context.resume();
      }
      _audioContext = context;
      return context;
    } catch (_) {
      return null;
    }
  }
}
