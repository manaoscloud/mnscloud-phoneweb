import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mnscloud_phoneweb/src/session/mnscloud_session_api.dart';
import 'package:mnscloud_phoneweb/src/session/mnscloud_session_controller.dart';
import 'package:mnscloud_phoneweb/src/session/session_platform.dart';

class FakePlatform extends SessionPlatform {
  FakePlatform() : super(storage: const FlutterSecureStorage());
}

Map<String, Object?> grant(String refresh) => {
  'status': 'success',
  'data': {
    'accessToken': 'access-$refresh',
    'expiresIn': 600,
    'refreshToken': refresh,
    'session': {
      'sessionUUID': 'S1',
      'phoneUserUUID': 'P1',
      'tenantUUID': 'T1',
      'realm': 'employee',
      'displayName': 'AGENTE 1',
      'expiresAt': '2026-10-25T10:00:00.000000Z',
    },
  },
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  MnscloudSessionController controllerWith(MockClient client) {
    return MnscloudSessionController(
      platform: FakePlatform(),
      apiFactory: (server) => MnscloudSessionApi(
        baseUrl: Uri.parse('${server.origin}/api/v1/'),
        client: client,
      ),
    );
  }

  test(
    'native sign-in stores only the refresh token and keeps access in memory',
    () async {
      final requests = <http.Request>[];
      final controller = controllerWith(
        MockClient((request) async {
          requests.add(request);
          return http.Response(jsonEncode(grant('r1')), 200);
        }),
      );

      final ok = await controller.signIn(
        identifier: ' PH7K2Q9Z ',
        password: 'secret',
        server: 'tenant.example.com',
      );

      expect(ok, isTrue);
      expect(controller.signedIn, isTrue);
      expect(controller.accessToken, 'access-r1');
      expect(
        requests
            .firstWhere((r) => r.url.path.endsWith('/signin'))
            .url
            .toString(),
        'https://tenant.example.com/api/v1/phone/auth/signin',
      );
      final body =
          jsonDecode(
                requests.firstWhere((r) => r.url.path.endsWith('/signin')).body,
              )
              as Map<String, dynamic>;
      expect(body['identifier'], 'PH7K2Q9Z');
      expect(body['clientKind'], 'native');
      expect(
        await const FlutterSecureStorage().read(
          key: 'mnscloud:phone_session:refresh_token',
        ),
        'r1',
      );
      controller.dispose();
    },
  );

  test('http servers are refused before any request', () async {
    var calls = 0;
    final controller = controllerWith(
      MockClient((request) async {
        calls++;
        return http.Response('{}', 200);
      }),
    );
    final ok = await controller.signIn(
      identifier: 'a@b.c',
      password: 'x',
      server: 'http://insecure.example.com',
    );
    expect(ok, isFalse);
    expect(calls, 0);
    expect(controller.errorCode, 'SERVER_INVALID');
    controller.dispose();
  });

  test(
    'tenant selection is offered when the login has several companies',
    () async {
      final controller = controllerWith(
        MockClient((request) async {
          return http.Response(
            jsonEncode({
              'error': 'Choose the company to sign in.',
              'code': 'PHONE_TENANT_SELECTION_REQUIRED',
              'tenants': [
                {'tenantUUID': 'T1', 'tenantName': 'Empresa A'},
                {'tenantUUID': 'T2', 'tenantName': 'Empresa B'},
              ],
            }),
            409,
          );
        }),
      );
      await controller.signIn(
        identifier: 'a@b.c',
        password: 'x',
        server: 'https://t.example.com',
      );
      expect(controller.signedIn, isFalse);
      expect(controller.tenantChoices.map((tenant) => tenant.name), [
        'Empresa A',
        'Empresa B',
      ]);
      expect(controller.errorCode, 'PHONE_TENANT_SELECTION_REQUIRED');
      controller.dispose();
    },
  );

  test('restore resumes with the stored token and a 401 forgets it', () async {
    FlutterSecureStorage.setMockInitialValues({
      'mnscloud:phone_session:refresh_token': 'old',
      'mnscloud:phone_session:server': 'https://t.example.com',
    });
    final sent = <String?>[];
    var reject = false;
    final controller = controllerWith(
      MockClient((request) async {
        sent.add((jsonDecode(request.body) as Map)['refreshToken'] as String?);
        return reject
            ? http.Response(
                jsonEncode({'code': 'PHONE_SESSION_INVALID', 'error': 'x'}),
                401,
              )
            : http.Response(jsonEncode(grant('new')), 200);
      }),
    );
    await controller.restore();
    expect(controller.signedIn, isTrue);
    expect(sent, ['old']);
    expect(
      await const FlutterSecureStorage().read(
        key: 'mnscloud:phone_session:refresh_token',
      ),
      'new',
    );

    await controller.signOut();
    expect(controller.signedIn, isFalse);
    expect(
      await const FlutterSecureStorage().read(
        key: 'mnscloud:phone_session:refresh_token',
      ),
      isNull,
    );

    FlutterSecureStorage.setMockInitialValues({
      'mnscloud:phone_session:refresh_token': 'leaked',
      'mnscloud:phone_session:server': 'https://t.example.com',
    });
    reject = true;
    final second = controllerWith(
      MockClient(
        (request) async => http.Response(
          jsonEncode({'code': 'PHONE_SESSION_INVALID', 'error': 'x'}),
          401,
        ),
      ),
    );
    await second.restore();
    expect(second.signedIn, isFalse);
    expect(second.errorMessage, isNull, reason: 'restore failures are silent');
    expect(
      await const FlutterSecureStorage().read(
        key: 'mnscloud:phone_session:refresh_token',
      ),
      isNull,
    );
    controller.dispose();
    second.dispose();
  });

  test('API errors map to user messages', () async {
    final controller = controllerWith(
      MockClient(
        (request) async => http.Response(
          jsonEncode({'code': 'PHONE_USE_APP_SIGNIN', 'error': 'x'}),
          403,
        ),
      ),
    );
    await controller.signIn(
      identifier: 'a@b.c',
      password: 'x',
      server: 'https://t.example.com',
    );
    expect(controller.errorMessage, contains('abra o PhoneWeb'));
    controller.dispose();
  });

  test(
    'signed-in sessions load lines, fetch credentials and take pool lines',
    () async {
      final paths = <String>[];
      var claimed = false;
      final controller = controllerWith(
        MockClient((request) async {
          paths.add('${request.method} ${request.url.path}');
          final path = request.url.path;
          if (path.endsWith('/phone/auth/signin')) {
            return http.Response(jsonEncode(grant('r1')), 200);
          }
          if (path.endsWith('/phone/lines')) {
            expect(request.headers['Authorization'], 'Bearer access-r1');
            return http.Response(
              jsonEncode({
                'data': {
                  'items': [
                    {
                      'lineKey': 'L1',
                      'source': 'assigned',
                      'mode': 'dedicated',
                      'primary': true,
                      'webrtcReady': true,
                      'username': '1001',
                      'label': '1001 · RECEPCAO',
                    },
                    if (claimed)
                      {
                        'lineKey': 'C1',
                        'source': 'claimed',
                        'mode': 'claimed',
                        'primary': false,
                        'webrtcReady': true,
                        'username': '1003',
                        'label': '1003',
                      },
                  ],
                },
              }),
              200,
            );
          }
          if (path.endsWith('/phone/lines/available')) {
            return http.Response(
              jsonEncode({
                'data': {
                  'items': claimed
                      ? []
                      : [
                          {
                            'poolUUID': 'P3',
                            'label': '1003',
                            'notes': 'POSICAO 3',
                          },
                        ],
                },
              }),
              200,
            );
          }
          if (path.endsWith('/phone/lines/claims')) {
            claimed = true;
            return http.Response(jsonEncode({'data': {}}), 201);
          }
          if (path.endsWith('/phone/lines/claims/C1')) {
            claimed = false;
            return http.Response(jsonEncode({'data': {}}), 200);
          }
          if (path.endsWith('/phone/lines/L1/credentials')) {
            return http.Response(
              jsonEncode({
                'data': {
                  'lineKey': 'L1',
                  'label': '1001 · RECEPCAO',
                  'sip': {
                    'username': '1001',
                    'password': 'line-secret',
                    'domain': 'pbx.example.com',
                    'displayName': 'RECEPCAO',
                  },
                  'wssUrl': 'wss://webrtc.example.com/ws',
                  'iceServers': [
                    {
                      'urls': ['stun:turn.example.com:3478'],
                    },
                  ],
                },
              }),
              200,
            );
          }
          return http.Response('{}', 404);
        }),
      );
      await controller.signIn(
        identifier: 'a@b.c',
        password: 'x',
        server: 'https://t.example.com',
      );
      await Future<void>.delayed(Duration.zero);
      await controller.refreshLines();
      expect(controller.lines.single.primary, isTrue);
      expect(controller.availableLines.single.notes, 'POSICAO 3');
      final credentials = await controller.lineCredentials('L1');
      expect(credentials?.password, 'line-secret');
      expect(credentials?.wssUrl, 'wss://webrtc.example.com/ws');
      expect(credentials?.stunUrls, ['stun:turn.example.com:3478']);
      expect(await controller.claimLine('P3'), isTrue);
      expect(controller.lines.map((line) => line.lineKey), ['L1', 'C1']);
      expect(controller.availableLines, isEmpty);
      expect(await controller.releaseLine('C1'), isTrue);
      expect(controller.lines.map((line) => line.lineKey), ['L1']);
      await controller.signOut();
      expect(controller.lines, isEmpty);
      controller.dispose();
    },
  );
}
