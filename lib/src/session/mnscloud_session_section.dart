import 'package:flutter/material.dart';

import 'mnscloud_session_api.dart';
import 'mnscloud_session_controller.dart';
import '../i18n/phoneweb_strings.dart';

/// Settings section "MNSCloud": optional sign-in with the tenant identity
/// (App e-mail, Pulse login or customer portal login). Same widget on desktop
/// dialog and mobile/PWA bottom sheet.
class MnscloudSessionSection extends StatefulWidget {
  const MnscloudSessionSection({required this.controller, super.key});

  final MnscloudSessionController controller;

  @override
  State<MnscloudSessionSection> createState() => _MnscloudSessionSectionState();
}

class _MnscloudSessionSectionState extends State<MnscloudSessionSection> {
  final _server = TextEditingController();
  final _identifier = TextEditingController();
  final _password = TextEditingController();
  String? _tenantUUID;
  bool _obscure = true;

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
    super.dispose();
  }

  Future<void> _submit() async {
    final ok = await widget.controller.signIn(
      identifier: _identifier.text,
      password: _password.text,
      server: _server.text,
      tenantUUID: _tenantUUID,
    );
    if (ok && mounted) {
      _password.clear();
      setState(() => _tenantUUID = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final controller = widget.controller;
        return SingleChildScrollView(
          child: controller.signedIn
              ? _SignedIn(controller: controller)
              : _form(context, controller),
        );
      },
    );
  }

  Widget _form(BuildContext context, MnscloudSessionController controller) {
    final colors = Theme.of(context).colorScheme;
    final working = controller.status == MnscloudSessionStatus.working;
    final tenants = controller.tenantChoices;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          tr('MNSCloud account'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 6),
        Text(
          tr(
            tr(
              'Optional. Sign in with the login you already use in MNSCloud: App e-mail, Pulse code or customer portal login. Without signing in, PhoneWeb keeps working with manual accounts from any SIP/WSS provider.',
            ),
          ),
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        if (controller.needsServer) ...[
          TextField(
            controller: _server,
            enabled: !working,
            keyboardType: TextInputType.url,
            autofillHints: const [AutofillHints.url],
            decoration: InputDecoration(
              labelText: tr('MNSCloud server'),
              hintText: 'https://empresa.exemplo.com.br',
              prefixIcon: Icon(Icons.dns_outlined),
            ),
          ),
          const SizedBox(height: 12),
        ],
        TextField(
          controller: _identifier,
          enabled: !working,
          autofillHints: const [AutofillHints.username],
          decoration: InputDecoration(
            labelText: tr('Username'),
            hintText: tr('E-mail, Pulse code or portal login'),
            prefixIcon: Icon(Icons.person_outline),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _password,
          enabled: !working,
          obscureText: _obscure,
          autofillHints: const [AutofillHints.password],
          onSubmitted: (_) => working ? null : _submit(),
          decoration: InputDecoration(
            labelText: tr('Password'),
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              tooltip: _obscure ? tr('Show password') : tr('Hide password'),
              icon: Icon(
                _obscure
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
        ),
        if (tenants.isNotEmpty) ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _tenantUUID,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: tr('Company'),
              prefixIcon: Icon(Icons.business_outlined),
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
        if (controller.errorMessage != null) ...[
          const SizedBox(height: 12),
          Text(controller.errorMessage!, style: TextStyle(color: colors.error)),
        ],
        const SizedBox(height: 16),
        SizedBox(
          height: 48,
          child: FilledButton.icon(
            onPressed: working ? null : _submit,
            icon: working
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.login),
            label: Text(tr('Sign in')),
          ),
        ),
      ],
    );
  }
}

class _SignedIn extends StatelessWidget {
  const _SignedIn({required this.controller});

  final MnscloudSessionController controller;

  static Map<String, String> get _realms => {
    'user': tr('App MNSCloud member'),
    'employee': tr('Employee (Pulse login)'),
    'customer_user': tr('Customer (portal login)'),
  };

  @override
  Widget build(BuildContext context) {
    final session = controller.session!;
    final colors = Theme.of(context).colorScheme;
    final expires = session.expiresAt?.toLocal();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            backgroundColor: colors.primaryContainer,
            child: Icon(
              Icons.verified_user_outlined,
              color: colors.onPrimaryContainer,
            ),
          ),
          title: Text(session.displayName ?? tr('Connected')),
          subtitle: Text(_realms[session.realm] ?? session.realm),
        ),
        const SizedBox(height: 12),
        _LinesBlock(controller: controller),
        if (expires != null) ...[
          const SizedBox(height: 8),
          Text(
            tr('Session valid until {date}', {
              'date':
                  '${expires.year}-${_two(expires.month)}-${_two(expires.day)} '
                  '${_two(expires.hour)}:${_two(expires.minute)}',
            }),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: 16),
        SizedBox(
          height: 48,
          child: OutlinedButton.icon(
            onPressed: controller.status == MnscloudSessionStatus.working
                ? null
                : controller.signOut,
            icon: const Icon(Icons.logout),
            label: Text(tr('Sign out')),
          ),
        ),
      ],
    );
  }

  static String _two(int value) => value.toString().padLeft(2, '0');
}

class _LinesBlock extends StatelessWidget {
  const _LinesBlock({required this.controller});

  final MnscloudSessionController controller;

  String _source(MnscloudLine line) {
    if (line.claimed) return tr('Free extension (reserved)');
    final kind = line.mode == 'shared' ? tr('Shared') : tr('Dedicated');
    return line.primary ? tr('{kind} · main', {'kind': kind}) : kind;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(tr('My lines'), style: text.titleSmall)),
            IconButton(
              tooltip: tr('Refresh lines'),
              onPressed: controller.linesLoading
                  ? null
                  : controller.refreshLines,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        if (controller.linesLoading) const LinearProgressIndicator(),
        if (controller.lines.isEmpty && !controller.linesLoading)
          Text(
            tr(
              'No line assigned. Take a free extension below or ask the administrator.',
            ),
            style: text.bodySmall?.copyWith(color: colors.onSurfaceVariant),
          ),
        for (final line in controller.lines)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              line.webrtcReady
                  ? Icons.phone_in_talk_outlined
                  : Icons.phone_disabled_outlined,
              color: line.webrtcReady ? colors.primary : colors.error,
            ),
            title: Text(
              line.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              line.webrtcReady
                  ? _source(line)
                  : tr('{source} · no WebRTC access', {
                      'source': _source(line),
                    }),
              maxLines: 2,
            ),
            trailing: line.claimed
                ? TextButton(
                    onPressed: () => controller.releaseLine(line.lineKey),
                    child: Text(tr('Release')),
                  )
                : null,
          ),
        if (controller.availableLines.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(tr('Free extensions'), style: text.titleSmall),
          for (final free in controller.availableLines)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_seat_outlined),
              title: Text(
                free.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: free.notes == null
                  ? null
                  : Text(free.notes!, maxLines: 1),
              trailing: FilledButton.tonal(
                onPressed: () => controller.claimLine(free.poolUUID),
                child: Text(tr('Take')),
              ),
            ),
        ],
        if (controller.linesError != null) ...[
          const SizedBox(height: 8),
          Text(controller.linesError!, style: TextStyle(color: colors.error)),
        ],
      ],
    );
  }
}
