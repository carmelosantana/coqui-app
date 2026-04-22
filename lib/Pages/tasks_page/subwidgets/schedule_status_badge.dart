import 'package:flutter/material.dart';

import 'package:coqui_app/Models/coqui_schedule.dart';
import 'package:coqui_app/Theme/coqui_colors.dart';

class ScheduleStatusBadge extends StatelessWidget {
  final CoquiSchedule schedule;

  const ScheduleStatusBadge({super.key, required this.schedule});

  @override
  Widget build(BuildContext context) {
    final (color, icon) = _statusStyle(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          schedule.statusLabel,
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
    return schedule.enabled
        ? (CoquiColors.chart2, Icons.schedule_send_outlined)
        : (cs.onSurfaceVariant, Icons.schedule_outlined);
  }
}
