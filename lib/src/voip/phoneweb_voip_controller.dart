import 'dart:async';

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
  final Map<String, Timer> _terminatedCallGuards = <String, Timer>{};
  final Set<String> _confirmedCallIds = <String>{};
  final Set<String> _answerRequestedCallIds = <String>{};
  Timer? _callDurationTimer;
  Timer? _answerConfirmationTimer;
  WebRtcAccount? _account;
  Call? _activeCall;
  DateTime? _callStartedAt;
  Duration _callDuration = Duration.zero;
  RegistrationStatus _registrationStatus = RegistrationStatus.offline;
  RegistrationDiagnostic? _registrationDiagnostic;
  TransportStateEnum _transportState = TransportStateEnum.NONE;
  CallStateEnum _callState = CallStateEnum.NONE;
  String _lastEvent = 'Ready';
  String _lastCallDiagnostic = '';
  bool _debugLoggingEnabled = false;
  bool _muted = false;
  bool _onHold = false;
  bool _started = false;
  bool _manualStopRequested = false;
  bool _activeCallHasRemoteStream = false;
  Future<void>? _registerInFlight;
  String? _activeAccountKey;
  final List<PhoneWebDebugEvent> _debugEvents = <PhoneWebDebugEvent>[];

  WebRtcAccount? get account => _account;
  RegistrationStatus get registrationStatus => _registrationStatus;
  RegistrationDiagnostic? get registrationDiagnostic => _registrationDiagnostic;
  TransportStateEnum get transportState => _transportState;
  CallStateEnum get callState => _callState;
  String get lastEvent => _lastEvent;
  String get lastCallDiagnostic => _lastCallDiagnostic;
  bool get debugLoggingEnabled => _debugLoggingEnabled;
  List<PhoneWebDebugEvent> get debugEvents => List.unmodifiable(_debugEvents);
  bool get muted => _muted;
  bool get onHold => _onHold;
  Duration get callDuration => _callDuration;
  bool get isRegistered => _helper.registered;
  bool get hasActiveCall => _activeCall != null;
  Direction? get activeCallDirection => _activeCall?.direction;
  bool get hasEstablishedCall =>
      _activeCall != null &&
      (_callState == CallStateEnum.CONFIRMED ||
          (_callState == CallStateEnum.STREAM &&
              _isCallConfirmed(_activeCall)) ||
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
  bool get hasAnswerableIncomingCall =>
      hasIncomingCall &&
      !_isAnswerRequested(_activeCall) &&
      (_callState == CallStateEnum.CALL_INITIATION ||
          _callState == CallStateEnum.CONNECTING ||
          _callState == CallStateEnum.PROGRESS);
  bool get hasPendingAnsweredIncomingCall =>
      hasIncomingCall && !hasAnswerableIncomingCall;
  String get remoteIdentity => _activeCall?.remote_identity ?? '';
  String get formattedCallDuration {
    final totalSeconds = _callDuration.inSeconds;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    if (hours > 0) {
      return [
        hours.toString().padLeft(2, '0'),
        minutes.toString().padLeft(2, '0'),
        seconds.toString().padLeft(2, '0'),
      ].join(':');
    }
    return [
      minutes.toString().padLeft(2, '0'),
      seconds.toString().padLeft(2, '0'),
    ].join(':');
  }

  Future<void> register(WebRtcAccount account) async {
    _debug('register.request', {
      'account': account.name,
      'username': account.username,
      'domain': account.domain,
      'wss': account.wssServer,
      'status': account.status.name,
      'autoRegister': account.autoRegister,
      'enabled': account.enabled,
    });
    final nextAccountKey = _accountKey(account);
    final sameAccount = _activeAccountKey == nextAccountKey;
    if (_activeCall != null && !sameAccount) {
      _setEvent('Cannot switch accounts while a call is active');
      notifyListeners();
      return;
    }
    if (sameAccount &&
        _started &&
        (_helper.registered ||
            _helper.connected ||
            _helper.connecting ||
            _registrationStatus == RegistrationStatus.registering)) {
      _account = account;
      if (_helper.registered) {
        _registrationStatus = RegistrationStatus.registered;
        _registrationDiagnostic = RegistrationDiagnostic.registered();
      }
      _setEvent(
        _helper.registered
            ? '${account.name} already registered'
            : '${account.name} registration already active',
      );
      notifyListeners();
      return _registerInFlight ?? Future<void>.value();
    }

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
      ..connectionRecoveryMinInterval = 15
      ..connectionRecoveryMaxInterval = 60
      ..iceGatheringTimeout = 500
      ..iceServers = _iceServers(account);

    settings.webSocketSettings.allowBadCertificate =
        account.allowInsecureTransport;
    settings.tcpSocketSettings.allowBadCertificate =
        account.allowInsecureTransport;

    _account = account;
    _activeAccountKey = nextAccountKey;
    _manualStopRequested = false;
    _registrationStatus = RegistrationStatus.registering;
    _registrationDiagnostic = RegistrationDiagnostic.registering();
    _setEvent('Registering ${account.name}');
    notifyListeners();

    _started = true;
    final future = _helper.start(settings);
    _registerInFlight = future;
    try {
      await future;
    } finally {
      if (identical(_registerInFlight, future)) {
        _registerInFlight = null;
      }
    }
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
      _activeAccountKey = null;
      _registrationStatus = RegistrationStatus.offline;
      _registrationDiagnostic = RegistrationDiagnostic.stopped();
      _setEvent('Registration stopped');
      notifyListeners();
    }
  }

  Future<void> makeCall(String destination) async {
    final currentAccount = _account;
    if (currentAccount == null || !_helper.connected || !_helper.registered) {
      _lastCallDiagnostic =
          'Account is not registered or the WebSocket transport is not connected.';
      _setEvent('Register an account before placing calls');
      notifyListeners();
      return;
    }

    final target = _normalizeTarget(destination, currentAccount.domain);
    try {
      _lastCallDiagnostic = '';
      final stream = await _microphoneStream();
      final started = await _helper.call(
        target,
        voiceOnly: true,
        customOptions: _callOptions(currentAccount),
        mediaStream: stream,
      );
      if (!started) {
        _lastCallDiagnostic = 'The SIP/WebRTC stack did not start the call.';
      }
      _setEvent(started ? 'Calling $target' : 'Call could not be started');
    } catch (error) {
      _lastCallDiagnostic = 'Could not access microphone or start call: $error';
      _setEvent('Call could not be started');
    }
    notifyListeners();
  }

  Future<void> answer() async {
    final call = _activeCall;
    if (call == null) return;

    try {
      _debug('call.answer.request', _callDebugData(call));
      final stream = await _microphoneStream();
      _debug('media.microphone.granted', {
        'tracks': stream.getTracks().map((track) => track.kind).join(','),
      });
      _setEvent('Answering call');
      notifyListeners();
      _markAnswerRequested(call);
      _stopRingtone();
      call.answer(_callOptions(_account), mediaStream: stream);
      _setEvent('Call answer requested');
      _startAnswerConfirmationTimer(call);
    } catch (error) {
      _debug('call.answer.error', {
        ..._callDebugData(call),
        'error': error.toString(),
      });
      _lastCallDiagnostic =
          'Could not access microphone or answer call: $error';
      _setEvent('Call answer failed');
      _clearActiveCall(CallStateEnum.FAILED);
    }
    notifyListeners();
  }

  void rejectOrHangup() {
    final call = _activeCall;
    if (call == null) return;

    _debug('call.hangup.request', _callDebugData(call));
    _cancelAnswerConfirmationTimer();
    _stopRingtone();
    _guardTerminatedCall(call);
    try {
      call.hangup();
      _debug('call.hangup.sent', _callDebugData(call));
    } catch (error, stack) {
      _debug('call.hangup.error', {
        ..._callDebugData(call),
        'error': error.toString(),
        'stack': stack.toString().split('\n').take(8).join(' | '),
      });
      _lastCallDiagnostic =
          'PhoneWeb requested hangup, but the SIP/WebRTC stack returned an error while sending BYE: $error';
    }
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
    _debug('transport.state', {
      'state': state.state.name,
      'statusCode': state.cause?.status_code,
      'cause': state.cause?.cause,
      'reason': state.cause?.reason_phrase,
    });
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
    _debug('registration.state', {
      'state': state.state?.name,
      'statusCode': state.cause?.status_code,
      'cause': state.cause?.cause,
      'reason': state.cause?.reason_phrase,
    });
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
    _debug('call.state', {
      ..._callDebugData(call),
      'state': state.state.name,
      'originator': state.originator?.name,
      'hasStream': state.stream != null,
      'statusCode': state.cause?.status_code,
      'cause': state.cause?.cause,
      'reason': state.cause?.reason_phrase,
      'confirmed': _isCallConfirmed(call),
      'answerRequested': _isAnswerRequested(call),
    });
    if (_isGuardedTerminatedCall(call)) {
      _setEvent('Ignored stale call ${state.state.name.toLowerCase()}');
      notifyListeners();
      return;
    }

    if (_shouldRejectBusy(call, state)) {
      _setEvent('Rejected overlapping incoming call');
      call.hangup({'status_code': 486, 'reason_phrase': 'Busy Here'});
      notifyListeners();
      return;
    }

    _callState = state.state;
    final stateDiagnostic = _callDiagnosticFromState(state);
    if (stateDiagnostic.isNotEmpty) {
      _lastCallDiagnostic = stateDiagnostic;
    }

    switch (state.state) {
      case CallStateEnum.NONE:
      case CallStateEnum.ENDED:
      case CallStateEnum.FAILED:
        _cancelAnswerConfirmationTimer();
        _unguardTerminatedCall(call);
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
      case CallStateEnum.CONNECTING:
        _activeCall = call;
      case CallStateEnum.PROGRESS:
        _activeCall = call;
        if (call.direction == Direction.incoming) {
          _startRingtone();
        } else {
          _startRingback();
        }
      case CallStateEnum.ACCEPTED:
        _activeCall = call;
        _markAnswerRequested(call);
        _stopRingtone();
        _stopRingback();
      case CallStateEnum.CONFIRMED:
        _activeCall = call;
        _markAnswerRequested(call);
        _markCallConfirmed(call);
        _cancelAnswerConfirmationTimer();
        _stopRingtone();
        _stopRingback();
        _startCallDuration();
      case CallStateEnum.STREAM:
        _activeCall = call;
        _markAnswerRequested(call);
        if (state.stream != null && state.originator == Originator.remote) {
          _debug('media.remote_stream.received', {
            ..._callDebugData(call),
            'confirmed': _isCallConfirmed(call),
          });
          _activeCallHasRemoteStream = true;
          _stopRingtone();
          _stopRingback();
          _attachRemoteStream(state.stream!);
          if (_isCallConfirmed(call)) {
            _startCallDuration();
          }
        }
      default:
        _activeCall = call;
        break;
    }

    _setEvent('Call ${state.state.name.toLowerCase()}');
    notifyListeners();
  }

  @override
  void onCallDebug(Call call, String event, Map<String, Object?> data) {
    _debug('sdk.$event', {..._callDebugData(call), ...data});
    notifyListeners();
  }

  @override
  void onNewMessage(SIPMessageRequest msg) {
    _debug('sip.message.received', {
      'direction': msg.originator?.name,
      'method': msg.request?.method,
    });
    _setEvent('SIP message received');
    notifyListeners();
  }

  @override
  void onNewNotify(Notify ntf) {
    _debug('sip.notify.received', {'method': ntf.request?.method});
    _setEvent('SIP notify received');
    notifyListeners();
  }

  @override
  void onNewReinvite(ReInvite event) {
    _debug('sip.reinvite.received', {
      'hasAudio': event.hasAudio,
      'hasVideo': event.hasVideo,
    });
    _setEvent('SIP re-invite received');
    notifyListeners();
  }

  @override
  void dispose() {
    _helper.removeSipUaHelperListener(this);
    _ringtone.dispose();
    _clearRemoteAudio();
    _remoteAudioReady.whenComplete(_remoteAudio.dispose);
    _cancelAnswerConfirmationTimer();
    _stopCallDuration();
    for (final timer in _terminatedCallGuards.values) {
      timer.cancel();
    }
    _terminatedCallGuards.clear();
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

  String _accountKey(WebRtcAccount account) {
    return [
      account.id,
      account.username.trim().toLowerCase(),
      account.domain.trim().toLowerCase(),
      account.wssServer.trim().toLowerCase(),
    ].join('|');
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

  void _guardTerminatedCall(Call call) {
    final id = _callGuardId(call);
    if (id == null) return;
    _terminatedCallGuards.remove(id)?.cancel();
    _terminatedCallGuards[id] = Timer(const Duration(minutes: 3), () {
      _terminatedCallGuards.remove(id);
    });
  }

  void _unguardTerminatedCall(Call call) {
    final id = _callGuardId(call);
    if (id == null) return;
    _terminatedCallGuards.remove(id)?.cancel();
  }

  bool _isGuardedTerminatedCall(Call call) {
    final id = _callGuardId(call);
    return id != null && _terminatedCallGuards.containsKey(id);
  }

  String? _callGuardId(Call call) {
    final id = call.id?.trim();
    if (id == null || id.isEmpty) return null;
    return id;
  }

  void _clearActiveCall(CallStateEnum state) {
    _stopRingtone();
    _stopRingback();
    _stopCallDuration();
    _clearRemoteAudio();
    _forgetCallConfirmed(_activeCall);
    _forgetAnswerRequested(_activeCall);
    _activeCall = null;
    _callState = state;
    _muted = false;
    _onHold = false;
    _activeCallHasRemoteStream = false;
  }

  void _startCallDuration() {
    _callStartedAt ??= DateTime.now();
    _callDuration = DateTime.now().difference(_callStartedAt!);
    _callDurationTimer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      final startedAt = _callStartedAt;
      if (startedAt == null) return;
      _callDuration = DateTime.now().difference(startedAt);
      notifyListeners();
    });
  }

  void _stopCallDuration() {
    _callDurationTimer?.cancel();
    _callDurationTimer = null;
    _callStartedAt = null;
    _callDuration = Duration.zero;
  }

  void _startAnswerConfirmationTimer(Call call) {
    _cancelAnswerConfirmationTimer();
    _answerConfirmationTimer = Timer(const Duration(seconds: 12), () {
      if (_activeCall?.id != call.id || _isCallConfirmed(call)) return;
      _lastCallDiagnostic =
          'The call answer was requested, but the SIP dialog was not confirmed. '
          'No confirmed 200 OK/ACK exchange was observed before the timeout.';
      _setEvent('Call answer was not confirmed');
      _debug('call.answer.confirmation_timeout', {
        ..._callDebugData(call),
        'hasRemoteStream': _activeCallHasRemoteStream,
      });
      if (!_activeCallHasRemoteStream) {
        _guardTerminatedCall(call);
        call.hangup({'status_code': 408, 'reason_phrase': 'ACK Timeout'});
        _clearActiveCall(CallStateEnum.FAILED);
      }
      notifyListeners();
    });
  }

  void _cancelAnswerConfirmationTimer() {
    _answerConfirmationTimer?.cancel();
    _answerConfirmationTimer = null;
  }

  void _markCallConfirmed(Call call) {
    final id = _callGuardId(call);
    if (id == null) return;
    _confirmedCallIds.add(id);
  }

  void _forgetCallConfirmed(Call? call) {
    final id = call == null ? null : _callGuardId(call);
    if (id == null) return;
    _confirmedCallIds.remove(id);
  }

  bool _isCallConfirmed(Call? call) {
    final id = call == null ? null : _callGuardId(call);
    return id != null && _confirmedCallIds.contains(id);
  }

  void _markAnswerRequested(Call call) {
    final id = _callGuardId(call);
    if (id == null) return;
    _answerRequestedCallIds.add(id);
  }

  void _forgetAnswerRequested(Call? call) {
    final id = call == null ? null : _callGuardId(call);
    if (id == null) return;
    _answerRequestedCallIds.remove(id);
  }

  bool _isAnswerRequested(Call? call) {
    final id = call == null ? null : _callGuardId(call);
    return id != null && _answerRequestedCallIds.contains(id);
  }

  void _startRingtone() {
    _ringtone.start();
  }

  void _stopRingtone() {
    _ringtone.stop();
  }

  void _startRingback() {
    _ringtone.start();
  }

  void _stopRingback() {
    _ringtone.stop();
  }

  void _attachRemoteStream(MediaStream stream) {
    _debug('media.remote_stream.attach.request', {
      'tracks': stream.getTracks().map((track) => track.kind).join(','),
    });
    _remoteAudioReady
        .then((_) {
          _remoteAudio.srcObject = stream;
          _remoteAudio.setVolume(1);
          _debug('media.remote_stream.attach.success', {
            'srcObject': _remoteAudio.srcObject != null,
          });
        })
        .catchError((Object error) {
          _debug('media.remote_stream.attach.error', {
            'error': error.toString(),
          });
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
    _debug('ui.event', {'event': event});
  }

  String _callDiagnosticFromState(CallState state) {
    final cause = state.cause;
    final parts = <String>[
      if (cause?.status_code != null) 'SIP ${cause!.status_code}',
      if (cause?.reason_phrase != null &&
          cause!.reason_phrase!.trim().isNotEmpty)
        cause.reason_phrase!.trim(),
      if (cause?.cause != null && cause!.cause!.trim().isNotEmpty)
        cause.cause!.trim(),
    ];
    return parts.join(' · ');
  }

  void setDebugLoggingEnabled(bool enabled) {
    if (_debugLoggingEnabled == enabled) return;
    _debugLoggingEnabled = enabled;
    _debug(enabled ? 'debug.enabled' : 'debug.disabled', {
      'account': _account?.name,
      'registrationStatus': _registrationStatus.name,
      'transportState': _transportState.name,
      'callState': _callState.name,
    }, force: true);
    notifyListeners();
  }

  void clearDebugLog() {
    _debugEvents.clear();
    _debug('debug.cleared', const <String, Object?>{}, force: true);
    notifyListeners();
  }

  String debugLogText({List<WebRtcAccount> accounts = const []}) {
    final account = _account;
    final accountLines = accounts.isEmpty
        ? <String>['- no saved accounts reported by UI']
        : accounts.map((savedAccount) {
            final isRuntimeAccount =
                account != null &&
                _accountKey(savedAccount) == _accountKey(account);
            final diagnostic = savedAccount.diagnostic?.summary ?? '-';
            return [
              '- ${savedAccount.name.isEmpty ? savedAccount.username : savedAccount.name}',
              'id=${savedAccount.id}',
              'sip=${savedAccount.username}@${savedAccount.domain}',
              'wss=${savedAccount.wssServer}',
              'enabled=${savedAccount.enabled}',
              'autoRegister=${savedAccount.autoRegister}',
              'status=${savedAccount.status.name}',
              'activeRuntime=${isRuntimeAccount ? 'yes' : 'no'}',
              'diagnostic=$diagnostic',
            ].join(' ');
          }).toList();
    final header = <String>[
      'MNSCloud PhoneWeb debug log',
      'Generated at: ${DateTime.now().toIso8601String()}',
      'Debug enabled: $_debugLoggingEnabled',
      'Saved accounts: ${accounts.length}',
      'Active runtime account: ${account?.name ?? '-'}',
      'Account: ${account?.name ?? '-'}',
      'SIP user: ${account == null ? '-' : '${account.username}@${account.domain}'}',
      'WSS: ${account?.wssServer ?? '-'}',
      'Registration status: ${_registrationStatus.name}',
      'Registration diagnostic: ${_registrationDiagnostic?.copyText ?? '-'}',
      'Transport state: ${_transportState.name}',
      'Call state: ${_callState.name}',
      'Active call: ${_activeCall == null ? 'no' : 'yes'}',
      'Remote identity: $remoteIdentity',
      'Last event: $_lastEvent',
      'Last call diagnostic: ${_lastCallDiagnostic.isEmpty ? '-' : _lastCallDiagnostic}',
      '---- saved accounts ----',
      ...accountLines,
      '---- events ----',
    ];
    return [
      ...header,
      ..._debugEvents.map((event) => event.toLine()),
    ].join('\n');
  }

  void _debug(String event, Map<String, Object?> data, {bool force = false}) {
    if (!_debugLoggingEnabled && !force) return;
    _debugEvents.add(
      PhoneWebDebugEvent(
        observedAt: DateTime.now(),
        event: event,
        data: Map<String, Object?>.from(data),
      ),
    );
    if (_debugEvents.length > 600) {
      _debugEvents.removeRange(0, _debugEvents.length - 600);
    }
  }

  Map<String, Object?> _callDebugData(Call call) {
    return <String, Object?>{
      'callId': call.id,
      'direction': call.direction?.name,
      'remoteIdentity': call.remote_identity,
      'localIdentity': call.local_identity,
      'state': call.state.name,
    };
  }
}

class PhoneWebDebugEvent {
  const PhoneWebDebugEvent({
    required this.observedAt,
    required this.event,
    required this.data,
  });

  final DateTime observedAt;
  final String event;
  final Map<String, Object?> data;

  String toLine() {
    final fields = data.entries
        .where((entry) => entry.value != null)
        .map((entry) => '${entry.key}=${_safe(entry.value)}')
        .join(' ');
    return '${observedAt.toIso8601String()} $event${fields.isEmpty ? '' : ' $fields'}';
  }

  static String _safe(Object? value) {
    if (value == null) return '';
    return value.toString().replaceAll('\n', r'\n').replaceAll('\r', r'\r');
  }
}
