import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../brand/brand.dart';
import '../session/mnscloud_session_api.dart';
import '../session/mnscloud_session_controller.dart';
import 'access_preferences.dart';
import 'access_strings.dart';
import '../pwa/install_app_button.dart';

const _defaultBrandColor = Color(0xff1264ed);

/// Web sign-in of PhoneWeb with the same layout as Pulse and POS: brand panel
/// beside the form (or compact, per Settings › Themes › Login do PhoneWeb),
/// any MNSCloud login (App e-mail, Pulse code, customer portal login) and
/// "continue without an account" for manual SIP/WSS accounts.
class PhoneWebAccessScreen extends StatelessWidget {
  const PhoneWebAccessScreen({
    required this.controller,
    required this.onContinueWithout,
    super.key,
  });

  final MnscloudSessionController controller;
  final VoidCallback onContinueWithout;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale?>(
      valueListenable: accessLocale,
      builder: (context, _, _) => ValueListenableBuilder<Brand?>(
        valueListenable: phonewebBrand,
        builder: (context, brand, _) {
          final color = brand?.primaryColor ?? _defaultBrandColor;
          final base = Theme.of(context);
          final dark = switch (brand?.login['appearance']) {
            'light' => false,
            'dark' => true,
            _ => base.brightness == Brightness.dark,
          };
          final scheme = ColorScheme.fromSeed(
            seedColor: color,
            brightness: dark ? Brightness.dark : Brightness.light,
          );
          return Theme(
            data: ThemeData(
              colorScheme: scheme,
              useMaterial3: true,
              inputDecorationTheme: InputDecorationTheme(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(9),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 18,
                ),
              ),
              filledButtonTheme: FilledButtonThemeData(
                style: FilledButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: color.computeLuminance() > .179
                      ? Colors.black
                      : Colors.white,
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9),
                  ),
                ),
              ),
              outlinedButtonTheme: OutlinedButtonThemeData(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9),
                  ),
                ),
              ),
            ),
            child: _AccessShell(
              brand: brand,
              child: _AccessForm(
                controller: controller,
                onContinueWithout: onContinueWithout,
              ),
            ),
          );
        },
      ),
    );
  }
}

Future<void> _openLink(BuildContext context, String url) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final error = AccessStrings.current().t('linkError');
  try {
    final opened = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
      webOnlyWindowName: '_blank',
    );
    if (!opened) messenger?.showSnackBar(SnackBar(content: Text(error)));
  } catch (_) {
    messenger?.showSnackBar(SnackBar(content: Text(error)));
  }
}

class _AccessForm extends StatefulWidget {
  const _AccessForm({
    required this.controller,
    required this.onContinueWithout,
  });

  final MnscloudSessionController controller;
  final VoidCallback onContinueWithout;

  @override
  State<_AccessForm> createState() => _AccessFormState();
}

class _AccessFormState extends State<_AccessForm> {
  final _form = GlobalKey<FormState>();
  final _server = TextEditingController();
  final _identifier = TextEditingController();
  final _password = TextEditingController();
  final _passwordFocus = FocusNode();
  bool _showPassword = false;
  String? _tenantUUID;

  @override
  void initState() {
    super.initState();
    _server.text = widget.controller.server?.toString() ?? '';
  }

  @override
  void dispose() {
    _server.dispose();
    _identifier.dispose();
    _password.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    final ok = await widget.controller.signIn(
      identifier: _identifier.text,
      password: _password.text,
      server: _server.text,
      tenantUUID: _tenantUUID,
    );
    if (ok) {
      await writeAccessSkipped(false);
    } else if (mounted) {
      setState(() {});
    }
  }

  /// App accounts recover the password on the App page of the same server;
  /// Pulse and customer portal logins are reset by the company.
  Future<void> _forgotPassword(AccessStrings s) {
    final server = widget.controller.server;
    final recovery = server?.resolve('/auth/forgot-password').toString();
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(s.t('forgotTitle')),
        content: Text(s.t('forgotHelp')),
        actions: [
          if (recovery != null)
            TextButton(
              key: const Key('appRecovery'),
              onPressed: () => _openLink(dialogContext, recovery),
              child: Text(s.t('appRecovery')),
            ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(s.t('close')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AccessStrings.current();
    final scheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final controller = widget.controller;
        final working = controller.status == MnscloudSessionStatus.working;
        final tenants = controller.tenantChoices;
        String? required(String? value) =>
            value == null || value.trim().isEmpty ? s.t('required') : null;
        return Form(
          key: _form,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  s.text('eyebrow').toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w700,
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  s.text('title'),
                  style: const TextStyle(
                    fontSize: 34,
                    height: 1.15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  s.text('subtitle'),
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.6,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 32),
                if (controller.errorMessage != null) ...[
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      controller.errorMessage!,
                      style: TextStyle(color: scheme.error),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                if (controller.needsServer) ...[
                  TextFormField(
                    key: const Key('accessServer'),
                    controller: _server,
                    enabled: !working,
                    keyboardType: TextInputType.url,
                    autofillHints: const [AutofillHints.url],
                    decoration: InputDecoration(labelText: s.t('server')),
                    validator: required,
                  ),
                  const SizedBox(height: 20),
                ],
                TextFormField(
                  key: const Key('accessUser'),
                  controller: _identifier,
                  enabled: !working,
                  decoration: InputDecoration(labelText: s.t('user')),
                  autofillHints: const [AutofillHints.username],
                  textInputAction: TextInputAction.next,
                  autocorrect: false,
                  validator: required,
                  onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  key: const Key('accessPassword'),
                  controller: _password,
                  focusNode: _passwordFocus,
                  enabled: !working,
                  decoration: InputDecoration(
                    labelText: s.t('password'),
                    suffixIcon: IconButton(
                      key: const Key('togglePassword'),
                      tooltip: _showPassword
                          ? s.t('hidePassword')
                          : s.t('showPassword'),
                      onPressed: () =>
                          setState(() => _showPassword = !_showPassword),
                      icon: Icon(
                        _showPassword ? Icons.visibility_off : Icons.visibility,
                      ),
                    ),
                  ),
                  obscureText: !_showPassword,
                  autofillHints: const [AutofillHints.password],
                  enableSuggestions: false,
                  autocorrect: false,
                  validator: (value) =>
                      value == null || value.isEmpty ? s.t('required') : null,
                  onFieldSubmitted: (_) => working ? null : _submit(),
                ),
                if (tenants.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    key: const Key('accessCompany'),
                    initialValue: _tenantUUID,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: s.t('company'),
                      helperText: s.t('chooseCompany'),
                    ),
                    items: [
                      for (final MnscloudTenantChoice tenant in tenants)
                        DropdownMenuItem(
                          value: tenant.uuid,
                          child: Text(
                            tenant.name.isEmpty ? tenant.uuid : tenant.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: working
                        ? null
                        : (value) => setState(() => _tenantUUID = value),
                  ),
                ],
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    key: const Key('forgotPassword'),
                    onPressed: () => _forgotPassword(s),
                    child: Text(s.t('forgotPassword')),
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  key: const Key('accessSignIn'),
                  onPressed: working ? null : _submit,
                  child: working
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(s.t('signIn')),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  key: const Key('continueWithout'),
                  onPressed: working ? null : widget.onContinueWithout,
                  child: Text(s.t('continueWithout')),
                ),
                const SizedBox(height: 10),
                Text(
                  s.t('continueWithoutHint'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AccessLanguageButton extends StatelessWidget {
  const _AccessLanguageButton();

  static const _names = {
    'pt': 'Português (BR)',
    'en': 'English (US)',
    'es': 'Español (ES)',
  };

  @override
  Widget build(BuildContext context) {
    final s = AccessStrings.current();
    return PopupMenuButton<String>(
      key: const Key('accessLanguage'),
      tooltip: s.t('language'),
      initialValue: accessLocale.value?.toLanguageTag() ?? 'auto',
      onSelected: setAccessLocale,
      itemBuilder: (_) => [
        PopupMenuItem(value: 'auto', child: Text(s.t('system'))),
        const PopupMenuItem(value: 'pt-BR', child: Text('Português (BR)')),
        const PopupMenuItem(value: 'en-US', child: Text('English (US)')),
        const PopupMenuItem(value: 'es-ES', child: Text('Español (ES)')),
      ],
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.language, size: 19),
            const SizedBox(width: 8),
            Text(_names[s.lang]!),
            const Icon(Icons.expand_more, size: 18),
          ],
        ),
      ),
    );
  }
}

class _AccessBrand extends StatelessWidget {
  const _AccessBrand({required this.brand, this.onDark = false});

  final Brand? brand;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final color = brand?.primaryColor ?? _defaultBrandColor;
    final mark = Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'M',
        style: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w900,
          color: color.computeLuminance() > .179 ? Colors.black : Colors.white,
        ),
      ),
    );
    final logo = brand?.logoUrl;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (logo != null)
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 120, maxHeight: 48),
            child: Image.network(
              logo,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => mark,
            ),
          )
        else
          mark,
        const SizedBox(width: 14),
        Flexible(
          child: Text(
            brand?.title ?? 'MNSCloud PhoneWeb',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: onDark ? Colors.white : null,
            ),
          ),
        ),
      ],
    );
  }
}

class _AccessShell extends StatelessWidget {
  const _AccessShell({required this.brand, required this.child});

  final Brand? brand;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final s = AccessStrings.current();
    final color = brand?.primaryColor ?? _defaultBrandColor;
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final split =
                constraints.maxWidth >= 900 &&
                brand?.login['layout'] != 'compact';
            final main = SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: EdgeInsets.all(split ? 40 : 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 16,
                        runSpacing: 12,
                        children: [
                          if (!split)
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 270),
                              child: _AccessBrand(brand: brand),
                            ),
                          const _AccessLanguageButton(),
                          const InstallAppButton(labeled: true),
                        ],
                      ),
                      SizedBox(height: split ? 76 : 48),
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 460),
                          child: child,
                        ),
                      ),
                      const SizedBox(height: 36),
                      _footer(context, s),
                    ],
                  ),
                ),
              ),
            );
            if (!split) return main;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xff071a37),
                          Color.lerp(const Color(0xff06142b), color, .35)!,
                        ],
                      ),
                    ),
                    child: Stack(
                      children: [
                        if (Brand.safeLink(brand?.login['heroImageUrl'])
                            case final String image)
                          Positioned.fill(
                            child: Opacity(
                              opacity: .16,
                              child: Image.network(
                                image,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) =>
                                    const SizedBox.shrink(),
                              ),
                            ),
                          ),
                        const Positioned.fill(
                          child: CustomPaint(painter: _Orbits()),
                        ),
                        SingleChildScrollView(
                          padding: const EdgeInsets.all(56),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _AccessBrand(brand: brand, onDark: true),
                              const SizedBox(height: 110),
                              Text(
                                s.text('eyebrow').toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  letterSpacing: 2,
                                ),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                s.text('heroTitle'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 52,
                                  fontWeight: FontWeight.w800,
                                  height: 1.12,
                                  letterSpacing: -2,
                                ),
                              ),
                              const SizedBox(height: 28),
                              Text(
                                s.text('heroText'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 19,
                                  height: 1.6,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(child: main),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _footer(BuildContext context, AccessStrings s) {
    final login = brand?.login ?? const {};
    Widget? link(String key, String label) {
      final url = Brand.safeLink(login[key]);
      return url == null
          ? null
          : TextButton(
              onPressed: () => _openLink(context, url),
              child: Text(label, textAlign: TextAlign.center),
            );
    }

    return Column(
      children: [
        if (link('supportUrl', s.text('supportLabel'))
            case final Widget support)
          support,
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          children: [
            if (link('privacyUrl', s.t('privacy')) case final Widget privacy)
              privacy,
            if (link('termsUrl', s.t('terms')) case final Widget terms) terms,
          ],
        ),
      ],
    );
  }
}

class _Orbits extends CustomPainter {
  const _Orbits();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: .12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final scale in [1.0, 1.3, 1.6]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(size.width * .2, size.height * 1.2),
          width: size.width * 1.7 * scale,
          height: size.height * .8 * scale,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
