import 'package:flutter/material.dart';

import 'package:coqui_app/Models/coqui_webhook.dart';
import 'package:coqui_app/Theme/coqui_colors.dart';

class WebhookStatusBadge extends StatelessWidget {
  final CoquiWebhook webhook;

  const WebhookStatusBadge({super.key, required this.webhook});

  @override
  Widget build(BuildContext context) {
    final (color, icon) = _statusStyle(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          webhook.statusLabel,
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
    return webhook.enabled
        ? (CoquiColors.chart2, Icons.cloud_done_outlined)
        : (cs.onSurfaceVariant, Icons.cloud_off_outlined);
  }
}
