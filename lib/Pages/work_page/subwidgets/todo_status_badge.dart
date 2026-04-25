import 'package:flutter/material.dart';

import 'package:coqui_app/Models/coqui_todo.dart';

class TodoStatusBadge extends StatelessWidget {
  final CoquiTodo todo;

  const TodoStatusBadge({
    super.key,
    required this.todo,
  });

  @override
  Widget build(BuildContext context) {
    final (label, background, foreground) = switch (todo.status) {
      'pending' => (
          'Pending',
          Theme.of(context).colorScheme.surfaceContainerHighest,
          Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      'in_progress' => (
          'In Progress',
          const Color(0xFFFFF1D8),
          const Color(0xFF9A5E00),
        ),
      'completed' => (
          'Completed',
          const Color(0xFFDDF6E8),
          const Color(0xFF1B7F43),
        ),
      'cancelled' => (
          'Cancelled',
          const Color(0xFFFFE0DF),
          const Color(0xFFB3261E),
        ),
      _ => (
          todo.status,
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
