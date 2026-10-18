import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mnscloud_phoneweb/src/bridge/phone_bridge.dart';

class _Host extends ChangeNotifier implements PhoneBridgeHost {
  bool registered = true;
  bool active = false;
  bool established = false;
  String direction = 'outgoing';
  bool muted = false;
  final calls = <String>[];

  @override
  Listenable get changes => this;

  @override
  PhoneBridgeSnapshot snapshot() => PhoneBridgeSnapshot(
    signedIn: true,
    registration: registered ? 'registered' : 'offline',
    accountName: 'MNSCloud · 1001',
    callActive: active,
    callDirection: active ? direction : null,
    callRemote: active ? '5592999990000' : null,
    callEstablished: established,
    callAnswerable: active && direction == 'incoming' && !established,
    muted: muted,
  );

  void set({bool? active, bool? established, String? direction}) {
    this.active = active ?? this.active;
    this.established = established ?? this.established;
    this.direction = direction ?? this.direction;
    notifyListeners();
  }

  @override
  Future<String?> dial(String number) async {
    if (!registered) return 'NOT_REGISTERED';
    calls.add('dial:$number');
    return null;
  }

  @override
  Future<String?> answer() async {
    calls.add('answer');
    return null;
  }

  @override
  String? hangup() {
    calls.add('hangup');
    return null;
  }

  @override
  String? setMuted(bool value) {
    muted = value;
    calls.add('mute:$value');
    return null;
  }

  @override
  String? dtmf(String tones) {
    calls.add('dtmf:$tones');
    return null;
  }

  @override
  Future<String?> signOut() async {
    calls.add('signOut');
    return null;
  }
}

class _Transport implements PhoneBridgeTransport {
  final controller = StreamController<Map<String, Object?>>.broadcast();
  final sent = <Map<String, Object?>>[];

  @override
  Stream<Map<String, Object?>> get incoming => controller.stream;

  @override
  void send(Map<String, Object?> message) => sent.add(message);

  Iterable<String> get types => sent.map((m) => m['type'] as String);

  Map<String, Object?> replyTo(Object id) =>
      (sent.lastWhere((m) => m['type'] == 'reply' && m['id'] == id)['payload']!
              as Map)
          .cast<String, Object?>();
}

Map<String, Object?> _cmd(Object id, String type, [Map<String, Object?>? p]) =>
    {
      'channel': 'mnscloud-phone',
      'v': 1,
      'id': id,
      'type': type,
      'payload': ?p,
    };

void main() {
  late _Host host;
  late _Transport transport;
  late PhoneBridge bridge;
  var now = DateTime.utc(2026, 10, 18, 12);
  String? focused;

  setUp(() {
    host = _Host();
    transport = _Transport();
    focused = null;
    bridge = PhoneBridge(
      host: host,
      transport: transport,
      appVersion: '0.1.65',
      onFocus: (number) => focused = number ?? 'focus',
      clock: () => now,
    )..start();
  });

  tearDown(() => bridge.dispose());

  test('announces ready and the initial state, then only changes', () {
    expect(transport.types.take(2), ['ready', 'state']);
    expect(transport.sent.first['payload'], {'version': '0.1.65', 'bridge': 1});
    host.notifyListeners();
    expect(transport.types.where((t) => t == 'state').length, 1);
  });

  test('call lifecycle events carry no secret and a duration', () {
    host.set(active: true, direction: 'incoming');
    now = now.add(const Duration(seconds: 3));
    host.set(established: true);
    now = now.add(const Duration(seconds: 7));
    host.set(active: false, established: false);
    expect(transport.types.where((t) => t.startsWith('call.')), [
      'call.ringing',
      'call.answered',
      'call.ended',
    ]);
    final ended = transport.sent.lastWhere((m) => m['type'] == 'call.ended');
    expect((ended['payload']! as Map)['durationMs'], 10000);
    expect(transport.sent.toString().contains('password'), isFalse);
  });

  test('commands are validated, executed and answered by id', () async {
    transport.controller.add(
      _cmd(1, 'phone.dial', {'number': '(92) 99999-0000'}),
    );
    transport.controller.add(_cmd(2, 'phone.dial', {'number': 'sip:evil@x'}));
    transport.controller.add(_cmd(3, 'phone.mute', {'muted': true}));
    transport.controller.add(_cmd(4, 'phone.dtmf', {'tones': '12#'}));
    transport.controller.add(_cmd(5, 'phone.nope'));
    transport.controller.add(_cmd(8, 'phone.signOut'));
    transport.controller.add({..._cmd(6, 'phone.hangup'), 'v': 2});
    transport.controller.add({'type': 'phone.hangup', 'v': 1, 'id': 7});
    await pumpEventQueue();
    expect(host.calls, [
      'dial:92999990000',
      'mute:true',
      'dtmf:12#',
      'signOut',
    ]);
    expect(focused, '92999990000');
    expect(transport.replyTo(1), {'ok': true});
    expect(transport.replyTo(2), {'ok': false, 'error': 'INVALID_NUMBER'});
    expect(transport.replyTo(5)['error'], 'UNKNOWN_COMMAND');
    expect(transport.replyTo(6)['error'], 'UNSUPPORTED_VERSION');
    expect(transport.sent.where((m) => m['id'] == 7), isEmpty);
  });

  test('host errors are returned to the App', () async {
    host.registered = false;
    transport.controller.add(_cmd(9, 'phone.dial', {'number': '1001'}));
    await pumpEventQueue();
    expect(transport.replyTo(9), {'ok': false, 'error': 'NOT_REGISTERED'});
  });
}
