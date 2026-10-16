import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'app_build_info.dart';
import 'runtime_version.dart';
import 'runtime_version_fetcher_stub.dart'
    if (dart.library.js_interop) 'runtime_version_fetcher_web.dart'
    as platform;

typedef DeployedVersionReader = Future<RuntimeReleaseInfo?> Function();

/// Detects that a newer PhoneWeb release went live while the app stays open.
///
/// It reads the release `build.json` on start, every ~5 minutes while the page
/// is visible and when the page becomes visible again, and accepts a different
/// version only after two reads agree [confirmDelay] apart. It never reloads by
/// itself: the UI shows a calm notice and the user updates when convenient.
class AppUpdateController extends ChangeNotifier {
  AppUpdateController({
    DeployedVersionReader? reader,
    String? runningVersion,
    DateTime Function()? clock,
  }) : _reader =
           reader ??
           (() => platform.fetchLatestRuntimeRelease(appBuildInfo.product)),
       runningVersion = normalizeVersion(
         runningVersion ?? appBuildInfo.version,
       ),
       _clock = clock ?? DateTime.now;

  static const pollInterval = Duration(minutes: 5);
  static const minCheckGap = Duration(minutes: 1);
  static const confirmDelay = Duration(seconds: 45);
  static const snoozeDuration = Duration(hours: 4);
  static const _snoozeKey = 'mnscloud_phoneweb_update_snooze';

  final DeployedVersionReader _reader;
  final DateTime Function() _clock;
  final String runningVersion;

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

  bool get noticeVisible {
    if (!updateAvailable) return false;
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

  /// Starts background detection on the web build only (native builds update
  /// through their store).
  void start() {
    if (_started || !kIsWeb) return;
    _started = true;
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

  /// Feeds one `build.json` read into the confirmation state.
  @visibleForTesting
  void observe(RuntimeReleaseInfo build, DateTime at) {
    final version = normalizeVersion(build.version);
    if (version.isEmpty) return;
    final current = _deployed;
    if (version == (current?.version ?? runningVersion)) {
      _candidate = null;
      _confirmTimer?.cancel();
      if (current == null) {
        _deployed = RuntimeReleaseInfo(
          version: version,
          buildRef: build.buildRef,
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
    _pollTimer?.cancel();
    _confirmTimer?.cancel();
    super.dispose();
  }
}
