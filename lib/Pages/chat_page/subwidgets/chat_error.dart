import 'package:flutter/material.dart';
import 'package:coqui_app/Models/coqui_exception.dart';

class ChatError extends StatelessWidget {
  final CoquiException error;
  final void Function() onRetry;

  const ChatError({
    super.key,
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final (icon, label, showRetry) = _errorPresentation;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.error),
        borderRadius: BorderRadius.circular(10.0),
      ),
      padding: const EdgeInsets.all(10.0),
      margin: const EdgeInsets.all(10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: colorScheme.error, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(color: colorScheme.error),
                ),
              ),
            ],
          ),
          if (showRetry) ...[
            const SizedBox(height: 10.0),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.error,
              ),
              child: const Text('Retry'),
            ),
          ],
        ],
      ),
    );
  }

  /// Returns (icon, label, showRetry) based on the error code.
  (IconData, String, bool) get _errorPresentation {
    return switch (error.code) {
      'agent_busy' => (
          Icons.hourglass_top_rounded,
          'Session is processing another request. Please wait.',
          true,
        ),
      'rate_limited' => (
          Icons.speed_rounded,
          _rateLimitMessage,
          true,
        ),
      'unauthorized' => (
          Icons.lock_outline_rounded,
          'Authentication failed. Check your API key in Settings.',
          false,
        ),
      'payload_too_large' => (
          Icons.warning_amber_rounded,
          'Message is too long. Maximum size is 100 KB.',
          false,
        ),
      'session_not_found' => (
          Icons.search_off_rounded,
          'Session not found. It may have been deleted.',
          false,
        ),
      _ => (
          Icons.error_outline_rounded,
          error.message,
          true,
        ),
    };
  }

  String get _rateLimitMessage {
    final retryAfter = error.retryAfter;
    if (retryAfter != null) {
      return 'Rate limited. Try again in $retryAfter second${retryAfter == 1 ? '' : 's'}.';
    }
    return 'Rate limited. Please wait before sending another request.';
  }
}
