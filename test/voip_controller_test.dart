import 'package:flutter_test/flutter_test.dart';
import 'package:mnscloud_phoneweb/src/voip/phoneweb_voip_controller.dart';

void main() {
  group('PhoneWebVoipController.normalizeSipWebSocketUrl', () {
    test('adds the default SIP WebSocket path when only host is provided', () {
      expect(
        PhoneWebVoipController.normalizeSipWebSocketUrl(
          'wss://webrtc.example.com',
        ),
        'wss://webrtc.example.com/ws',
      );
    });

    test('keeps explicit WebSocket paths unchanged', () {
      expect(
        PhoneWebVoipController.normalizeSipWebSocketUrl(
          'wss://webrtc.example.com/sip-ws',
        ),
        'wss://webrtc.example.com/sip-ws',
      );
    });

    test('keeps invalid values unchanged so validation can fail normally', () {
      expect(
        PhoneWebVoipController.normalizeSipWebSocketUrl('https://example.com'),
        'https://example.com',
      );
    });
  });
}
