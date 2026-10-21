import 'package:flutter/material.dart';

import 'app_update_controller.dart';
import '../i18n/phoneweb_strings.dart';

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
    final critical = controller.critical;

    return Semantics(
      liveRegion: true,
      container: true,
      label: critical ? tr('Important update') : tr('New version available'),
      child: Material(
        elevation: 6,
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 380),
          padding: const EdgeInsets.fromLTRB(16, 14, 6, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: critical
                  ? colorScheme.primary
                  : colorScheme.outlineVariant,
              width: critical ? 2 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(
                  critical ? Icons.system_update : Icons.auto_awesome,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        text: critical
                            ? tr('Important update')
                            : tr('New version available'),
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
                    if (critical)
                      Text(
                        tr(
                          'This version fixes an important problem. Update as soon as possible; your accounts and history stay saved.',
                        ),
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                      )
                    else
                      Text(
                        tr(
                          tr(
                            'PhoneWeb was updated with improvements and fixes. Update when convenient; your accounts and history stay saved.',
                          ),
                        ),
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
                        if (!critical)
                          TextButton(
                            onPressed: controller.postpone,
                            child: Text(tr('Later')),
                          ),
                        FilledButton.icon(
                          onPressed: controller.reloadNow,
                          icon: const Icon(Icons.refresh, size: 18),
                          label: Text(tr('Update now')),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (!critical)
                IconButton(
                  tooltip: tr('Remind me later'),
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
