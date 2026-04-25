import 'package:flutter/material.dart';

import 'package:coqui_app/Models/coqui_channel.dart';
import 'package:coqui_app/Theme/coqui_colors.dart';

class ChannelStatusBadge extends StatelessWidget {
  final CoquiChannel channel;

  const ChannelStatusBadge({
    super.key,
    required this.channel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final styles = _statusStyles(theme);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: styles.background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: styles.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(styles.icon, size: 14, color: styles.foreground),
          const SizedBox(width: 6),
          Text(
            channel.statusLabel,
            style: theme.textTheme.labelSmall?.copyWith(
              color: styles.foreground,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  _BadgeStyles _statusStyles(ThemeData theme) {
    if (channel.isHealthy) {
      return _BadgeStyles(
        background: CoquiColors.chart3.withValues(alpha: 0.12),
        border: CoquiColors.chart3.withValues(alpha: 0.3),
        foreground: CoquiColors.chart3,
        icon: Icons.check_circle_outline,
      );
    }
    if (channel.isDisabled) {
      return _BadgeStyles(
        background: theme.colorScheme.secondary.withValues(alpha: 0.8),
        border: theme.dividerColor,
        foreground: theme.colorScheme.onSurfaceVariant,
        icon: Icons.pause_circle_outline,
      );
    }
    if (channel.isPlaceholder) {
      return _BadgeStyles(
        background: theme.colorScheme.secondary.withValues(alpha: 0.8),
        border: theme.dividerColor,
        foreground: theme.colorScheme.onSurfaceVariant,
        icon: Icons.architecture_outlined,
      );
    }
    if (channel.workerStatus == 'running') {
      return _BadgeStyles(
        background: CoquiColors.warning.withValues(alpha: 0.12),
        border: CoquiColors.warning.withValues(alpha: 0.3),
        foreground: CoquiColors.warning,
        icon: Icons.sync_outlined,
      );
    }
    return _BadgeStyles(
      background: theme.colorScheme.error.withValues(alpha: 0.12),
      border: theme.colorScheme.error.withValues(alpha: 0.3),
      foreground: theme.colorScheme.error,
      icon: Icons.error_outline,
    );
  }
}

class _BadgeStyles {
  final Color background;
  final Color border;
  final Color foreground;
  final IconData icon;

  const _BadgeStyles({
    required this.background,
    required this.border,
    required this.foreground,
    required this.icon,
  });
}