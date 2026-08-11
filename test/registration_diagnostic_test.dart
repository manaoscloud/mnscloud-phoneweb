import 'package:flutter_test/flutter_test.dart';
import 'package:mnscloud_phoneweb/src/account/webrtc_account.dart';

void main() {
  group('RegistrationDiagnostic.fromSipFailure', () {
    test('classifies request timeouts as retryable warnings', () {
      final diagnostic = RegistrationDiagnostic.fromSipFailure(
        statusCode: 408,
        cause: 'REQUEST_TIMEOUT',
        reasonPhrase: 'Request Timeout',
      );

      expect(diagnostic.code, 'sip_timeout');
      expect(diagnostic.retrying, isTrue);
      expect(diagnostic.severity, RegistrationDiagnosticSeverity.warning);
      expect(diagnostic.summary, '408 · Server did not respond');
    });

    test('classifies forbidden responses as non-retryable errors', () {
      final diagnostic = RegistrationDiagnostic.fromSipFailure(
        statusCode: 403,
        cause: 'SIP_FAILURE_CODE',
        reasonPhrase: 'Forbidden',
      );

      expect(diagnostic.code, 'sip_forbidden');
      expect(diagnostic.retrying, isFalse);
      expect(diagnostic.severity, RegistrationDiagnosticSeverity.error);
      expect(diagnostic.summary, '403 · Registration forbidden');
    });

    test('sanitizes copied diagnostic text', () {
      final diagnostic = RegistrationDiagnostic.fromSipFailure(
        statusCode: 503,
        cause: 'SIP_FAILURE_CODE',
        reasonPhrase: 'Service\nUnavailable',
      );

      expect(diagnostic.code, 'sip_server_error');
      expect(diagnostic.copyText, isNot(contains('\nUnavailable')));
      expect(diagnostic.copyText, contains('Retrying: yes'));
    });
  });
}
