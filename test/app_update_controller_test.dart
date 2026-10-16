import 'package:flutter_test/flutter_test.dart';
import 'package:mnscloud_phoneweb/src/version/app_update_controller.dart';
import 'package:mnscloud_phoneweb/src/version/runtime_version.dart';

void main() {
  final t0 = DateTime(2026, 10, 16, 12);
  late DateTime now;
  late AppUpdateController controller;

  RuntimeReleaseInfo build(String version) =>
      RuntimeReleaseInfo(version: version);

  setUp(() {
    now = t0;
    controller = AppUpdateController(
      reader: () async => null,
      runningVersion: '0.1.58',
      clock: () => now,
    );
  });

  tearDown(() => controller.dispose());

  test('stays quiet while the installed release equals the running bundle', () {
    controller.observe(build('0.1.58'), t0);
    expect(controller.updateAvailable, isFalse);
    expect(controller.versionInfo.latestVersion, '0.1.58');
  });

  test('announces a new release only after two reads agree 45 s apart', () {
    controller.observe(build('0.1.59'), t0);
    controller.observe(build('0.1.59'), t0.add(const Duration(seconds: 44)));
    expect(controller.updateAvailable, isFalse);
    controller.observe(
      build('0.1.59'),
      t0.add(AppUpdateController.confirmDelay),
    );
    expect(controller.updateAvailable, isTrue);
    expect(controller.noticeVisible, isTrue);
    expect(controller.versionInfo.updateAvailable, isTrue);
  });

  test('"later" hides the notice for 4 h, a newer release shows it again', () {
    controller.observe(build('0.1.59'), t0);
    controller.observe(
      build('0.1.59'),
      t0.add(AppUpdateController.confirmDelay),
    );
    controller.postpone();
    expect(controller.noticeVisible, isFalse);

    now = t0.add(
      AppUpdateController.snoozeDuration + const Duration(minutes: 1),
    );
    expect(controller.noticeVisible, isTrue);

    controller.postpone();
    final later = now.add(const Duration(minutes: 5));
    controller.observe(build('0.1.60'), later);
    controller.observe(
      build('0.1.60'),
      later.add(AppUpdateController.confirmDelay),
    );
    expect(controller.noticeVisible, isTrue);
  });

  test('a rollback to the running version clears the notice', () {
    controller.observe(build('0.1.59'), t0);
    controller.observe(
      build('0.1.59'),
      t0.add(AppUpdateController.confirmDelay),
    );
    final back = t0.add(const Duration(minutes: 10));
    controller.observe(build('0.1.58'), back);
    controller.observe(
      build('v0.1.58'),
      back.add(AppUpdateController.confirmDelay),
    );
    expect(controller.updateAvailable, isFalse);
  });
}
