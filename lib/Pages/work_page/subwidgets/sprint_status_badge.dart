import 'package:flutter/material.dart';

import 'package:coqui_app/Models/coqui_sprint.dart';

class SprintStatusBadge extends StatelessWidget {
  final CoquiSprint sprint;

  const SprintStatusBadge({
    super.key,
    required this.sprint,
  });

  @override
  Widget build(BuildContext context) {
    final (label, background, foreground) = switch (sprint.status) {
      'planned' => (
          'Planned',
          Theme.of(context).colorScheme.surfaceContainerHighest,
          Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      'in_progress' => (
          'In Progress',
          const Color(0xFFFFF1D8),
          const Color(0xFF9A5E00),
        ),
      'review' => (
          'Review',
          const Color(0xFFEDE6FF),
          const Color(0xFF6C39C7),
        ),
      'complete' => (
          'Complete',
          const Color(0xFFDDF6E8),
          const Color(0xFF1B7F43),
        ),
      'rejected' => (
          'Rejected',
          const Color(0xFFFFE0DF),
          const Color(0xFFB3261E),
        ),
      _ => (
          sprint.status,
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
