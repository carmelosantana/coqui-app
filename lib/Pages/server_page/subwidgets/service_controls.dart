import 'package:flutter/material.dart';
import 'package:coqui_app/Platform/platform_info.dart';
import 'package:coqui_app/Providers/local_server_provider.dart';
import 'package:provider/provider.dart';

/// Service management controls (launchd on macOS, systemd on Linux).
/// Hidden on Windows with an explanation.
class ServiceControls extends StatelessWidget {
  const ServiceControls({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<LocalServerProvider>(
      builder: (context, provider, _) {
        if (!provider.serviceSupported) {
          if (PlatformInfo.isWindows) {
            return _buildUnsupportedCard(
                context,
                'Windows Service support is coming in a future release. '
                'For now, use the Start/Stop buttons above to control '
                'the server process.');
          }
          return _buildUnsupportedCard(
              context,
              'Service management is not available on this system. '
              'Use the Start/Stop buttons to control the server process.');
        }

        final info = provider.info;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Background Service',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Run the server as a background service that starts '
              'automatically when you log in.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 12),
            CheckboxListTile(
              value: provider.autoApprove,
              onChanged:
                  info.isBusy ? null : (v) => provider.setAutoApprove(v ?? false),
              title: const Text('Auto-approve tools'),
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
            CheckboxListTile(
              value: provider.unsafe,
              onChanged:
                  info.isBusy ? null : (v) => provider.setUnsafe(v ?? false),
              title: const Text('Unsafe mode'),
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 4),
            if (!info.serviceInstalled)
              FilledButton.tonalIcon(
                onPressed: info.isBusy ? null : () => provider.installService(),
                icon: const Icon(Icons.miscellaneous_services),
                label: const Text('Set Up Service'),
              )
            else ...[
              Row(
                children: [
                  Icon(
                    info.serviceRunning
                        ? Icons.check_circle
                        : Icons.remove_circle_outline,
                    size: 16,
                    color: info.serviceRunning ? Colors.green : Colors.grey,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    info.serviceRunning ? 'Service running' : 'Service stopped',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (!info.serviceRunning)
                    FilledButton.tonal(
                      onPressed:
                          info.isBusy ? null : () => provider.startService(),
                      child: const Text('Start Service'),
                    ),
                  if (info.serviceRunning) ...[
                    FilledButton.tonal(
                      onPressed:
                          info.isBusy ? null : () => provider.stopService(),
                      child: const Text('Stop Service'),
                    ),
                  ],
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed:
                        info.isBusy ? null : () => provider.uninstallService(),
                    child: const Text('Remove Service'),
                  ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildUnsupportedCard(BuildContext context, String message) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(
              Icons.info_outline,
              size: 18,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
