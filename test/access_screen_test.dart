import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mnscloud_phoneweb/src/access/access_preferences.dart';
import 'package:mnscloud_phoneweb/src/access/access_screen.dart';
import 'package:mnscloud_phoneweb/src/brand/brand.dart';
import 'package:mnscloud_phoneweb/src/session/mnscloud_session_api.dart';
import 'package:mnscloud_phoneweb/src/session/mnscloud_session_controller.dart';
import 'package:mnscloud_phoneweb/src/session/session_platform.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Platform extends SessionPlatform {
  _Platform() : super(storage: const FlutterSecureStorage());
}

MnscloudSessionController _controller(MockClient client) =>
    MnscloudSessionController(
      platform: _Platform(),
      apiFactory: (server) => MnscloudSessionApi(
        baseUrl: Uri.parse('${server.origin}/api/v1/'),
        client: client,
      ),
    );

Future<void> _pump(
  WidgetTester tester,
  MnscloudSessionController controller, {
  Size size = const Size(1440, 900),
  VoidCallback? onContinue,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: PhoneWebAccessScreen(
        controller: controller,
        onContinueWithout: onContinue ?? () {},
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    accessLocale.value = const Locale('pt', 'BR');
  });
  tearDown(() {
    phonewebBrand.value = null;
    accessLocale.value = null;
  });

  testWidgets(
    'wide screens show the brand panel, the sign-in and continue without an account',
    (tester) async {
      var continued = false;
      final controller = _controller(
        MockClient((_) async => http.Response('{}', 500)),
      );
      await _pump(tester, controller, onContinue: () => continued = true);
      expect(find.text('Suas chamadas.\nEm qualquer lugar.'), findsOneWidget);
      expect(find.text('Entre no PhoneWeb'), findsOneWidget);
      expect(find.byKey(const Key('accessServer')), findsOneWidget);
      await tester.tap(find.byKey(const Key('continueWithout')));
      expect(continued, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('sign-in with any MNSCloud login opens the session', (
    tester,
  ) async {
    final controller = _controller(
      MockClient(
        (request) async => http.Response(
          jsonEncode({
            'status': 'success',
            'data': {
              'accessToken': 'access',
              'expiresIn': 600,
              'refreshToken': 'refresh',
              'session': {
                'sessionUUID': 'S1',
                'phoneUserUUID': 'P1',
                'tenantUUID': 'T1',
                'realm': 'user',
                'displayName': 'Ana',
              },
            },
          }),
          200,
        ),
      ),
    );
    await _pump(tester, controller, size: const Size(390, 844));
    await tester.tap(find.byKey(const Key('accessSignIn')));
    await tester.pumpAndSettle();
    expect(find.text('Este campo é obrigatório.'), findsWidgets);
    await tester.enterText(
      find.byKey(const Key('accessServer')),
      'tenant.example.com',
    );
    await tester.enterText(
      find.byKey(const Key('accessUser')),
      'ana@example.com',
    );
    await tester.enterText(find.byKey(const Key('accessPassword')), 'secret');
    await tester.ensureVisible(find.byKey(const Key('accessSignIn')));
    await tester.tap(find.byKey(const Key('accessSignIn')));
    await tester.pumpAndSettle();
    expect(controller.signedIn, isTrue);
    expect(tester.takeException(), isNull);
    // Stops the renewal timer of the session.
    await controller.signOut();
    await tester.pumpAndSettle();
  });

  testWidgets(
    'Themes copy, compact layout, links and the forgot password help',
    (tester) async {
      phonewebBrand.value = const Brand(
        title: 'Loja Centro',
        login: {
          'layout': 'compact',
          'privacyUrl': 'https://example.com/privacy',
          'termsUrl': 'javascript:alert(1)',
          'texts': {
            'pt-BR': {'title': 'Telefone da Loja'},
          },
        },
      );
      final controller = _controller(
        MockClient((_) async => http.Response('{}', 500)),
      );
      await _pump(tester, controller);
      expect(find.text('Telefone da Loja'), findsOneWidget);
      expect(find.text('Suas chamadas.\nEm qualquer lugar.'), findsNothing);
      expect(find.text('Loja Centro'), findsOneWidget);
      expect(find.text('Privacidade'), findsOneWidget);
      expect(find.text('Termos de uso'), findsNothing);

      await tester.tap(find.byKey(const Key('forgotPassword')));
      await tester.pumpAndSettle();
      expect(find.text('Recuperar senha'), findsOneWidget);
      await tester.tap(find.text('Fechar'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('accessLanguage')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('English (US)').last);
      await tester.pumpAndSettle();
      expect(find.text('Continue without an account'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
