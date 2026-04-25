import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:coqui_app/Models/local_server_state.dart';
import 'package:coqui_app/Providers/local_server_provider.dart';
import 'package:provider/provider.dart';

/// Adaptive action buttons based on the current server state.
class ServerControls extends StatelessWidget {
  const ServerControls({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<LocalServerProvider>(
      builder: (context, provider, _) {
        final info = provider.info;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (info.status == LocalServerStatus.notInstalled)
              _buildInstallSection(context, provider),
            if (info.isInstalled) ...[
              if (info.instanceConfigMismatch) ...[
                _buildSyncWarning(context, provider),
                const SizedBox(height: 16),
              ],
              _buildProcessSection(context, provider),
              if (info.status == LocalServerStatus.running) ...[
                const SizedBox(height: 16),
                _buildConnectionInfo(context, provider),
              ],
              const SizedBox(height: 16),
              _buildUpdateSection(context, provider),
            ],
            if (info.errorMessage != null) ...[
              const SizedBox(height: 12),
              _buildErrorCard(context, info.errorMessage!),
            ],
            if (info.isInstalled) ...[
              const SizedBox(height: 16),
              _buildManualFallback(context, provider),
            ],
          ],
        );
      },
    );
  }

  Widget _buildInstallSection(
    BuildContext context,
    LocalServerProvider provider,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: provider.info.isBusy ? null : () => provider.install(),
          icon: const Icon(Icons.download),
          label: const Text('Install Server'),
        ),
        const SizedBox(height: 8),
        Text(
          'Requires PHP 8.4+. The installer will set this up automatically.\n'
          'The installer may ask for your password to install PHP.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }

  Widget _buildProcessSection(
    BuildContext context,
    LocalServerProvider provider,
  ) {
    final info = provider.info;
    final isBusy = info.isBusy;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CheckboxListTile(
          value: provider.autoApprove,
          onChanged: isBusy ? null : (v) => provider.setAutoApprove(v ?? false),
          title: const Text('Auto-approve tools'),
          subtitle: const Text(
            'Skip confirmation prompts. Catastrophic commands are still blocked.',
          ),
          dense: true,
          contentPadding: EdgeInsets.zero,
        ),
        CheckboxListTile(
          value: provider.unsafe,
          onChanged: isBusy ? null : (v) => provider.setUnsafe(v ?? false),
          title: const Text('Unsafe mode'),
          subtitle: const Text(
            'Disable PHP function restrictions in php_execute.',
          ),
          dense: true,
          contentPadding: EdgeInsets.zero,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            if (info.status == LocalServerStatus.stopped ||
                info.status == LocalServerStatus.error) ...[
              Expanded(
                child: FilledButton.icon(
                  onPressed: isBusy ? null : () => provider.startProcess(),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Start'),
                ),
              ),
            ],
            if (info.status == LocalServerStatus.running) ...[
              Expanded(
                child: FilledButton.icon(
                  onPressed: isBusy ? null : () => provider.stopProcess(),
                  icon: const Icon(Icons.stop),
                  label: const Text('Stop'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isBusy ? null : () => provider.restartProcess(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Restart'),
                ),
              ),
            ],
            if (info.status == LocalServerStatus.starting ||
                info.status == LocalServerStatus.stopping) ...[
              const Expanded(
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildConnectionInfo(
    BuildContext context,
    LocalServerProvider provider,
  ) {
    final info = provider.info;
    final url = 'http://127.0.0.1:${info.port}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Connection',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child:
                      Text(url, style: Theme.of(context).textTheme.bodyMedium),
                ),
                IconButton(
                  icon: const Icon(Icons.copy, size: 18),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: url));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('URL copied'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                  tooltip: 'Copy URL',
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                ),
              ],
            ),
            if (info.apiKey != null) ...[
              const SizedBox(height: 4),
              _ApiKeyRow(apiKey: info.apiKey!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildUpdateSection(
    BuildContext context,
    LocalServerProvider provider,
  ) {
    return OutlinedButton.icon(
      onPressed: provider.info.isBusy ? null : () => provider.update(),
      icon: const Icon(Icons.system_update_alt),
      label: const Text('Check for Updates'),
    );
  }

  Widget _buildSyncWarning(
    BuildContext context,
    LocalServerProvider provider,
  ) {
    return Card(
      color: Theme.of(context).colorScheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Local instance out of sync',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onTertiaryContainer,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'The API key stored in ~/.coqui/.workspace/.env does not match the app\'s local server configuration. '
              'Sync the local instance before starting or updating the server.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onTertiaryContainer,
                  ),
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: provider.info.isBusy
                  ? null
                  : () => provider.syncInstanceFromConfig(),
              icon: const Icon(Icons.sync),
              label: const Text('Sync Local Instance'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard(BuildContext context, String message) {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(
              Icons.error_outline,
              color: Theme.of(context).colorScheme.onErrorContainer,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManualFallback(
    BuildContext context,
    LocalServerProvider provider,
  ) {
    return ExpansionTile(
      title: Text(
        'Manual Launch',
        style: Theme.of(context).textTheme.titleSmall,
      ),
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 8),
      children: [
        Text(
          'If the controls above don\'t work, you can start the server '
          'manually from a terminal on this machine:',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Expanded(
                child: SelectableText(
                  provider.manualLaunchCommand,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                      ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy, size: 16),
                onPressed: () {
                  Clipboard.setData(
                    ClipboardData(text: provider.manualLaunchCommand),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Command copied'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
                tooltip: 'Copy command',
                constraints: const BoxConstraints(
                  minWidth: 28,
                  minHeight: 28,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ApiKeyRow extends StatefulWidget {
  final String apiKey;
  const _ApiKeyRow({required this.apiKey});

  @override
  State<_ApiKeyRow> createState() => _ApiKeyRowState();
}

class _ApiKeyRowState extends State<_ApiKeyRow> {
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            _revealed ? widget.apiKey : '••••••••••••••••',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        IconButton(
          icon: Icon(
            _revealed ? Icons.visibility_off : Icons.visibility,
            size: 18,
          ),
          onPressed: () => setState(() => _revealed = !_revealed),
          tooltip: _revealed ? 'Hide API key' : 'Show API key',
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
        IconButton(
          icon: const Icon(Icons.copy, size: 18),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: widget.apiKey));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('API key copied'),
                duration: Duration(seconds: 1),
              ),
            );
          },
          tooltip: 'Copy API key',
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
      ],
    );
  }
}
