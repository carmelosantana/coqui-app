import 'package:flutter/material.dart';
import 'package:coqui_app/Providers/local_server_provider.dart';
import 'package:provider/provider.dart';

/// Read-only configuration summary for the local server.
class ServerConfig extends StatelessWidget {
  const ServerConfig({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<LocalServerProvider>(
      builder: (context, provider, _) {
        final textStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Configuration',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text('Host: 127.0.0.1', style: textStyle),
            const SizedBox(height: 4),
            Text('Port: ${provider.port}', style: textStyle),
            const SizedBox(height: 4),
            Text('Install path: ${provider.installPath}', style: textStyle),
            const SizedBox(height: 4),
            Text('Workspace: ${provider.workspacePath}', style: textStyle),
          ],
        );
      },
    );
  }
}
