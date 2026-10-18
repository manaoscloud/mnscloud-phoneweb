import 'package:flutter/material.dart';

import 'mnscloud_session_api.dart';
import 'mnscloud_session_controller.dart';

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
        Text('Conta MNSCloud', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        Text(
          'Opcional. Entre com o login que você já usa na MNSCloud: e-mail do App, '
          'código do Pulse ou login do portal do cliente. Sem entrar, o PhoneWeb '
          'continua funcionando com contas manuais de qualquer provedor SIP/WSS.',
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
            decoration: const InputDecoration(
              labelText: 'Servidor MNSCloud',
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
          decoration: const InputDecoration(
            labelText: 'Usuário',
            hintText: 'E-mail, código do Pulse ou login do portal',
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
            labelText: 'Senha',
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              tooltip: _obscure ? 'Mostrar senha' : 'Ocultar senha',
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
            decoration: const InputDecoration(
              labelText: 'Empresa',
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
            label: const Text('Entrar'),
          ),
        ),
      ],
    );
  }
}

class _SignedIn extends StatelessWidget {
  const _SignedIn({required this.controller});

  final MnscloudSessionController controller;

  static const _realms = {
    'user': 'Membro do App MNSCloud',
    'employee': 'Funcionário (login do Pulse)',
    'customer_user': 'Cliente (login do portal)',
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
          title: Text(session.displayName ?? 'Conectado'),
          subtitle: Text(_realms[session.realm] ?? session.realm),
        ),
        const SizedBox(height: 8),
        Text(
          'Conectado à MNSCloud. As linhas que sua empresa atribuir a você aparecerão aqui.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
        ),
        if (expires != null) ...[
          const SizedBox(height: 8),
          Text(
            'Sessão válida até ${expires.year}-${_two(expires.month)}-${_two(expires.day)} '
            '${_two(expires.hour)}:${_two(expires.minute)}',
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
            label: const Text('Sair'),
          ),
        ),
      ],
    );
  }

  static String _two(int value) => value.toString().padLeft(2, '0');
}
