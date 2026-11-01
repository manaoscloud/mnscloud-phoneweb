import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mnscloud_phoneweb/src/access/access_preferences.dart';
import 'package:mnscloud_phoneweb/src/session/mnscloud_session_api.dart';
import 'package:mnscloud_phoneweb/src/version/app_build_info.dart';
import 'package:mnscloud_phoneweb/src/version/app_update_controller.dart';
import 'package:mnscloud_phoneweb/src/version/app_update_notice.dart';
import 'package:mnscloud_phoneweb/src/version/client_identity.dart';
import 'package:mnscloud_phoneweb/src/version/client_policy.dart';
import 'package:mnscloud_phoneweb/src/version/runtime_version.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final root = Uri.parse('https://pbx.example.com/api/v1/');

  ClientVersionPolicy policy(Map<String, String> minimum) =>
      ClientVersionPolicy(latest: '9.9.9', minimum: minimum);

  AppUpdateController installed({
    required String platform,
    Uri? Function()? apiRoot,
    ClientPolicyReader? reader,
    ValueNotifier<bool>? unsupported,
    bool web = false,
  }) => AppUpdateController(
    reader: () async => null,
    runningVersion: '1.2.3',
    apiRoot: apiRoot ?? () => root,
    policyReader: reader,
    unsupported: unsupported ?? ValueNotifier(false),
    web: web,
    clientPlatform: platform,
  );

  group('installed apps', () {
    for (final platform in ['android', 'ios', 'windows', 'macos', 'linux']) {
      test('$platform below its minimum is critical and visible', () async {
        final controller = installed(
          platform: platform,
          reader: (_) async => policy({platform: '1.3.0'}),
        );
        addTearDown(controller.dispose);
        await controller.check(force: true);
        expect(controller.critical, isTrue);
        expect(controller.noticeVisible, isTrue);
      });
    }

    test('the minimum of another platform does not apply', () async {
      final controller = installed(
        platform: 'android',
        reader: (_) async => policy({'ios': '9.0.0', 'android': '1.2.3'}),
      );
      addTearDown(controller.dispose);
      await controller.check(force: true);
      expect(controller.critical, isFalse);
      expect(controller.noticeVisible, isFalse);
    });

    test('fails open on endpoint failure, no minimum or no server', () async {
      final failing = installed(
        platform: 'android',
        reader: (_) async => throw Exception('offline'),
      );
      final empty = installed(
        platform: 'android',
        reader: (_) async => policy(const {}),
      );
      var calls = 0;
      final noServer = installed(
        platform: 'android',
        apiRoot: () => null,
        reader: (_) async {
          calls += 1;
          return policy({'android': '9.0.0'});
        },
      );
      for (final controller in [failing, empty, noServer]) {
        addTearDown(controller.dispose);
        await controller.check(force: true);
        expect(controller.critical, isFalse);
        expect(controller.noticeVisible, isFalse);
      }
      expect(calls, 0);
    });

    test(
      'reads the policy of the selected server and drops the old one',
      () async {
        Uri? server = root;
        final roots = <Uri>[];
        final controller = installed(
          platform: 'android',
          apiRoot: () => server,
          reader: (apiRoot) async {
            roots.add(apiRoot);
            return policy({'android': apiRoot == root ? '2.0.0' : '1.0.0'});
          },
        );
        addTearDown(controller.dispose);
        await controller.check(force: true);
        expect(controller.critical, isTrue);

        await controller.check();
        expect(roots, hasLength(1), reason: 'same server is not re-read');

        server = Uri.parse('https://other.example.com/api/v1/');
        await controller.check();
        expect(roots.last, server);
        expect(controller.critical, isFalse);
      },
    );

    test('an API 426 CLIENT_VERSION_UNSUPPORTED marks it critical', () async {
      final unsupported = ValueNotifier(false);
      final controller = installed(
        platform: 'android',
        reader: (_) async => null,
        unsupported: unsupported,
      );
      addTearDown(controller.dispose);
      var notified = 0;
      controller.addListener(() => notified += 1);
      unsupported.value = true;
      expect(notified, 1);
      expect(controller.critical, isTrue);
      expect(controller.noticeVisible, isTrue);
    });

    testWidgets('the critical notice has the store text and no buttons', (
      tester,
    ) async {
      accessLocale.value = const Locale('pt', 'BR');
      addTearDown(() => accessLocale.value = null);
      final unsupported = ValueNotifier(true);
      final controller = installed(
        platform: 'android',
        reader: (_) async => null,
        unsupported: unsupported,
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: AppUpdateNotice(controller: controller)),
        ),
      );
      expect(
        find.text(
          'Esta versão do app não é mais aceita. Atualize o app pela loja ou com o administrador para continuar.',
        ),
        findsOneWidget,
      );
      expect(find.byType(FilledButton), findsNothing);
      expect(find.byType(TextButton), findsNothing);
      expect(find.byType(IconButton), findsNothing);
    });
  });

  group('web', () {
    test(
      'ignores the API policy and 426, keeps build.json behaviour',
      () async {
        final unsupported = ValueNotifier(false);
        var policyCalls = 0;
        final controller = installed(
          platform: 'web',
          web: true,
          unsupported: unsupported,
          reader: (_) async {
            policyCalls += 1;
            return policy({'web': '9.0.0'});
          },
        );
        addTearDown(controller.dispose);
        await controller.check(force: true);
        unsupported.value = true;
        expect(policyCalls, 0);
        expect(controller.critical, isFalse);
        expect(controller.noticeVisible, isFalse);

        final t0 = DateTime(2026, 11, 1);
        const build = RuntimeReleaseInfo(
          version: '9.9.9',
          minimumVersion: '2.0.0',
        );
        controller.observe(build, t0);
        controller.observe(build, t0.add(AppUpdateController.confirmDelay));
        expect(controller.critical, isTrue);
        expect(controller.noticeVisible, isTrue);
      },
    );

    testWidgets('the web notice keeps its update button', (tester) async {
      final controller = installed(platform: 'web', web: true);
      addTearDown(controller.dispose);
      final t0 = DateTime(2026, 11, 1);
      const build = RuntimeReleaseInfo(version: '9.9.9');
      controller.observe(build, t0);
      controller.observe(build, t0.add(AppUpdateController.confirmDelay));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: AppUpdateNotice(controller: controller)),
        ),
      );
      expect(find.byType(FilledButton), findsOneWidget);
      expect(find.byType(TextButton), findsOneWidget);
    });
  });

  group('API client', () {
    tearDown(() => clientVersionUnsupported.value = false);

    test('sends the client identity headers on every API call', () async {
      final seen = <http.BaseRequest>[];
      final api = MnscloudSessionApi(
        baseUrl: root,
        client: MockClient((request) async {
          seen.add(request);
          return http.Response(
            jsonEncode({
              'status': 'success',
              'data': {'items': []},
            }),
            200,
          );
        }),
      );
      await api.lines('token');
      await api.signOut('token');
      expect(seen, hasLength(2));
      for (final request in seen) {
        expect(
          request.headers['X-Mns-Client'],
          'mnscloud-phoneweb/${appBuildInfo.version}',
        );
        expect(request.headers['X-Mns-Client-Platform'], 'linux');
      }
      expect(
        mnscloudClientId,
        matches(RegExp(r'^mnscloud-phoneweb/\d+\.\d+\.\d+$')),
      );
    });

    test('a 426 CLIENT_VERSION_UNSUPPORTED raises the signal', () async {
      final api = MnscloudSessionApi(
        baseUrl: root,
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'status': 'error',
              'code': 'CLIENT_VERSION_UNSUPPORTED',
              'error': 'Update the app.',
            }),
            426,
          ),
        ),
      );
      await expectLater(
        api.lines('token'),
        throwsA(
          isA<MnscloudApiException>().having(
            (error) => error.code,
            'code',
            'CLIENT_VERSION_UNSUPPORTED',
          ),
        ),
      );
      expect(clientVersionUnsupported.value, isTrue);
    });

    test('other errors do not raise the signal', () async {
      final api = MnscloudSessionApi(
        baseUrl: root,
        client: MockClient(
          (_) async => http.Response(jsonEncode({'code': 'OTHER'}), 426),
        ),
      );
      await expectLater(
        api.lines('token'),
        throwsA(isA<MnscloudApiException>()),
      );
      expect(clientVersionUnsupported.value, isFalse);
    });

    test('reads the policy endpoint of the API root', () async {
      Uri? url;
      final result = await fetchClientVersionPolicy(
        root,
        client: MockClient((request) async {
          url = request.url;
          return http.Response(
            jsonEncode({
              'status': 'success',
              'data': {
                'app': 'phoneweb',
                'product': 'mnscloud-phoneweb',
                'latest': '1.4.0',
                'minimum': {'android': '1.3.0', 'ios': null, 'linux': 'bad'},
              },
            }),
            200,
          );
        }),
      );
      expect(
        url.toString(),
        'https://pbx.example.com/api/v1/public/clients/phoneweb/policy',
      );
      expect(result?.latest, '1.4.0');
      expect(result?.minimum, {'android': '1.3.0'});
      final failed = await fetchClientVersionPolicy(
        root,
        client: MockClient((_) async => http.Response('nope', 500)),
      );
      expect(failed, isNull);
    });
  });
}
