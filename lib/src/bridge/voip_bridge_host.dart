import 'package:flutter/foundation.dart';
import 'package:sip_ua/sip_ua.dart';

import '../session/mnscloud_session_controller.dart';
import '../voip/phoneweb_voip_controller.dart';
import 'phone_bridge.dart';

/// Phone Bridge host over the PhoneWeb VoIP and MNSCloud session controllers.
class VoipBridgeHost implements PhoneBridgeHost {
  VoipBridgeHost(this.voip, this.session)
    : changes = Listenable.merge([voip, session]);

  final PhoneWebVoipController voip;
  final MnscloudSessionController session;

  @override
  final Listenable changes;

  @override
  PhoneBridgeSnapshot snapshot() => PhoneBridgeSnapshot(
    signedIn: session.signedIn,
    registration: voip.registrationStatus.name,
    accountName: voip.account?.name,
    callActive: voip.hasActiveCall,
    callDirection: switch (voip.activeCallDirection) {
      Direction.incoming => 'incoming',
      Direction.outgoing => 'outgoing',
      null => null,
    },
    callRemote: voip.hasActiveCall ? voip.remoteIdentity : null,
    callEstablished: voip.hasEstablishedCall,
    callAnswerable: voip.hasAnswerableIncomingCall,
    muted: voip.muted,
  );

  @override
  Future<String?> dial(String number) async {
    if (!voip.isRegistered) return 'NOT_REGISTERED';
    if (voip.hasActiveCall) return 'CALL_ACTIVE';
    await voip.makeCall(number);
    return voip.hasActiveCall ? null : 'CALL_FAILED';
  }

  @override
  Future<String?> answer() async {
    if (!voip.hasAnswerableIncomingCall) return 'NO_INCOMING_CALL';
    await voip.answer();
    return null;
  }

  @override
  String? hangup() {
    if (!voip.hasActiveCall) return 'NO_CALL';
    voip.rejectOrHangup();
    return null;
  }

  @override
  String? setMuted(bool muted) {
    if (!voip.hasEstablishedCall) return 'NO_CALL';
    if (voip.muted != muted) voip.toggleMute();
    return null;
  }

  @override
  String? dtmf(String tones) {
    if (!voip.hasEstablishedCall) return 'NO_CALL';
    for (final tone in tones.split('')) {
      voip.sendDtmf(tone);
    }
    return null;
  }
}
