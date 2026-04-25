import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:coqui_app/Models/coqui_exception.dart';
import 'package:coqui_app/Providers/instance_provider.dart';

enum _RestartPromptAction { later, restart }

Future<void> promptForPendingServerRestart(
  BuildContext context, {
  FutureOr<void> Function()? onRestarted,
}) async {
  final instanceProvider = context.read<InstanceProvider>();
  await instanceProvider.refreshHealth();

  if (!context.mounted ||
      instanceProvider.isOnline != true ||
      !instanceProvider.restartRequired) {
    return;
  }

  final reason = instanceProvider.restartState.reason ??
      'Restart the API server so the latest channel configuration is fully applied.';

  final action = await showDialog<_RestartPromptAction>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Restart API server?'),
      content: Text(reason),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, _RestartPromptAction.later),
          child: const Text('Later'),
        ),
        FilledButton.icon(
          onPressed: () =>
              Navigator.pop(dialogContext, _RestartPromptAction.restart),
          icon: const Icon(Icons.restart_alt),
          label: const Text('Restart now'),
        ),
      ],
    ),
  );

  if (action != _RestartPromptAction.restart || !context.mounted) {
    return;
  }

  await restartServerFromPrompt(context, onRestarted: onRestarted);
}

Future<void> restartServerFromPrompt(
  BuildContext context, {
  FutureOr<void> Function()? onRestarted,
}) async {
  final instanceProvider = context.read<InstanceProvider>();
  final messenger = ScaffoldMessenger.of(context);

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => const AlertDialog(
      content: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Text('Restarting the API server and waiting for it to come back online...'),
          ),
        ],
      ),
    ),
  );

  try {
    final success = await instanceProvider.requestServerRestart();
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }

    if (!context.mounted) return;

    if (success) {
      if (onRestarted != null) {
        await onRestarted();
      }
      messenger.showSnackBar(
        const SnackBar(content: Text('API restarted and is back online.')),
      );
      return;
    }

    messenger.showSnackBar(
      const SnackBar(
        content: Text(
          'API restart was requested, but the server did not come back online in time.',
        ),
      ),
    );
  } catch (error) {
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      messenger.showSnackBar(
        SnackBar(content: Text(CoquiException.friendly(error).message)),
      );
    }
  }
}