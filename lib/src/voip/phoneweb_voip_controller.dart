import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:sip_ua/sip_ua.dart';

import '../account/webrtc_account.dart';

class PhoneWebVoipController extends ChangeNotifier
    implements SipUaHelperListener {
  PhoneWebVoipController({SIPUAHelper? helper})
      : _helper = helper ?? SIPUAHelper() {
    _helper.addSipUaHelperListener(this);
  }

  final SIPUAHelper _helper;
  WebRtcAccount? _account;
  Call? _activeCall;
  RegistrationStatus _registrationStatus = RegistrationStatus.offline;
  TransportStateEnum _transportState = TransportStateEnum.NONE;
  CallStateEnum _callState = CallStateEnum.NONE;
  String _lastEvent = 'Ready';
  bool _muted = false;
  bool _onHold = false;
  bool _started = false;

  WebRtcAccount? get account => _account;
  RegistrationStatus get registrationStatus => _registrationStatus;
  TransportStateEnum get transportState => _transportState;
  CallStateEnum get callState => _callState;
  String get lastEvent => _lastEvent;
  bool get muted => _muted;
  bool get onHold => _onHold;
  bool get isRegistered => _helper.registered;
  bool get hasActiveCall => _activeCall != null;
  bool get hasIncomingCall =>
      _activeCall != null &&
      _activeCall!.direction == Direction.incoming &&
      (_callState == CallStateEnum.CALL_INITIATION ||
          _callState == CallStateEnum.CONNECTING);
  String get remoteIdentity => _activeCall?.remote_identity ?? '';

  Future<void> register(WebRtcAccount account) async {
    final password = account.password.trim();
    if (password.isEmpty) {
      _setEvent('Password is required to register ${account.name}');
      _registrationStatus = RegistrationStatus.failed;
      notifyListeners();
      return;
    }

    final uri = Uri.tryParse(account.wssServer);
    if (uri == null || (uri.scheme != 'wss' && uri.scheme != 'ws')) {
      _setEvent('WebSocket URL is invalid for ${account.name}');
      _registrationStatus = RegistrationStatus.failed;
      notifyListeners();
      return;
    }
    if (uri.scheme == 'ws' && !account.allowInsecureTransport && !kDebugMode) {
      _setEvent('Insecure WS is disabled for ${account.name}');
      _registrationStatus = RegistrationStatus.failed;
      notifyListeners();
      return;
    }

    _account = account;
    _registrationStatus = RegistrationStatus.registering;
    _setEvent('Registering ${account.name}');
    notifyListeners();

    final settings = UaSettings()
      ..transportType = TransportType.WS
      ..uri = 'sip:${account.username}@${account.domain}'
      ..webSocketUrl = account.wssServer
      ..host = account.domain
      ..authorizationUser = account.username
      ..password = password
      ..displayName =
          account.displayName.isEmpty ? account.username : account.displayName
      ..userAgent = 'MNSCloud PhoneWeb'
      ..dtmfMode = DtmfMode.RFC2833
      ..contact_uri = 'sip:${account.username}@${account.domain}'
      ..register = true
      ..register_expires = 600
      ..iceServers = _iceServers(account);

    settings.webSocketSettings.allowBadCertificate =
        account.allowInsecureTransport;
    settings.tcpSocketSettings.allowBadCertificate =
        account.allowInsecureTransport;

    _started = true;
    await _helper.start(settings);
  }

  Future<void> unregister() async {
    if (_helper.registered) {
      await _helper.unregister(true);
    } else {
      if (_started) {
        _helper.stop();
      }
      _started = false;
      _registrationStatus = RegistrationStatus.offline;
      _setEvent('Registration stopped');
      notifyListeners();
    }
  }

  Future<void> makeCall(String destination) async {
    final currentAccount = _account;
    if (currentAccount == null || !_helper.connected) {
      _setEvent('Register an account before placing calls');
      notifyListeners();
      return;
    }

    final target = _normalizeTarget(destination, currentAccount.domain);
    final stream = await _microphoneStream();
    final started =
        await _helper.call(target, voiceOnly: true, mediaStream: stream);
    _setEvent(started ? 'Calling $target' : 'Call could not be started');
    notifyListeners();
  }

  Future<void> answer() async {
    final call = _activeCall;
    if (call == null) return;

    final stream = await _microphoneStream();
    call.answer(_helper.buildCallOptions(true), mediaStream: stream);
    _setEvent('Call answered');
    notifyListeners();
  }

  void rejectOrHangup() {
    final call = _activeCall;
    if (call == null) return;

    call.hangup();
    _activeCall = null;
    _callState = CallStateEnum.ENDED;
    _muted = false;
    _onHold = false;
    _setEvent('Call ended');
    notifyListeners();
  }

  void toggleMute() {
    final call = _activeCall;
    if (call == null) return;

    if (_muted) {
      call.unmute(true, false);
    } else {
      call.mute(true, false);
    }
  }

  void toggleHold() {
    final call = _activeCall;
    if (call == null) return;

    if (_onHold) {
      call.unhold();
    } else {
      call.hold();
    }
  }

  void sendDtmf(String tone) {
    final call = _activeCall;
    if (call == null) return;

    call.sendDTMF(tone);
    _setEvent('DTMF $tone sent');
    notifyListeners();
  }

  @override
  void transportStateChanged(TransportState state) {
    _transportState = state.state;
    _setEvent('Transport ${state.state.name.toLowerCase()}');
    notifyListeners();
  }

  @override
  void registrationStateChanged(RegistrationState state) {
    _registrationStatus = switch (state.state) {
      RegistrationStateEnum.REGISTERED => RegistrationStatus.registered,
      RegistrationStateEnum.REGISTRATION_FAILED => RegistrationStatus.failed,
      RegistrationStateEnum.UNREGISTERED => RegistrationStatus.offline,
      RegistrationStateEnum.NONE || null => RegistrationStatus.offline,
    };
    if (_registrationStatus == RegistrationStatus.offline ||
        _registrationStatus == RegistrationStatus.failed) {
      _started = false;
    }
    _setEvent('Registration ${_registrationStatus.label.toLowerCase()}');
    notifyListeners();
  }

  @override
  void callStateChanged(Call call, CallState state) {
    _activeCall = call;
    _callState = state.state;

    switch (state.state) {
      case CallStateEnum.MUTED:
        _muted = true;
      case CallStateEnum.UNMUTED:
        _muted = false;
      case CallStateEnum.HOLD:
        _onHold = true;
      case CallStateEnum.UNHOLD:
        _onHold = false;
      case CallStateEnum.ENDED:
      case CallStateEnum.FAILED:
        _activeCall = null;
        _muted = false;
        _onHold = false;
      default:
        break;
    }

    _setEvent('Call ${state.state.name.toLowerCase()}');
    notifyListeners();
  }

  @override
  void onNewMessage(SIPMessageRequest msg) {
    _setEvent('SIP message received');
    notifyListeners();
  }

  @override
  void onNewNotify(Notify ntf) {
    _setEvent('SIP notify received');
    notifyListeners();
  }

  @override
  void onNewReinvite(ReInvite event) {
    _setEvent('SIP re-invite received');
    notifyListeners();
  }

  @override
  void dispose() {
    _helper.removeSipUaHelperListener(this);
    if (_started) {
      _helper.stop();
    }
    super.dispose();
  }

  List<Map<String, String>> _iceServers(WebRtcAccount account) {
    final servers = <Map<String, String>>[];
    if (account.stunServer.trim().isNotEmpty) {
      servers.add({'urls': account.stunServer.trim()});
    }
    if (account.turnServer.trim().isNotEmpty) {
      servers.add({'urls': account.turnServer.trim()});
    }
    if (servers.isEmpty) {
      servers.add({'urls': 'stun:stun.l.google.com:19302'});
    }
    return servers;
  }

  String _normalizeTarget(String destination, String domain) {
    final clean = destination.trim();
    if (clean.startsWith('sip:')) return clean;
    if (clean.contains('@')) return 'sip:$clean';
    return 'sip:$clean@$domain';
  }

  Future<MediaStream> _microphoneStream() {
    return navigator.mediaDevices.getUserMedia(<String, dynamic>{
      'audio': true,
      'video': false,
    });
  }

  void _setEvent(String event) {
    _lastEvent = event;
  }
}
