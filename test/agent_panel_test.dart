import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mnscloud_phoneweb/src/agent/agent_api.dart';
import 'package:mnscloud_phoneweb/src/agent/agent_panel.dart';
import 'package:mnscloud_phoneweb/src/session/mnscloud_session_controller.dart';

class Session extends MnscloudSessionController {
  @override
  Uri get server => Uri.parse('https://tenant.example.invalid');
  @override
  String get accessToken => 'fixture-token';
}

class FakeAgent extends AgentApi {
  FakeAgent() : super(Uri.parse('https://tenant.example.invalid/api/v1/'));
  String state = 'AVAILABLE';
  final actions = <String>[];
  final updates = StreamController<Map<String, dynamic>>.broadcast();
  @override
  Future<Map<String, dynamic>> request(
    String token, {
    String? action,
    Map<String, Object?>? body,
  }) async {
    if (action != null) {
      actions.add(action);
      expect(body?['revision'], 4);
      if (action == 'state') state = '${body?['status']}';
      if (action == 'logout') state = 'LOGGED_OUT';
    }
    return {
      'agent': {'VqaRevision': 4, 'VqaRuntimeStatus': state, 'SessionOwner': 1},
      'pauseReasons': [
        {'VpzUUID': 'reason', 'VpzName': 'LUNCH'},
      ],
      'queues': [
        {'VpqName': 'SUPPORT'},
      ],
    };
  }

  @override
  Stream<Map<String, dynamic>> events(String token, String cursor) =>
      updates.stream;
  @override
  void close() {
    unawaited(updates.close());
    super.close();
  }
}

void main() {
  for (final width in [390.0, 1280.0]) {
    testWidgets('agent controls remain reachable at width $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = FakeAgent();
      final session = Session();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AgentPanel(session: session, api: api),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.textContaining('SUPPORT'), findsOneWidget);
      await tester.tap(find.text('Pause'));
      await tester.pump();
      expect(find.text('Select a pause reason.'), findsOneWidget);
      expect(api.actions, isEmpty);
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('LUNCH').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pause'));
      await tester.pump();
      await tester.pump();
      expect(api.state, 'PAUSED');
      await tester.ensureVisible(find.text('Leave queues'));
      await tester.tap(find.text('Leave queues'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Join queues'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      session.dispose();
    });
  }
}
