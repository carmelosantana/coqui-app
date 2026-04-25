import 'package:flutter/material.dart';
import 'package:coqui_app/Models/local_server_state.dart';
import 'package:coqui_app/Providers/local_server_provider.dart';
import 'package:provider/provider.dart';

/// Header showing the Coqui server icon, version, and status chip.
class ServerStatusHeader extends StatelessWidget {
  const ServerStatusHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<LocalServerProvider>(
      builder: (context, provider, _) {
        final info = provider.info;
        final colorScheme = Theme.of(context).colorScheme;
        final textTheme = Theme.of(context).textTheme;

        return Row(
          children: [
            Icon(
              Icons.dns,
              size: 32,
              color: colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Coqui Server',
                        style: textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (info.version != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'v${info.version}',
                            style: textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSecondaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  _StatusChip(status: info.status),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StatusChip extends StatelessWidget {
  final LocalServerStatus status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      LocalServerStatus.notInstalled => ('Not Installed', Colors.grey),
      LocalServerStatus.stopped => ('Stopped', Colors.grey),
      LocalServerStatus.running => ('Running', Colors.green),
      LocalServerStatus.error => ('Error', Colors.red),
      LocalServerStatus.installing => ('Installing…', Colors.orange),
      LocalServerStatus.updating => ('Updating…', Colors.orange),
      LocalServerStatus.starting => ('Starting…', Colors.orange),
      LocalServerStatus.stopping => ('Stopping…', Colors.orange),
      LocalServerStatus.uninstalling => ('Uninstalling…', Colors.orange),
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w500,
              ),
        ),
      ],
    );
  }
}
