import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:sip_ua/sip_ua.dart';

import '../account/webrtc_account.dart';
import '../audio/ringtone_player.dart';

class PhoneWebVoipController extends ChangeNotifier
    implements SipUaHelperListener {
  PhoneWebVoipController({SIPUAHelper? helper})
    : _helper = helper ?? SIPUAHelper() {
    _helper.addSipUaHelperListener(this);
    _remoteAudioReady = _remoteAudio.initialize();
  }

  final SIPUAHelper _helper;
  final RTCVideoRenderer _remoteAudio = RTCVideoRenderer();
  final RingtonePlayer _ringtone = RingtonePlayer();
  late final Future<void> _remoteAudioReady;
  WebRtcAccount? _account;
  Call? _activeCall;
  RegistrationStatus _registrationStatus = RegistrationStatus.offline;
  RegistrationDiagnostic? _registrationDiagnostic;
  TransportStateEnum _transportState = TransportStateEnum.NONE;
  CallStateEnum _callState = CallStateEnum.NONE;
  String _lastEvent = 'Ready';
  bool _muted = false;
  bool _onHold = false;
  bool _started = false;
  bool _manualStopRequested = false;

  WebRtcAccount? get account => _account;
  RegistrationStatus get registrationStatus => _registrationStatus;
  RegistrationDiagnostic? get registrationDiagnostic => _registrationDiagnostic;
  TransportStateEnum get transportState => _transportState;
  CallStateEnum get callState => _callState;
  String get lastEvent => _lastEvent;
  bool get muted => _muted;
  bool get onHold => _onHold;
  bool get isRegistered => _helper.registered;
  bool get hasActiveCall => _activeCall != null;
  bool get hasEstablishedCall =>
      _activeCall != null &&
      (_callState == CallStateEnum.ACCEPTED ||
          _callState == CallStateEnum.CONFIRMED ||
          _callState == CallStateEnum.STREAM ||
          _callState == CallStateEnum.MUTED ||
          _callState == CallStateEnum.UNMUTED ||
          _callState == CallStateEnum.HOLD ||
          _callState == CallStateEnum.UNHOLD);
  bool get hasIncomingCall =>
      _activeCall != null &&
      _activeCall!.direction == Direction.incoming &&
      !hasEstablishedCall &&
      _callState != CallStateEnum.FAILED &&
      _callState != CallStateEnum.ENDED &&
      _callState != CallStateEnum.NONE;
  String get remoteIdentity => _activeCall?.remote_identity ?? '';

  Future<void> register(WebRtcAccount account) async {
    final password = account.password.trim();
    if (password.isEmpty) {
      _setEvent('Password is required to register ${account.name}');
      _registrationStatus = RegistrationStatus.failed;
      notifyListeners();
      return;
    }

    final webSocketUrl = account.wssServer.trim();
    final uri = Uri.tryParse(webSocketUrl);
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
    _manualStopRequested = false;
    _registrationStatus = RegistrationStatus.registering;
    _registrationDiagnostic = RegistrationDiagnostic.registering();
    _setEvent('Registering ${account.name}');
    notifyListeners();

    final settings = UaSettings()
      ..transportType = TransportType.WS
      ..uri = 'sip:${account.username}@${account.domain}'
      ..webSocketUrl = webSocketUrl
      ..host = account.domain
      ..authorizationUser = account.username
      ..password = password
      ..displayName = account.displayName.isEmpty
          ? account.username
          : account.displayName
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
    _manualStopRequested = true;
    if (_helper.registered) {
      await _helper.unregister(true);
    } else {
      if (_started) {
        _helper.stop();
      }
      _started = false;
      _registrationStatus = RegistrationStatus.offline;
      _registrationDiagnostic = RegistrationDiagnostic.stopped();
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
    final started = await _helper.call(
      target,
      voiceOnly: true,
      customOptions: _callOptions(currentAccount),
      mediaStream: stream,
    );
    _setEvent(started ? 'Calling $target' : 'Call could not be started');
    notifyListeners();
  }

  Future<void> answer() async {
    final call = _activeCall;
    if (call == null) return;

    final stream = await _microphoneStream();
    call.answer(_callOptions(_account), mediaStream: stream);
    _setEvent('Call answered');
    notifyListeners();
  }

  void rejectOrHangup() {
    final call = _activeCall;
    if (call == null) return;

    _stopRingtone();
    call.hangup();
    _clearActiveCall(CallStateEnum.ENDED);
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
    if (state.state == TransportStateEnum.DISCONNECTED &&
        !_manualStopRequested) {
      if (_registrationStatus == RegistrationStatus.registered ||
          _registrationStatus == RegistrationStatus.registering) {
        _registrationStatus = RegistrationStatus.registering;
      }
      _registrationDiagnostic = RegistrationDiagnostic.fromTransport(
        transportState: state.state.name.toLowerCase(),
        statusCode: state.cause?.status_code,
        cause: state.cause?.cause,
        reasonPhrase: state.cause?.reason_phrase,
      );
      _setEvent(_registrationDiagnostic!.summary);
      notifyListeners();
      return;
    }
    _setEvent('Transport ${state.state.name.toLowerCase()}');
    notifyListeners();
  }

  @override
  void registrationStateChanged(RegistrationState state) {
    if (!_manualStopRequested &&
        _helper.registered &&
        (state.state == RegistrationStateEnum.REGISTRATION_FAILED ||
            state.state == RegistrationStateEnum.UNREGISTERED)) {
      _registrationStatus = RegistrationStatus.registered;
      _registrationDiagnostic = RegistrationDiagnostic.registered();
      _started = true;
      _setEvent('Registration registered');
      notifyListeners();
      return;
    }

    final nextStatus = switch (state.state) {
      RegistrationStateEnum.REGISTERED => RegistrationStatus.registered,
      RegistrationStateEnum.REGISTRATION_FAILED => RegistrationStatus.failed,
      RegistrationStateEnum.UNREGISTERED => RegistrationStatus.offline,
      RegistrationStateEnum.NONE || null => RegistrationStatus.offline,
    };

    final unexpectedUnregistered =
        !_manualStopRequested &&
        nextStatus == RegistrationStatus.offline &&
        (_started ||
            _registrationStatus == RegistrationStatus.registered ||
            _registrationStatus == RegistrationStatus.registering);

    _registrationStatus = unexpectedUnregistered
        ? RegistrationStatus.registering
        : nextStatus;

    if (_registrationStatus == RegistrationStatus.offline ||
        _registrationStatus == RegistrationStatus.failed) {
      _started = false;
    }
    if (_registrationStatus == RegistrationStatus.registered) {
      _manualStopRequested = false;
      _registrationDiagnostic = RegistrationDiagnostic.registered();
    } else if (unexpectedUnregistered) {
      _registrationDiagnostic = RegistrationDiagnostic.interrupted(
        statusCode: state.cause?.status_code,
        cause: state.cause?.cause,
        reasonPhrase: state.cause?.reason_phrase,
      );
    } else if (_registrationStatus == RegistrationStatus.registering) {
      _registrationDiagnostic = RegistrationDiagnostic.registering();
    } else if (_registrationStatus == RegistrationStatus.failed) {
      _registrationDiagnostic = RegistrationDiagnostic.fromSipFailure(
        statusCode: state.cause?.status_code,
        cause: state.cause?.cause,
        reasonPhrase: state.cause?.reason_phrase,
      );
    } else if (_registrationStatus == RegistrationStatus.offline) {
      _registrationDiagnostic = RegistrationDiagnostic.stopped();
    }
    _setEvent(
      (_registrationStatus == RegistrationStatus.failed ||
                  unexpectedUnregistered) &&
              _registrationDiagnostic != null
          ? _registrationDiagnostic!.summary
          : 'Registration ${_registrationStatus.label.toLowerCase()}',
    );
    notifyListeners();
  }

  @override
  void callStateChanged(Call call, CallState state) {
    if (_shouldRejectBusy(call, state)) {
      _setEvent('Rejected overlapping incoming call');
      call.hangup({'status_code': 486, 'reason_phrase': 'Busy Here'});
      notifyListeners();
      return;
    }

    _callState = state.state;

    switch (state.state) {
      case CallStateEnum.NONE:
      case CallStateEnum.ENDED:
      case CallStateEnum.FAILED:
        _clearActiveCall(state.state);
      case CallStateEnum.MUTED:
        _activeCall = call;
        _muted = true;
      case CallStateEnum.UNMUTED:
        _activeCall = call;
        _muted = false;
      case CallStateEnum.HOLD:
        _activeCall = call;
        _onHold = true;
      case CallStateEnum.UNHOLD:
        _activeCall = call;
        _onHold = false;
      case CallStateEnum.CALL_INITIATION:
      case CallStateEnum.PROGRESS:
        _activeCall = call;
        if (call.direction == Direction.incoming) {
          _startRingtone();
        }
      case CallStateEnum.ACCEPTED:
      case CallStateEnum.CONFIRMED:
        _activeCall = call;
        _stopRingtone();
      case CallStateEnum.STREAM:
        _activeCall = call;
        _stopRingtone();
        if (state.stream != null && state.originator == Originator.remote) {
          _attachRemoteStream(state.stream!);
        }
      default:
        _activeCall = call;
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
    _ringtone.dispose();
    _clearRemoteAudio();
    _remoteAudioReady.whenComplete(_remoteAudio.dispose);
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

  Map<String, dynamic> _callOptions(WebRtcAccount? account) {
    final options = _helper.buildCallOptions(true);
    final policy =
        account?.codecPolicy ?? WebRtcCodecPolicy.automaticRecommended;
    final modifier = _codecPolicyModifier(policy);

    final rtcOfferConstraints = Map<String, dynamic>.from(
      options['rtcOfferConstraints'] as Map,
    );
    final rtcAnswerConstraints = Map<String, dynamic>.from(
      options['rtcAnswerConstraints'] as Map,
    );
    rtcOfferConstraints['offerModifiers'] = [modifier];
    rtcAnswerConstraints['offerModifiers'] = [modifier];

    return {
      ...options,
      'rtcOfferConstraints': rtcOfferConstraints,
      'rtcAnswerConstraints': rtcAnswerConstraints,
    };
  }

  Future<RTCSessionDescription> Function(RTCSessionDescription)
  _codecPolicyModifier(WebRtcCodecPolicy policy) {
    return (description) async {
      final sdp = description.sdp;
      if (sdp == null || sdp.isEmpty) return description;
      return RTCSessionDescription(
        _filterAudioCodecs(sdp, policy.allowedAudioCodecs),
        description.type,
      );
    };
  }

  String _filterAudioCodecs(String sdp, Set<String> allowedCodecs) {
    final lines = sdp.split(RegExp(r'\r?\n'));
    final payloadCodecs = <String, String>{};
    final audioPayloads = <String>{};
    var inAudio = false;

    for (final line in lines) {
      if (line.startsWith('m=')) {
        inAudio = line.startsWith('m=audio ');
        if (inAudio) {
          final parts = line.split(RegExp(r'\s+'));
          audioPayloads
            ..clear()
            ..addAll(parts.skip(3));
        }
        continue;
      }

      if (!inAudio) continue;
      final match = RegExp(r'^a=rtpmap:([0-9]+)\s+([^/]+)/').firstMatch(line);
      if (match == null) continue;
      payloadCodecs[match.group(1)!] = match.group(2)!.toLowerCase();
    }

    final allowedPayloads = audioPayloads.where((payload) {
      final codec = payloadCodecs[payload]?.toLowerCase();
      return codec == null ||
          allowedCodecs.contains(codec) ||
          codec == 'telephone-event';
    }).toSet();

    if (allowedPayloads.isEmpty) return sdp;

    final filtered = <String>[];
    inAudio = false;

    for (final line in lines) {
      if (line.startsWith('m=')) {
        inAudio = line.startsWith('m=audio ');
        if (inAudio) {
          final parts = line.split(RegExp(r'\s+'));
          final retained = parts.skip(3).where(allowedPayloads.contains);
          filtered.add([...parts.take(3), ...retained].join(' '));
          continue;
        }
      }

      if (inAudio && _isPayloadAttribute(line)) {
        final payload = _payloadFromAttribute(line);
        if (payload != null && !allowedPayloads.contains(payload)) {
          continue;
        }
      }

      filtered.add(line);
    }

    return filtered.join('\r\n');
  }

  bool _isPayloadAttribute(String line) {
    return line.startsWith('a=rtpmap:') ||
        line.startsWith('a=fmtp:') ||
        line.startsWith('a=rtcp-fb:');
  }

  String? _payloadFromAttribute(String line) {
    final match = RegExp(
      r'^a=(?:rtpmap|fmtp|rtcp-fb):([0-9]+)',
    ).firstMatch(line);
    return match?.group(1);
  }

  bool _shouldRejectBusy(Call call, CallState state) {
    final active = _activeCall;
    if (active == null || active.id == call.id) return false;
    if (call.direction != Direction.incoming) return false;
    return state.state == CallStateEnum.CALL_INITIATION ||
        state.state == CallStateEnum.PROGRESS;
  }

  void _clearActiveCall(CallStateEnum state) {
    _stopRingtone();
    _clearRemoteAudio();
    _activeCall = null;
    _callState = state;
    _muted = false;
    _onHold = false;
  }

  void _startRingtone() {
    _ringtone.start();
  }

  void _stopRingtone() {
    _ringtone.stop();
  }

  void _attachRemoteStream(MediaStream stream) {
    _remoteAudioReady
        .then((_) {
          _remoteAudio.srcObject = stream;
          _remoteAudio.setVolume(1);
        })
        .catchError((Object error) {
          _setEvent('Remote audio could not be attached');
          notifyListeners();
        });
  }

  void _clearRemoteAudio() {
    _remoteAudioReady
        .then((_) {
          _remoteAudio.srcObject = null;
        })
        .catchError((Object _) {});
  }

  void _setEvent(String event) {
    _lastEvent = event;
  }
}
