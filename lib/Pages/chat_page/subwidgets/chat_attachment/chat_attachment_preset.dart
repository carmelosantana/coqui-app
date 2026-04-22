import 'package:flutter/material.dart';
import 'package:coqui_app/Models/chat_preset.dart';

class ChatAttachmentPreset extends StatelessWidget {
  final ChatPreset preset;
  final Function() onPressed;

  const ChatAttachmentPreset({
    super.key,
    required this.preset,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (preset.role != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 7,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  preset.role!,
                  style: textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSecondaryContainer,
                  ),
                ),
              ),
              const SizedBox(height: 6),
            ],
            Text(preset.title, style: textTheme.titleSmall),
            Text(
              preset.subtitle,
              style: textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

