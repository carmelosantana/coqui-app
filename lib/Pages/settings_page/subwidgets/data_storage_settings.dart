import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:coqui_app/Providers/chat_provider.dart';
import 'package:coqui_app/Providers/instance_provider.dart';
import 'package:coqui_app/Services/analytics_service.dart';
import 'package:coqui_app/Services/app_restart_service.dart';
import 'package:coqui_app/Services/local_data_reset_service.dart';

class DataStorageSettings extends StatefulWidget {
  const DataStorageSettings({super.key});

  @override
  State<DataStorageSettings> createState() => _DataStorageSettingsState();
}

class _DataStorageSettingsState extends State<DataStorageSettings> {
  bool _clearingSessionCache = false;
  bool _clearingAllData = false;

  bool get _busy => _clearingSessionCache || _clearingAllData;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Data & Storage',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        ListTile(
          enabled: !_busy,
          leading: _clearingSessionCache
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.cleaning_services_outlined),
          title: const Text('Clear Session Cache'),
          subtitle: const Text(
            'Deletes only local cached conversations and messages on this device. Synced server sessions may reappear after refresh.',
          ),
          onTap: _busy ? null : _handleClearSessionCache,
        ),
        ListTile(
          enabled: !_busy,
          leading: _clearingAllData
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
                  Icons.delete_forever_outlined,
                  color: Theme.of(context).colorScheme.error,
                ),
          title: Text(
            'Delete All Stored Data',
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
          subtitle: const Text(
            'Deletes saved servers, local settings, and cached chat data on this device. Supported platforms restart automatically after the reset.',
          ),
          onTap: _busy ? null : _handleClearAllStoredData,
        ),
      ],
    );
  }

  Future<void> _handleClearSessionCache() async {
    final resetService = context.read<LocalDataResetService>();
    final chatProvider = context.read<ChatProvider>();
    final messenger = ScaffoldMessenger.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Session Cache?'),
        content: const Text(
          'This removes only locally cached conversations and messages from this device. Coqui will not delete any server-side sessions.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear Cache'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _clearingSessionCache = true);

    try {
      await resetService.clearSessionCache();
      chatProvider.clearLocalSessionState();

      AnalyticsService.trackEvent('local_session_cache_cleared');

      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Local session cache cleared. Synced sessions may reappear after refresh.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Failed to clear the local session cache: $error'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _clearingSessionCache = false);
      }
    }
  }

  Future<void> _handleClearAllStoredData() async {
    final resetService = context.read<LocalDataResetService>();
    final restartService = context.read<AppRestartService>();
    final chatProvider = context.read<ChatProvider>();
    final instanceProvider = context.read<InstanceProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final restartSupported = await restartService.isRestartSupported();
    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete All Stored Data?'),
        content: Text(
          restartSupported
              ? 'This closes Coqui\'s local stores, deletes saved servers, local settings, and cached chat data on this device, then restarts the app. Server-side data and exported files are not deleted.'
              : 'This deletes saved servers, local settings, and cached chat data on this device. Server-side data and exported files are not deleted. iOS does not allow Coqui to restart itself, so you will need to close and reopen the app when the reset finishes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete Local Data'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _clearingAllData = true);

    try {
      if (restartSupported) {
        chatProvider.clearLocalSessionState();
        instanceProvider.pauseForDestructiveReset();

        final restartResult = await _runBlockingResetDialog(
          message: 'Deleting local data and restarting Coqui...',
          action: () async {
            await resetService.deleteAllStoredDataForRestart();
            return restartService.restartApplication();
          },
        );

        AnalyticsService.trackEvent('local_app_data_cleared');

        if (!mounted) return;

        switch (restartResult) {
          case AppRestartResult.restarted:
            messenger.showSnackBar(
              const SnackBar(
                content: Text('Coqui is restarting to finish the reset.'),
              ),
            );
            return;
          case AppRestartResult.requiresManualRestart:
            await _showManualRestartDialog();
            return;
          case AppRestartResult.failed:
            messenger.showSnackBar(
              const SnackBar(
                content: Text(
                  'Local data was deleted, but Coqui could not restart automatically. Close and reopen the app to finish the reset.',
                ),
              ),
            );
            return;
        }
      }

      await resetService.clearAllStoredData();
      chatProvider.clearLocalSessionState();
      await instanceProvider.clearStoredInstances(ensureDefaultInstance: false);

      AnalyticsService.trackEvent('local_app_data_cleared');

      if (!mounted) return;
      await _showManualRestartDialog();
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Failed to reset local app data: $error'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _clearingAllData = false);
      }
    }
  }

  Future<T> _runBlockingResetDialog<T>({
    required String message,
    required Future<T> Function() action,
  }) async {
    final rootNavigator = Navigator.of(context, rootNavigator: true);
    final route = DialogRoute<void>(
      context: rootNavigator.context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Resetting Local Data'),
        content: Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 16),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );

    unawaited(rootNavigator.push(route));
    await Future<void>.delayed(Duration.zero);

    try {
      return await action();
    } finally {
      if (route.isActive && rootNavigator.mounted) {
        rootNavigator.removeRoute(route);
      }
    }
  }

  Future<void> _showManualRestartDialog() async {
    final navigator = Navigator.of(context);
    await showDialog<void>(
      context: navigator.context,
      builder: (context) => AlertDialog(
        title: const Text('Restart Coqui to Finish'),
        content: const Text(
          'Saved servers, local settings, and cached chat data were removed from this device. Close and reopen Coqui to finish the reset. Server-side data was not deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );

    if (mounted) {
      navigator.maybePop();
    }
  }
}