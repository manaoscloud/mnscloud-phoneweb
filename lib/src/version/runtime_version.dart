import 'app_build_info.dart';

class RuntimeVersionInfo {
  const RuntimeVersionInfo({
    required this.product,
    required this.version,
    required this.channel,
    this.latestVersion,
    this.latestBuildRef,
  });

  final String product;
  final String version;
  final String channel;
  final String? latestVersion;
  final String? latestBuildRef;

  /// The installed release differs from this bundle (newer, or a rollback).
  bool get updateAvailable {
    final latest = normalizeVersion(latestVersion);
    if (latest.isEmpty) return false;
    return latest != normalizeVersion(version);
  }

  String get displayVersion => 'v$version';
}

RuntimeVersionInfo currentRuntimeVersionInfo({
  String? latestVersion,
  String? latestBuildRef,
}) {
  return RuntimeVersionInfo(
    product: appBuildInfo.product,
    version: appBuildInfo.version,
    channel: appBuildInfo.channel,
    latestVersion: latestVersion,
    latestBuildRef: latestBuildRef,
  );
}

String normalizeVersion(String? value) =>
    (value ?? '').trim().replaceFirst(RegExp('^v', caseSensitive: false), '');

bool isReleaseVersion(String value) =>
    RegExp(r'^\d+\.\d+\.\d+([-+][0-9A-Za-z.-]+)?$').hasMatch(value);

int compareSemver(String left, String right) {
  final leftParts = _semverParts(left);
  final rightParts = _semverParts(right);
  for (var index = 0; index < 3; index += 1) {
    final diff = leftParts[index] - rightParts[index];
    if (diff != 0) return diff;
  }
  return 0;
}

List<int> _semverParts(String value) {
  final core = value
      .trim()
      .replaceFirst(RegExp('^v', caseSensitive: false), '')
      .split(RegExp(r'[+-]'))
      .first;
  final parts = core.split('.');
  return List<int>.generate(3, (index) {
    if (index >= parts.length) return 0;
    return int.tryParse(parts[index]) ?? 0;
  });
}

class RuntimeReleaseInfo {
  const RuntimeReleaseInfo({this.version, this.buildRef, this.minimumVersion});

  final String? version;
  final String? buildRef;

  /// Releases below this version must update (critical fix); null when unset.
  final String? minimumVersion;
}
