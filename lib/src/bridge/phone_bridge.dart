import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Phone Bridge v1 (`docs/phone-bridge.md`): the MNSCloud App hosts PhoneWeb in
/// a same-origin frame and drives it with `{v: 1, id, type, payload}`
/// messages. No secret, token or SIP credential ever crosses the bridge.
const phoneBridgeVersion = 1;
const phoneBridgeChannel = 'mnscloud-phone';

/// What the App may see of the phone at any moment.
@immutable
class PhoneBridgeSnapshot {
  const PhoneBridgeSnapshot({
    required this.signedIn,
    required this.registration,
    required this.accountName,
    required this.callActive,
    required this.callDirection,
    required this.callRemote,
    required this.callEstablished,
    required this.callAnswerable,
    required this.muted,
  });

  final bool signedIn;
  final String registration;
  final String? accountName;
  final bool callActive;
  final String? callDirection;
  final String? callRemote;
  final bool callEstablished;
  final bool callAnswerable;
  final bool muted;

  Map<String, Object?> toJson() => {
    'signedIn': signedIn,
    'registration': registration,
    'account': accountName,
    'call': callActive
        ? {
            'direction': callDirection,
            'remote': callRemote,
            'established': callEstablished,
            'answerable': callAnswerable,
            'muted': muted,
          }
        : null,
  };
}

/// The phone side the bridge drives (implemented over the VoIP controller).
abstract class PhoneBridgeHost {
  Listenable get changes;
  PhoneBridgeSnapshot snapshot();

  /// Starts a call; returns an error code (`NOT_REGISTERED`, ...) or null.
  Future<String?> dial(String number);
  Future<String?> answer();
  String? hangup();
  String? setMuted(bool muted);
  String? dtmf(String tones);

  /// Ends the MNSCloud session of the phone (App sign-out); manual accounts stay.
  Future<String?> signOut();
}

/// Message transport (web: `postMessage` with exact origin checks).
abstract class PhoneBridgeTransport {
  Stream<Map<String, Object?>> get incoming;
  void send(Map<String, Object?> message);
}

final _dialable = RegExp(r'^[0-9+*#]{1,32}$');
final _dtmf = RegExp(r'^[0-9*#A-Da-d]{1,32}$');

class PhoneBridge {
  PhoneBridge({
    required this.host,
    required this.transport,
    required this.appVersion,
    this.onFocus,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final PhoneBridgeHost host;
  final PhoneBridgeTransport transport;
  final String appVersion;

  /// Called on `phone.focus` and on `phone.dial`, so the UI shows the call.
  final void Function(String? number)? onFocus;
  final DateTime Function() _clock;

  StreamSubscription<Map<String, Object?>>? _subscription;
  String? _lastState;
  PhoneBridgeSnapshot? _previous;
  DateTime? _callStartedAt;

  void start() {
    _subscription = transport.incoming.listen(_onMessage);
    host.changes.addListener(_onChange);
    _emit('ready', {'version': appVersion, 'bridge': phoneBridgeVersion});
    _onChange();
  }

  void dispose() {
    _subscription?.cancel();
    host.changes.removeListener(_onChange);
  }

  void _emit(String type, [Map<String, Object?> payload = const {}]) {
    transport.send({
      'channel': phoneBridgeChannel,
      'v': phoneBridgeVersion,
      'type': type,
      'payload': payload,
    });
  }

  void _reply(Object? id, {String? error, Map<String, Object?>? payload}) {
    transport.send({
      'channel': phoneBridgeChannel,
      'v': phoneBridgeVersion,
      'id': id,
      'type': 'reply',
      'payload': {'ok': error == null, 'error': ?error, ...?payload},
    });
  }

  void _onChange() {
    final now = host.snapshot();
    final previous = _previous;
    _previous = now;
    if (now.callActive && (previous == null || !previous.callActive)) {
      _callStartedAt = _clock();
      final call = {'direction': now.callDirection, 'remote': now.callRemote};
      _emit(
        now.callDirection == 'incoming' ? 'call.ringing' : 'call.started',
        call,
      );
    }
    if (now.callEstablished && previous != null && !previous.callEstablished) {
      _emit('call.answered', {
        'direction': now.callDirection,
        'remote': now.callRemote,
      });
    }
    if (!now.callActive && previous != null && previous.callActive) {
      final started = _callStartedAt;
      _emit('call.ended', {
        'direction': previous.callDirection,
        'remote': previous.callRemote,
        'established': previous.callEstablished,
        'durationMs': started == null
            ? 0
            : _clock().difference(started).inMilliseconds,
      });
      _callStartedAt = null;
    }
    final state = jsonEncode(now.toJson());
    if (state != _lastState) {
      _lastState = state;
      _emit('state', now.toJson());
    }
  }

  Future<void> _onMessage(Map<String, Object?> message) async {
    if (message['channel'] != phoneBridgeChannel || message['type'] == null) {
      return;
    }
    final id = message['id'];
    if (message['v'] != phoneBridgeVersion) {
      _reply(id, error: 'UNSUPPORTED_VERSION');
      return;
    }
    final payload = message['payload'] is Map
        ? (message['payload'] as Map).cast<String, Object?>()
        : const <String, Object?>{};
    switch (message['type']) {
      case 'phone.state':
        _reply(id, payload: {'state': host.snapshot().toJson()});
      case 'phone.focus':
        onFocus?.call(null);
        _reply(id);
      case 'phone.dial':
        final number = (payload['number'] ?? '').toString().replaceAll(
          RegExp(r'[\s().-]'),
          '',
        );
        if (!_dialable.hasMatch(number)) {
          _reply(id, error: 'INVALID_NUMBER');
          return;
        }
        onFocus?.call(number);
        _reply(id, error: await host.dial(number));
      case 'phone.answer':
        _reply(id, error: await host.answer());
      case 'phone.hangup':
        _reply(id, error: host.hangup());
      case 'phone.mute':
        _reply(id, error: host.setMuted(payload['muted'] != false));
      case 'phone.dtmf':
        final tones = (payload['tones'] ?? '').toString();
        if (!_dtmf.hasMatch(tones)) {
          _reply(id, error: 'INVALID_DTMF');
          return;
        }
        _reply(id, error: host.dtmf(tones));
      case 'phone.signOut':
        _reply(id, error: await host.signOut());
      default:
        _reply(id, error: 'UNKNOWN_COMMAND');
    }
  }
}
