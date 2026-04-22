import 'package:flutter/material.dart';

import 'package:coqui_app/Models/coqui_project.dart';

class ProjectStatusBadge extends StatelessWidget {
  final CoquiProject project;

  const ProjectStatusBadge({
    super.key,
    required this.project,
  });

  @override
  Widget build(BuildContext context) {
    final (label, background, foreground) = switch (project.status) {
      'active' => (
          'Active',
          const Color(0xFFDDF6E8),
          const Color(0xFF1B7F43),
        ),
      'completed' => (
          'Completed',
          const Color(0xFFE7F0FF),
          const Color(0xFF2251C5),
        ),
      'archived' => (
          'Archived',
          Theme.of(context).colorScheme.surfaceContainerHighest,
          Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      _ => (
          project.status,
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
