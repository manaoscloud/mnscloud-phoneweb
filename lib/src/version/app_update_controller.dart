import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'app_build_info.dart';
import 'client_identity.dart';
import 'client_policy.dart';
import 'runtime_version.dart';
import 'runtime_version_fetcher_stub.dart'
    if (dart.library.js_interop) 'runtime_version_fetcher_web.dart'
    as platform;

typedef DeployedVersionReader = Future<RuntimeReleaseInfo?> Function();
typedef ClientPolicyReader = Future<ClientVersionPolicy?> Function(Uri apiRoot);

/// Detects that a newer PhoneWeb release went live while the app stays open.
///
/// It reads the release `build.json` on start, every ~5 minutes while the page
/// is visible and when the page becomes visible again, and accepts a different
/// version only after two reads agree [confirmDelay] apart. It never reloads by
/// itself: the UI shows a calm notice and the user updates when convenient.
///
/// Installed apps (not web) instead read the API version policy of PhoneWeb
/// (`/public/clients/phoneweb/policy`) of the selected MNSCloud server on
/// start, every [policyInterval] and on return to foreground. Only a running
/// version below the minimum of its platform, or an API 426
/// `CLIENT_VERSION_UNSUPPORTED`, shows a notice, always critical. A failed
/// read or a missing minimum shows nothing (fail open).
class AppUpdateController extends ChangeNotifier {
  AppUpdateController({
    DeployedVersionReader? reader,
    String? runningVersion,
    DateTime Function()? clock,
    Uri? Function()? apiRoot,
    ClientPolicyReader? policyReader,
    ValueNotifier<bool>? unsupported,
    @visibleForTesting bool? web,
    @visibleForTesting String? clientPlatform,
  }) : _reader =
           reader ??
           (() => platform.fetchLatestRuntimeRelease(appBuildInfo.product)),
       runningVersion = normalizeVersion(
         runningVersion ?? appBuildInfo.version,
       ),
       _clock = clock ?? DateTime.now,
       _apiRoot = apiRoot ?? (() => null),
       _policyReader = policyReader ?? fetchClientVersionPolicy,
       _unsupported = unsupported ?? clientVersionUnsupported,
       isWeb = web ?? kIsWeb,
       _clientPlatform = clientPlatform ?? mnscloudClientPlatform {
    if (!isWeb) _unsupported.addListener(_onUnsupported);
  }

  static const pollInterval = Duration(minutes: 5);
  static const minCheckGap = Duration(minutes: 1);
  static const confirmDelay = Duration(seconds: 45);
  static const snoozeDuration = Duration(hours: 4);
  static const policyInterval = Duration(hours: 6);
  static const _snoozeKey = 'mnscloud_phoneweb_update_snooze';

  final DeployedVersionReader _reader;
  final DateTime Function() _clock;
  final String runningVersion;
  final Uri? Function() _apiRoot;
  final ClientPolicyReader _policyReader;
  final ValueNotifier<bool> _unsupported;
  final String _clientPlatform;

  /// Web build (release `build.json`) instead of an installed app (API policy).
  final bool isWeb;

  String? _policyMinimum;
  Uri? _policyRoot;
  AppLifecycleListener? _lifecycle;

  RuntimeReleaseInfo? _deployed;
  ({String version, DateTime seenAt})? _candidate;
  ({String version, DateTime until})? _snooze;
  DateTime? _lastCheckAt;
  Future<void>? _inFlight;
  Timer? _pollTimer;
  Timer? _confirmTimer;
  bool _started = false;
  bool _disposed = false;

  RuntimeReleaseInfo? get deployed => _deployed;

  bool get updateAvailable {
    final version = _deployed?.version;
    return version != null && version != runningVersion;
  }

  /// The running bundle is below the release `minimumVersion`: the notice
  /// cannot be postponed (it still never reloads by itself). Installed apps:
  /// below the API minimum of their platform, or rejected with 426.
  bool get critical {
    if (!isWeb) {
      final minimum = _policyMinimum;
      return _unsupported.value ||
          (minimum != null && compareSemver(runningVersion, minimum) < 0);
    }
    final minimum = _deployed?.minimumVersion;
    return minimum != null &&
        updateAvailable &&
        compareSemver(runningVersion, minimum) < 0;
  }

  bool get noticeVisible {
    if (!isWeb) return critical;
    if (!updateAvailable) return false;
    if (critical) return true;
    final snooze = _snooze;
    return snooze == null ||
        snooze.version != _deployed!.version ||
        !snooze.until.isAfter(_clock());
  }

  /// Version info for the settings badge (running bundle vs installed release).
  RuntimeVersionInfo get versionInfo => currentRuntimeVersionInfo(
    latestVersion: _deployed?.version,
    latestBuildRef: _deployed?.buildRef,
  );

  /// Starts background detection: the release `build.json` on the web build,
  /// the API version policy on installed apps (they update through their store).
  void start() {
    if (_started) return;
    _started = true;
    if (!isWeb) {
      _lifecycle = AppLifecycleListener(
        onResume: () => unawaited(check(force: true)),
      );
      _pollTimer = Timer.periodic(
        policyInterval,
        (_) => unawaited(check(force: true)),
      );
      unawaited(check(force: true));
      return;
    }
    _snooze = _readSnooze();
    platform.listenPageVisible(() => unawaited(check()));
    _schedulePoll();
    unawaited(check(force: true));
  }

  Future<void> check({bool force = false}) {
    final pending = _inFlight;
    if (pending != null) return pending;
    final now = _clock();
    final last = _lastCheckAt;
    if (!isWeb) {
      // Installed apps: start, every 6 h, foreground, or a new server only.
      final root = _apiRoot();
      if (!force && root == _policyRoot) return Future.value();
      _lastCheckAt = now;
      return _checkPolicy(root);
    }
    if (!force && last != null && now.difference(last) < minCheckGap) {
      return Future.value();
    }
    _lastCheckAt = now;
    final future = _reader()
        .then((build) {
          if (build?.version != null && !_disposed) observe(build!, _clock());
        })
        .catchError((Object _) {})
        .whenComplete(() => _inFlight = null);
    _inFlight = future;
    return future;
  }

  /// Installed apps: reads the policy of the selected server. No server, a
  /// failed read or no minimum for this platform shows nothing (fail open).
  Future<void> _checkPolicy(Uri? root) {
    if (root != _policyRoot) {
      _policyRoot = root;
      if (_policyMinimum != null) {
        _policyMinimum = null;
        notifyListeners();
      }
    }
    if (root == null) return Future.value();
    final future = _policyReader(root)
        .then((policy) {
          if (_disposed || policy == null || root != _policyRoot) return;
          final minimum = policy.minimum[_clientPlatform];
          if (minimum == _policyMinimum) return;
          _policyMinimum = minimum;
          notifyListeners();
        })
        .catchError((Object _) {})
        .whenComplete(() => _inFlight = null);
    _inFlight = future;
    return future;
  }

  void _onUnsupported() {
    if (!_disposed) notifyListeners();
  }

  /// Feeds one `build.json` read into the confirmation state.
  @visibleForTesting
  void observe(RuntimeReleaseInfo build, DateTime at) {
    final version = normalizeVersion(build.version);
    if (version.isEmpty) return;
    final current = _deployed;
    if (version == (current?.version ?? runningVersion)) {
      _candidate = null;
      _confirmTimer?.cancel();
      if (current == null || current.minimumVersion != build.minimumVersion) {
        _deployed = RuntimeReleaseInfo(
          version: version,
          buildRef: build.buildRef,
          minimumVersion: build.minimumVersion,
        );
        notifyListeners();
      }
      return;
    }
    final candidate = _candidate;
    if (candidate != null && candidate.version == version) {
      if (at.difference(candidate.seenAt) >= confirmDelay) {
        _candidate = null;
        _confirmTimer?.cancel();
        _deployed = RuntimeReleaseInfo(
          version: version,
          buildRef: build.buildRef,
          minimumVersion: build.minimumVersion,
        );
        notifyListeners();
      }
      return;
    }
    _candidate = (version: version, seenAt: at);
    _confirmTimer?.cancel();
    if (_started) {
      _confirmTimer = Timer(confirmDelay, () => unawaited(check(force: true)));
    }
  }

  /// "Later": hide the notice for this version for a few hours.
  void postpone() {
    final version = _deployed?.version;
    if (version == null) return;
    _snooze = (version: version, until: _clock().add(snoozeDuration));
    platform.writeUpdateSnooze(
      _snoozeKey,
      jsonEncode({
        'version': version,
        'until': _snooze!.until.millisecondsSinceEpoch,
      }),
    );
    notifyListeners();
  }

  void reloadNow() => platform.reloadPage();

  void _schedulePoll() {
    final jitter = Duration(seconds: Random().nextInt(60) - 30);
    _pollTimer = Timer(pollInterval + jitter, () {
      if (platform.isPageVisible()) unawaited(check());
      if (!_disposed) _schedulePoll();
    });
  }

  ({String version, DateTime until})? _readSnooze() {
    try {
      final raw = platform.readUpdateSnooze(_snoozeKey);
      if (raw == null) return null;
      final value = jsonDecode(raw);
      if (value is! Map) return null;
      final version = value['version'];
      final until = value['until'];
      if (version is! String || until is! int) return null;
      return (
        version: version,
        until: DateTime.fromMillisecondsSinceEpoch(until),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _unsupported.removeListener(_onUnsupported);
    _lifecycle?.dispose();
    _pollTimer?.cancel();
    _confirmTimer?.cancel();
    super.dispose();
  }
}
