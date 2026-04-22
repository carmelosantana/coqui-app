import 'package:flutter/material.dart';

import 'package:coqui_app/Models/coqui_artifact.dart';

class ArtifactStageBadge extends StatelessWidget {
  final CoquiArtifact artifact;

  const ArtifactStageBadge({
    super.key,
    required this.artifact,
  });

  @override
  Widget build(BuildContext context) {
    final (label, background, foreground) = switch (artifact.stage) {
      'draft' => (
          'Draft',
          Theme.of(context).colorScheme.surfaceContainerHighest,
          Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      'review' => (
          'Review',
          const Color(0xFFEDE6FF),
          const Color(0xFF6C39C7),
        ),
      'final' => (
          'Final',
          const Color(0xFFDDF6E8),
          const Color(0xFF1B7F43),
        ),
      _ => (
          artifact.stage,
          Theme.of(context).colorScheme.surfaceContainerHighest,
          Theme.of(context).colorScheme.onSurfaceVariant,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
