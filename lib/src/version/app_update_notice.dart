import 'package:flutter/material.dart';

import 'app_update_controller.dart';

/// Calm, non-blocking "new version" card. The host decides where it sits and
/// hides it during calls; this widget never reloads by itself.
class AppUpdateNotice extends StatelessWidget {
  const AppUpdateNotice({super.key, required this.controller});

  final AppUpdateController controller;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final version = controller.deployed?.version;

    return Semantics(
      liveRegion: true,
      container: true,
      label: 'Nova versão disponível',
      child: Material(
        elevation: 6,
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 380),
          padding: const EdgeInsets.fromLTRB(16, 14, 6, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(Icons.auto_awesome, color: colorScheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        text: 'Nova versão disponível',
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        children: [
                          if (version != null)
                            TextSpan(
                              text: '  v$version',
                              style: textTheme.labelSmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'O PhoneWeb foi atualizado com melhorias e correções. '
                      'Atualize quando for conveniente; suas contas e o histórico '
                      'ficam salvos.',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        TextButton(
                          onPressed: controller.postpone,
                          child: const Text('Depois'),
                        ),
                        FilledButton.icon(
                          onPressed: controller.reloadNow,
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('Atualizar agora'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Lembrar mais tarde',
                onPressed: controller.postpone,
                icon: const Icon(Icons.close),
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
