import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../i18n/phoneweb_strings.dart';
import 'pwa.dart';

/// "Install app" for the web PhoneWeb: opens the browser prompt (Chrome, Edge, Android) or shows
/// the Add to Home Screen steps (iPhone/iPad). Hidden when installed, unsupported, native or
/// embedded in the App phone dock (`?embed=app`).
class InstallAppButton extends StatefulWidget {
  const InstallAppButton({super.key, this.labeled = false});

  /// Outlined button with the label (headers with room) instead of an icon.
  final bool labeled;

  @override
  State<InstallAppButton> createState() => _InstallAppButtonState();
}

class _InstallAppButtonState extends State<InstallAppButton> {
  PwaInstallState _state = pwaInstallState();

  static final bool _embedded = kIsWeb && Uri.base.queryParameters['embed'] == 'app';

  @override
  void initState() {
    super.initState();
    pwaOnInstallChange(() {
      if (mounted) setState(() => _state = pwaInstallState());
    });
  }

  Future<void> _install() async {
    if (_state == PwaInstallState.ios) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.ios_share),
          title: Text(tr('Install app')),
          content: Text(tr('In Safari, tap Share and then "Add to Home Screen".')),
          actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(tr('Close')))],
        ),
      );
      return;
    }
    await pwaPromptInstall();
    if (mounted) setState(() => _state = pwaInstallState());
  }

  @override
  Widget build(BuildContext context) {
    if (_embedded || (_state != PwaInstallState.available && _state != PwaInstallState.ios)) {
      return const SizedBox.shrink();
    }
    if (widget.labeled) {
      return OutlinedButton.icon(
        key: const Key('installApp'),
        // The app theme stretches outlined buttons to the full width; this one sits in headers.
        style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
        icon: const Icon(Icons.install_desktop),
        label: Text(tr('Install app')),
        onPressed: _install,
      );
    }
    return IconButton(
      key: const Key('installApp'),
      tooltip: tr('Install app'),
      icon: const Icon(Icons.install_desktop),
      onPressed: _install,
    );
  }
}
