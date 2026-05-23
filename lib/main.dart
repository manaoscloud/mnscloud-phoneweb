import 'package:flutter/material.dart';

void main() {
  runApp(const PhoneWebApp());
}

class PhoneWebApp extends StatelessWidget {
  const PhoneWebApp({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF0F766E),
      brightness: Brightness.light,
    );

    return MaterialApp(
      title: 'MNSCloud PhoneWeb',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: colorScheme,
        scaffoldBackgroundColor: const Color(0xFFF7F8F5),
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          filled: true,
          fillColor: Colors.white,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: colorScheme.outlineVariant),
          ),
        ),
      ),
      home: const PhoneWebHomePage(),
    );
  }
}

class PhoneWebHomePage extends StatefulWidget {
  const PhoneWebHomePage({super.key});

  @override
  State<PhoneWebHomePage> createState() => _PhoneWebHomePageState();
}

class _PhoneWebHomePageState extends State<PhoneWebHomePage> {
  final List<WebRtcAccount> _accounts = [];
  String? _selectedAccountId;
  String _dialNumber = '';
  String _lastEvent = 'Ready';

  WebRtcAccount? get _selectedAccount {
    for (final account in _accounts) {
      if (account.id == _selectedAccountId) {
        return account;
      }
    }
    return _accounts.isEmpty ? null : _accounts.first;
  }

  Future<void> _openAccountDialog({WebRtcAccount? account}) async {
    final result = await showDialog<WebRtcAccount>(
      context: context,
      builder: (context) => AccountDialog(account: account),
    );

    if (result == null) {
      return;
    }

    setState(() {
      final index = _accounts.indexWhere((item) => item.id == result.id);
      if (index >= 0) {
        _accounts[index] = result;
        _lastEvent = '${result.name} updated';
      } else {
        _accounts.add(result);
        _selectedAccountId = result.id;
        _lastEvent = '${result.name} added';
      }
    });
  }

  void _removeAccount(WebRtcAccount account) {
    setState(() {
      _accounts.removeWhere((item) => item.id == account.id);
      if (_selectedAccountId == account.id) {
        _selectedAccountId = _accounts.isEmpty ? null : _accounts.first.id;
      }
      _lastEvent = '${account.name} removed';
    });
  }

  void _toggleRegistration(WebRtcAccount account) {
    setState(() {
      final index = _accounts.indexWhere((item) => item.id == account.id);
      if (index < 0) {
        return;
      }

      final nextStatus = account.status == RegistrationStatus.registered
          ? RegistrationStatus.offline
          : RegistrationStatus.registered;

      _accounts[index] = account.copyWith(
        status: nextStatus,
        enabled: nextStatus == RegistrationStatus.registered,
      );
      _lastEvent = '${account.name} ${nextStatus.label.toLowerCase()}';
    });
  }

  void _appendDial(String value) {
    setState(() {
      _dialNumber = '$_dialNumber$value';
    });
  }

  void _backspaceDial() {
    if (_dialNumber.isEmpty) {
      return;
    }

    setState(() {
      _dialNumber = _dialNumber.substring(0, _dialNumber.length - 1);
    });
  }

  void _clearDial() {
    setState(() {
      _dialNumber = '';
    });
  }

  void _simulateCall() {
    final account = _selectedAccount;
    if (account == null || _dialNumber.trim().isEmpty) {
      return;
    }

    setState(() {
      _lastEvent =
          'Outgoing call prepared from ${account.name} to $_dialNumber';
    });
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 920;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(compact ? 16 : 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppHeader(
                accountCount: _accounts.length,
                onAddAccount: () => _openAccountDialog(),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: compact
                    ? ListView(
                        children: _buildPanels(compact: true),
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 360,
                            child: AccountPanel(
                              accounts: _accounts,
                              selectedAccountId: _selectedAccount?.id,
                              onAddAccount: () => _openAccountDialog(),
                              onEditAccount: (account) =>
                                  _openAccountDialog(account: account),
                              onRemoveAccount: _removeAccount,
                              onSelectAccount: (account) {
                                setState(() {
                                  _selectedAccountId = account.id;
                                });
                              },
                              onToggleRegistration: _toggleRegistration,
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: WorkspacePanels(
                              selectedAccount: _selectedAccount,
                              dialNumber: _dialNumber,
                              accountCount: _accounts.length,
                              lastEvent: _lastEvent,
                              onAppend: _appendDial,
                              onBackspace: _backspaceDial,
                              onClear: _clearDial,
                              onCall: _simulateCall,
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildPanels({required bool compact}) {
    return [
      AccountPanel(
        accounts: _accounts,
        selectedAccountId: _selectedAccount?.id,
        onAddAccount: () => _openAccountDialog(),
        onEditAccount: (account) => _openAccountDialog(account: account),
        onRemoveAccount: _removeAccount,
        onSelectAccount: (account) {
          setState(() {
            _selectedAccountId = account.id;
          });
        },
        onToggleRegistration: _toggleRegistration,
      ),
      const SizedBox(height: 16),
      DialerPanel(
        selectedAccount: _selectedAccount,
        dialNumber: _dialNumber,
        onAppend: _appendDial,
        onBackspace: _backspaceDial,
        onClear: _clearDial,
        onCall: _simulateCall,
      ),
      const SizedBox(height: 16),
      BottomPanels(accountCount: _accounts.length, lastEvent: _lastEvent),
    ];
  }
}

class WorkspacePanels extends StatelessWidget {
  const WorkspacePanels({
    required this.selectedAccount,
    required this.dialNumber,
    required this.accountCount,
    required this.lastEvent,
    required this.onAppend,
    required this.onBackspace,
    required this.onClear,
    required this.onCall,
    super.key,
  });

  final WebRtcAccount? selectedAccount;
  final String dialNumber;
  final int accountCount;
  final String lastEvent;
  final ValueChanged<String> onAppend;
  final VoidCallback onBackspace;
  final VoidCallback onClear;
  final VoidCallback onCall;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 1080) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: DialerPanel(
                  selectedAccount: selectedAccount,
                  dialNumber: dialNumber,
                  onAppend: onAppend,
                  onBackspace: onBackspace,
                  onClear: onClear,
                  onCall: onCall,
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 360,
                child: Column(
                  children: [
                    DiagnosticsPanel(
                      accountCount: accountCount,
                      lastEvent: lastEvent,
                    ),
                    const SizedBox(height: 16),
                    const Expanded(child: CallHistoryPanel()),
                  ],
                ),
              ),
            ],
          );
        }

        return ListView(
          children: [
            DialerPanel(
              selectedAccount: selectedAccount,
              dialNumber: dialNumber,
              onAppend: onAppend,
              onBackspace: onBackspace,
              onClear: onClear,
              onCall: onCall,
            ),
            const SizedBox(height: 16),
            BottomPanels(accountCount: accountCount, lastEvent: lastEvent),
          ],
        );
      },
    );
  }
}

class AppHeader extends StatelessWidget {
  const AppHeader({
    required this.accountCount,
    required this.onAddAccount,
    super.key,
  });

  final int accountCount;
  final VoidCallback onAddAccount;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 640;

    return Flex(
      direction: compact ? Axis.vertical : Axis.horizontal,
      crossAxisAlignment:
          compact ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'MNSCloud PhoneWeb',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              '$accountCount WebRTC account${accountCount == 1 ? '' : 's'} configured',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
        SizedBox(
            height: compact ? 14 : 0, width: compact ? double.infinity : 0),
        FilledButton.icon(
          onPressed: onAddAccount,
          icon: const Icon(Icons.add),
          label: const Text('Add account'),
        ),
      ],
    );
  }
}

class AccountPanel extends StatelessWidget {
  const AccountPanel({
    required this.accounts,
    required this.selectedAccountId,
    required this.onAddAccount,
    required this.onEditAccount,
    required this.onRemoveAccount,
    required this.onSelectAccount,
    required this.onToggleRegistration,
    super.key,
  });

  final List<WebRtcAccount> accounts;
  final String? selectedAccountId;
  final VoidCallback onAddAccount;
  final ValueChanged<WebRtcAccount> onEditAccount;
  final ValueChanged<WebRtcAccount> onRemoveAccount;
  final ValueChanged<WebRtcAccount> onSelectAccount;
  final ValueChanged<WebRtcAccount> onToggleRegistration;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PanelTitle(
            icon: Icons.account_circle_outlined,
            title: 'Accounts',
            action: IconButton(
              tooltip: 'Add account',
              onPressed: onAddAccount,
              icon: const Icon(Icons.add),
            ),
          ),
          const SizedBox(height: 12),
          if (accounts.isEmpty)
            EmptyState(
              icon: Icons.wifi_calling_3_outlined,
              title: 'No WebRTC accounts',
              message: 'Add a WSS provider account to start configuring calls.',
              actionLabel: 'Add account',
              onAction: onAddAccount,
            )
          else
            ...accounts.map(
              (account) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AccountTile(
                  account: account,
                  selected: selectedAccountId == account.id,
                  onSelect: () => onSelectAccount(account),
                  onEdit: () => onEditAccount(account),
                  onRemove: () => onRemoveAccount(account),
                  onToggle: () => onToggleRegistration(account),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class AccountTile extends StatelessWidget {
  const AccountTile({
    required this.account,
    required this.selected,
    required this.onSelect,
    required this.onEdit,
    required this.onRemove,
    required this.onToggle,
    super.key,
  });

  final WebRtcAccount account;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onEdit;
  final VoidCallback onRemove;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onSelect,
      borderRadius: BorderRadius.circular(8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected
              ? colorScheme.primaryContainer.withValues(alpha: 0.45)
              : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? colorScheme.primary : colorScheme.outlineVariant,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          account.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${account.username}@${account.domain}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  StatusChip(status: account.status),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                account.wssServer,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  FilledButton.tonalIcon(
                    onPressed: onToggle,
                    icon: Icon(
                      account.status == RegistrationStatus.registered
                          ? Icons.logout
                          : Icons.login,
                    ),
                    label: Text(
                      account.status == RegistrationStatus.registered
                          ? 'Disable'
                          : 'Enable',
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Edit account',
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  IconButton(
                    tooltip: 'Remove account',
                    onPressed: onRemove,
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DialerPanel extends StatelessWidget {
  const DialerPanel({
    required this.selectedAccount,
    required this.dialNumber,
    required this.onAppend,
    required this.onBackspace,
    required this.onClear,
    required this.onCall,
    super.key,
  });

  final WebRtcAccount? selectedAccount;
  final String dialNumber;
  final ValueChanged<String> onAppend;
  final VoidCallback onBackspace;
  final VoidCallback onClear;
  final VoidCallback onCall;

  @override
  Widget build(BuildContext context) {
    final canCall = selectedAccount != null && dialNumber.trim().isNotEmpty;
    final colorScheme = Theme.of(context).colorScheme;

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PanelTitle(
            icon: Icons.dialpad_outlined,
            title: 'Dialer',
          ),
          const SizedBox(height: 16),
          AccountContextBanner(account: selectedAccount),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F5F2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: colorScheme.outlineVariant),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              dialNumber.isEmpty ? 'Enter number' : dialNumber,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    color: dialNumber.isEmpty
                                        ? colorScheme.onSurfaceVariant
                                        : colorScheme.onSurface,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Backspace',
                            onPressed: dialNumber.isEmpty ? null : onBackspace,
                            icon: const Icon(Icons.backspace_outlined),
                          ),
                          IconButton(
                            tooltip: 'Clear',
                            onPressed: dialNumber.isEmpty ? null : onClear,
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  DialPad(onAppend: onAppend),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton.icon(
                      onPressed: canCall ? onCall : null,
                      icon: const Icon(Icons.call),
                      label: const Text('Call'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AccountContextBanner extends StatelessWidget {
  const AccountContextBanner({required this.account, super.key});

  final WebRtcAccount? account;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final currentAccount = account;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            account == null ? Icons.info_outline : Icons.router_outlined,
            color: colorScheme.onSecondaryContainer,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              currentAccount == null
                  ? 'Select or add an account before placing calls.'
                  : '${currentAccount.name} · ${currentAccount.status.label}',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: colorScheme.onSecondaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}

class DialPad extends StatelessWidget {
  const DialPad({required this.onAppend, super.key});

  final ValueChanged<String> onAppend;

  @override
  Widget build(BuildContext context) {
    const values = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '*', '0', '#'];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: values.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisExtent: 58,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
      ),
      itemBuilder: (context, index) {
        final value = values[index];

        return OutlinedButton(
          onPressed: () => onAppend(value),
          child: Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        );
      },
    );
  }
}

class BottomPanels extends StatelessWidget {
  const BottomPanels({
    required this.accountCount,
    required this.lastEvent,
    super.key,
  });

  final int accountCount;
  final String lastEvent;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 760;
    final panels = [
      Expanded(
        child: DiagnosticsPanel(
          accountCount: accountCount,
          lastEvent: lastEvent,
        ),
      ),
      const SizedBox(width: 16, height: 16),
      const Expanded(child: CallHistoryPanel()),
    ];

    if (compact) {
      return Column(
        children: [
          DiagnosticsPanel(accountCount: accountCount, lastEvent: lastEvent),
          const SizedBox(height: 16),
          const CallHistoryPanel(),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: panels,
    );
  }
}

class DiagnosticsPanel extends StatelessWidget {
  const DiagnosticsPanel({
    required this.accountCount,
    required this.lastEvent,
    super.key,
  });

  final int accountCount;
  final String lastEvent;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PanelTitle(
            icon: Icons.monitor_heart_outlined,
            title: 'Diagnostics',
          ),
          const SizedBox(height: 12),
          InfoRow(label: 'WebRTC engine', value: 'Idle'),
          InfoRow(label: 'Accounts loaded', value: '$accountCount'),
          InfoRow(label: 'Last event', value: lastEvent),
        ],
      ),
    );
  }
}

class CallHistoryPanel extends StatelessWidget {
  const CallHistoryPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return const SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PanelTitle(
            icon: Icons.history,
            title: 'Call history',
          ),
          SizedBox(height: 12),
          EmptyState(
            icon: Icons.call_outlined,
            title: 'No calls yet',
            message: 'Completed calls will appear here.',
          ),
        ],
      ),
    );
  }
}

class AccountDialog extends StatefulWidget {
  const AccountDialog({this.account, super.key});

  final WebRtcAccount? account;

  @override
  State<AccountDialog> createState() => _AccountDialogState();
}

class _AccountDialogState extends State<AccountDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _displayNameController;
  late final TextEditingController _usernameController;
  late final TextEditingController _domainController;
  late final TextEditingController _wssController;
  late final TextEditingController _stunController;
  late final TextEditingController _turnController;
  late final TextEditingController _passwordController;
  bool _enabled = true;
  bool _autoRegister = true;

  @override
  void initState() {
    super.initState();
    final account = widget.account;

    _nameController = TextEditingController(text: account?.name ?? '');
    _displayNameController =
        TextEditingController(text: account?.displayName ?? '');
    _usernameController = TextEditingController(text: account?.username ?? '');
    _domainController = TextEditingController(text: account?.domain ?? '');
    _wssController = TextEditingController(text: account?.wssServer ?? '');
    _stunController = TextEditingController(text: account?.stunServer ?? '');
    _turnController = TextEditingController(text: account?.turnServer ?? '');
    _passwordController = TextEditingController();
    _enabled = account?.enabled ?? true;
    _autoRegister = account?.autoRegister ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _displayNameController.dispose();
    _usernameController.dispose();
    _domainController.dispose();
    _wssController.dispose();
    _stunController.dispose();
    _turnController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 720;

    return Dialog(
      insetPadding: EdgeInsets.all(compact ? 16 : 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.account == null
                        ? 'Add WebRTC account'
                        : 'Edit WebRTC account',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      DialogField(
                        width: compact ? double.infinity : 348,
                        child: TextFormField(
                          controller: _nameController,
                          decoration:
                              const InputDecoration(labelText: 'Account name'),
                          validator: _required,
                        ),
                      ),
                      DialogField(
                        width: compact ? double.infinity : 348,
                        child: TextFormField(
                          controller: _displayNameController,
                          decoration:
                              const InputDecoration(labelText: 'Display name'),
                        ),
                      ),
                      DialogField(
                        width: compact ? double.infinity : 224,
                        child: TextFormField(
                          controller: _usernameController,
                          decoration:
                              const InputDecoration(labelText: 'SIP user'),
                          validator: _required,
                        ),
                      ),
                      DialogField(
                        width: compact ? double.infinity : 224,
                        child: TextFormField(
                          controller: _domainController,
                          decoration:
                              const InputDecoration(labelText: 'Domain'),
                          validator: _required,
                        ),
                      ),
                      DialogField(
                        width: compact ? double.infinity : 224,
                        child: TextFormField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration:
                              const InputDecoration(labelText: 'Password'),
                        ),
                      ),
                      DialogField(
                        width: double.infinity,
                        child: TextFormField(
                          controller: _wssController,
                          decoration: const InputDecoration(
                            labelText: 'WSS server',
                            hintText: 'wss://pbx.example.com/ws',
                          ),
                          validator: _wss,
                        ),
                      ),
                      DialogField(
                        width: compact ? double.infinity : 348,
                        child: TextFormField(
                          controller: _stunController,
                          decoration: const InputDecoration(
                            labelText: 'STUN server',
                            hintText: 'stun:stun.example.com:3478',
                          ),
                        ),
                      ),
                      DialogField(
                        width: compact ? double.infinity : 348,
                        child: TextFormField(
                          controller: _turnController,
                          decoration: const InputDecoration(
                            labelText: 'TURN server',
                            hintText: 'turn:turn.example.com:3478',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 18,
                    runSpacing: 8,
                    children: [
                      FilterChip(
                        selected: _enabled,
                        label: const Text('Enabled'),
                        avatar: Icon(_enabled ? Icons.check : Icons.close),
                        onSelected: (value) {
                          setState(() {
                            _enabled = value;
                          });
                        },
                      ),
                      FilterChip(
                        selected: _autoRegister,
                        label: const Text('Auto register'),
                        avatar: Icon(
                            _autoRegister ? Icons.sync : Icons.sync_disabled),
                        onSelected: (value) {
                          setState(() {
                            _autoRegister = value;
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        onPressed: _submit,
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('Save'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Required';
    }
    return null;
  }

  String? _wss(String? value) {
    final required = _required(value);
    if (required != null) {
      return required;
    }
    if (!value!.trim().startsWith('wss://')) {
      return 'Use a secure WSS URL';
    }
    return null;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final existing = widget.account;
    final account = WebRtcAccount(
      id: existing?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      name: _nameController.text.trim(),
      displayName: _displayNameController.text.trim(),
      username: _usernameController.text.trim(),
      domain: _domainController.text.trim(),
      wssServer: _wssController.text.trim(),
      stunServer: _stunController.text.trim(),
      turnServer: _turnController.text.trim(),
      hasPassword: _passwordController.text.isNotEmpty ||
          (existing?.hasPassword ?? false),
      enabled: _enabled,
      autoRegister: _autoRegister,
      status: existing?.status ?? RegistrationStatus.offline,
    );

    Navigator.of(context).pop(account);
  }
}

class DialogField extends StatelessWidget {
  const DialogField({required this.width, required this.child, super.key});

  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: width, child: child);
  }
}

class SectionCard extends StatelessWidget {
  const SectionCard({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: child,
      ),
    );
  }
}

class PanelTitle extends StatelessWidget {
  const PanelTitle({
    required this.icon,
    required this.title,
    this.action,
    super.key,
  });

  final IconData icon;
  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        if (action != null) action!,
      ],
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAF7),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 34,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.add),
              label: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip({required this.status, super.key});

  final RegistrationStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      RegistrationStatus.registered => const Color(0xFF047857),
      RegistrationStatus.registering => const Color(0xFFB45309),
      RegistrationStatus.failed => const Color(0xFFB91C1C),
      RegistrationStatus.offline =>
        Theme.of(context).colorScheme.onSurfaceVariant,
    };

    return Chip(
      visualDensity: VisualDensity.compact,
      side: BorderSide(color: color.withValues(alpha: 0.35)),
      label: Text(status.label),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.w700),
      backgroundColor: color.withValues(alpha: 0.08),
    );
  }
}

class InfoRow extends StatelessWidget {
  const InfoRow({required this.label, required this.value, super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 132,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

enum RegistrationStatus {
  offline,
  registering,
  registered,
  failed;

  String get label {
    return switch (this) {
      RegistrationStatus.offline => 'Offline',
      RegistrationStatus.registering => 'Registering',
      RegistrationStatus.registered => 'Registered',
      RegistrationStatus.failed => 'Failed',
    };
  }
}

class WebRtcAccount {
  const WebRtcAccount({
    required this.id,
    required this.name,
    required this.displayName,
    required this.username,
    required this.domain,
    required this.wssServer,
    required this.stunServer,
    required this.turnServer,
    required this.hasPassword,
    required this.enabled,
    required this.autoRegister,
    required this.status,
  });

  final String id;
  final String name;
  final String displayName;
  final String username;
  final String domain;
  final String wssServer;
  final String stunServer;
  final String turnServer;
  final bool hasPassword;
  final bool enabled;
  final bool autoRegister;
  final RegistrationStatus status;

  WebRtcAccount copyWith({
    String? id,
    String? name,
    String? displayName,
    String? username,
    String? domain,
    String? wssServer,
    String? stunServer,
    String? turnServer,
    bool? hasPassword,
    bool? enabled,
    bool? autoRegister,
    RegistrationStatus? status,
  }) {
    return WebRtcAccount(
      id: id ?? this.id,
      name: name ?? this.name,
      displayName: displayName ?? this.displayName,
      username: username ?? this.username,
      domain: domain ?? this.domain,
      wssServer: wssServer ?? this.wssServer,
      stunServer: stunServer ?? this.stunServer,
      turnServer: turnServer ?? this.turnServer,
      hasPassword: hasPassword ?? this.hasPassword,
      enabled: enabled ?? this.enabled,
      autoRegister: autoRegister ?? this.autoRegister,
      status: status ?? this.status,
    );
  }
}
