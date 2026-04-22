import 'package:flutter/material.dart';

import 'package:coqui_app/Models/coqui_loop.dart';
import 'package:coqui_app/Theme/coqui_colors.dart';

class LoopStatusBadge extends StatelessWidget {
  final CoquiLoop loop;

  const LoopStatusBadge({super.key, required this.loop});

  @override
  Widget build(BuildContext context) {
    final (color, icon) = _statusStyle(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          loop.statusLabel,
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
    return switch (loop.status) {
      'running' => (CoquiColors.chart2, Icons.play_circle_outline),
      'paused' => (CoquiColors.warning, Icons.pause_circle_outline),
      'completed' => (CoquiColors.chart2, Icons.check_circle_outline),
      'failed' => (cs.error, Icons.error_outline),
      'cancelled' => (cs.onSurfaceVariant, Icons.stop_circle_outlined),
      _ => (cs.onSurfaceVariant, Icons.loop_outlined),
    };
  }
}
