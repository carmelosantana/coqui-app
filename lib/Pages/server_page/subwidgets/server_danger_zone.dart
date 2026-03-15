import 'package:flutter/material.dart';
import 'package:coqui_app/Providers/local_server_provider.dart';
import 'package:provider/provider.dart';

/// Danger-zone section shown at the bottom of the Local Server page.
///
/// Lets the user uninstall the server with optional additives:
/// - Remove workspace data (~/.coqui/.workspace)
/// - Remove PHP and Composer from the system
///
/// The "Uninstall" button is disabled until the first checkbox (required gate)
/// is checked, and requires an explicit confirmation dialog before executing.
class ServerDangerZone extends StatefulWidget {
  const ServerDangerZone({super.key});

  @override
  State<ServerDangerZone> createState() => _ServerDangerZoneState();
}

class _ServerDangerZoneState extends State<ServerDangerZone> {
  bool _removeCoqui = false;
  bool _removeWorkspace = false;
  bool _removePhpComposer = false;

  void _reset() {
    setState(() {
      _removeCoqui = false;
      _removeWorkspace = false;
      _removePhpComposer = false;
    });
  }

  Future<void> _confirmAndUninstall(LocalServerProvider provider) async {
    final lines = <String>['• Coqui server and all installed packages'];
    if (_removeWorkspace) lines.add('• Workspace data (sessions, logs, configs)');
    if (_removePhpComposer) lines.add('• PHP and Composer');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Uninstall Coqui?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('The following will be permanently removed:'),
            const SizedBox(height: 8),
            ...lines.map((l) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(l),
                )),
            const SizedBox(height: 8),
            const Text('This cannot be undone.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Uninstall'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;

    await provider.uninstall(
      removeWorkspace: _removeWorkspace,
      removePhpAndComposer: _removePhpComposer,
    );

    if (mounted) _reset();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LocalServerProvider>(
      builder: (context, provider, _) {
        if (!provider.info.isInstalled) return const SizedBox.shrink();

        final isBusy = provider.info.isBusy;
        final canUninstall = _removeCoqui && !isBusy;
        final mutedColor = Theme.of(context).colorScheme.onSurfaceVariant;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Divider(),
            Text(
              'Uninstall',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: mutedColor,
                  ),
            ),
            const SizedBox(height: 4),
            CheckboxListTile(
              value: _removeCoqui,
              onChanged: isBusy
                  ? null
                  : (v) => setState(() => _removeCoqui = v ?? false),
              title: const Text('Remove Coqui server'),
              subtitle: const Text(
                'Stops the server and removes all installed files',
              ),
              contentPadding: EdgeInsets.zero,
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
            ),
            CheckboxListTile(
              value: _removeWorkspace,
              onChanged: isBusy
                  ? null
                  : (v) => setState(() => _removeWorkspace = v ?? false),
              title: const Text('Remove workspace data'),
              subtitle: const Text(
                'Deletes sessions, logs, and configuration (~/.coqui/.workspace)',
              ),
              contentPadding: EdgeInsets.zero,
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
            ),
            CheckboxListTile(
              value: _removePhpComposer,
              onChanged: isBusy
                  ? null
                  : (v) => setState(() => _removePhpComposer = v ?? false),
              title: const Text('Remove PHP and Composer'),
              subtitle: const Text(
                'Also uninstalls PHP and Composer from your system',
              ),
              contentPadding: EdgeInsets.zero,
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed:
                  canUninstall ? () => _confirmAndUninstall(provider) : null,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Uninstall'),
            ),
          ],
        );
      },
    );
  }
}
