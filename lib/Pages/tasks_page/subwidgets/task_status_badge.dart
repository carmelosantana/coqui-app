import 'package:flutter/material.dart';
import 'package:coqui_app/Models/coqui_task.dart';
import 'package:coqui_app/Theme/coqui_colors.dart';

class TaskStatusBadge extends StatelessWidget {
  final CoquiTask task;

  const TaskStatusBadge({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    final (color, icon) = _statusStyle(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          task.statusLabel,
          style: Theme.of(context)
              .textTheme
              .labelSmall
              ?.copyWith(color: color, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  (Color, IconData) _statusStyle(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return switch (task.status) {
      'pending' => (cs.onSurfaceVariant, Icons.schedule_outlined),
      'running' => (CoquiColors.chart2, Icons.play_circle_outline),
      'cancelling' => (Colors.orange, Icons.stop_circle_outlined),
      'completed' => (CoquiColors.chart3, Icons.check_circle_outline),
      'failed' => (cs.error, Icons.error_outline),
      'cancelled' => (cs.onSurfaceVariant, Icons.cancel_outlined),
      _ => (cs.onSurfaceVariant, Icons.help_outline),
    };
  }
}
