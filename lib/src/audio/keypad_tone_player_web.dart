import 'package:web/web.dart' as web;

class KeypadTonePlayer {
  web.AudioContext? _audioContext;

  void play(String key) {
    final frequencies = _frequencies[key];
    if (frequencies == null) {
      return;
    }

    final context = _context();
    if (context == null) {
      return;
    }

    final now = context.currentTime;
    final stopAt = now + 0.11;
    final gain = context.createGain();
    gain.gain.setValueAtTime(0.0001, now);
    gain.gain.exponentialRampToValueAtTime(0.045, now + 0.01);
    gain.gain.exponentialRampToValueAtTime(0.0001, stopAt);
    gain.connect(context.destination);

    for (final frequency in frequencies) {
      final oscillator = context.createOscillator();
      oscillator.type = 'sine';
      oscillator.frequency.setValueAtTime(frequency, now);
      oscillator.connect(gain);
      oscillator.start(now);
      oscillator.stop(stopAt);
    }
  }

  void dispose() {
    _audioContext?.close();
    _audioContext = null;
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

  static const Map<String, List<num>> _frequencies = {
    '1': [697, 1209],
    '2': [697, 1336],
    '3': [697, 1477],
    '4': [770, 1209],
    '5': [770, 1336],
    '6': [770, 1477],
    '7': [852, 1209],
    '8': [852, 1336],
    '9': [852, 1477],
    '*': [941, 1209],
    '0': [941, 1336],
    '#': [941, 1477],
  };
}
