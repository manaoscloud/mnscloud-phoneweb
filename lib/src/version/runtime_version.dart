import 'app_build_info.dart';
import 'runtime_version_fetcher_stub.dart'
    if (dart.library.js_interop) 'runtime_version_fetcher_web.dart';

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

  bool get updateAvailable {
    final latest = latestVersion?.trim();
    if (latest == null || latest.isEmpty) return false;
    return compareSemver(latest, version) > 0;
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

Future<RuntimeVersionInfo> loadRuntimeVersionInfo() async {
  final latest = await fetchLatestRuntimeRelease(appBuildInfo.product);
  return currentRuntimeVersionInfo(
    latestVersion: latest?.version,
    latestBuildRef: latest?.buildRef,
  );
}

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
  const RuntimeReleaseInfo({this.version, this.buildRef});

  final String? version;
  final String? buildRef;
}
