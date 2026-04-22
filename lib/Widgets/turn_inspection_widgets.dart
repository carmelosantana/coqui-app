import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import 'package:coqui_app/Models/agent_activity_event.dart';
import 'package:coqui_app/Models/coqui_turn.dart';

class TurnActivityPanel extends StatelessWidget {
  final List<AgentActivityEvent> activity;
  final bool isActive;
  final String title;
  final String emptyLabel;

  const TurnActivityPanel({
    super.key,
    required this.activity,
    this.isActive = false,
    this.title = 'Agent Activity',
    this.emptyLabel = 'No activity recorded for this turn.',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(
          color: theme.colorScheme.outlineVariant,
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (isActive)
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: theme.colorScheme.primary,
                  ),
                )
              else
                Icon(
                  Icons.history_outlined,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
              const SizedBox(width: 8),
              Text(
                title,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (activity.isEmpty)
            Text(
              emptyLabel,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else
            ...activity.map((event) => _ActivityEventRow(event: event)),
        ],
      ),
    );
  }
}

class TurnSummaryCard extends StatelessWidget {
  final CoquiTurn turn;
  final String title;

  const TurnSummaryCard({
    super.key,
    required this.turn,
    this.title = 'Turn Summary',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final usage = turn.contextUsage;
    final usageValue = usage == null
        ? null
        : (usage.usagePercent / 100).clamp(0.0, 1.0).toDouble();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant,
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                turn.error != null ? Icons.error_outline : Icons.insights_outlined,
                size: 18,
                color: turn.error != null
                    ? theme.colorScheme.error
                    : theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (turn.turnNumber > 0)
                Text(
                  '#${turn.turnNumber}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          if (turn.summary.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              turn.summary,
              style: theme.textTheme.bodyMedium,
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetadataChip(
                icon: Icons.token_outlined,
                label: turn.totalTokens > 0
                    ? '${turn.totalTokens} tokens'
                    : 'No token usage',
              ),
              _MetadataChip(
                icon: Icons.schedule_outlined,
                label: turn.durationMs > 0 ? turn.durationFormatted : 'No duration',
              ),
              _MetadataChip(
                icon: Icons.loop_outlined,
                label: turn.iterations > 0
                    ? '${turn.iterations} iteration${turn.iterations == 1 ? '' : 's'}'
                    : 'Single pass',
              ),
              if (turn.toolsUsed.isNotEmpty)
                _MetadataChip(
                  icon: Icons.build_outlined,
                  label: turn.toolsUsed.join(', '),
                ),
              if (turn.childAgentCount > 0)
                _MetadataChip(
                  icon: Icons.account_tree_outlined,
                  label:
                      '${turn.childAgentCount} child ${turn.childAgentCount == 1 ? 'agent' : 'agents'}',
                ),
              if (turn.model.isNotEmpty)
                _MetadataChip(
                  icon: Icons.memory_outlined,
                  label: turn.model,
                ),
            ],
          ),
          if (usage != null) ...[
            const SizedBox(height: 14),
            Text(
              'Context Usage',
              style: theme.textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                minHeight: 8,
                value: usageValue,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${usage.usedTokens}/${usage.effectiveBudget} tokens used (${usage.usagePercent.toStringAsFixed(1)}%)',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (usage.breakdown.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: usage.breakdown.entries
                    .where((entry) => entry.value > 0)
                    .map(
                      (entry) => _MetadataChip(
                        icon: Icons.stacked_bar_chart_outlined,
                        label: '${entry.key}: ${entry.value}',
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
          if (turn.fileEdits.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              'File Edits',
              style: theme.textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            ...turn.fileEdits.map(
              (edit) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.edit_note_outlined,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${edit.operation.toUpperCase()} ${p.basename(edit.filePath)}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (turn.backgroundTasks != null &&
              turn.backgroundTasks!.totalCount > 0) ...[
            const SizedBox(height: 14),
            Text(
              'Background Tasks',
              style: theme.textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            Text(
              '${turn.backgroundTasks!.totalCount} task${turn.backgroundTasks!.totalCount == 1 ? '' : 's'} launched',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            ...turn.backgroundTasks!.agents.map(
              (task) => _TaskRow(
                icon: Icons.smart_toy_outlined,
                title: task.title,
                subtitle: task.role ?? task.status,
              ),
            ),
            ...turn.backgroundTasks!.tools.map(
              (task) => _TaskRow(
                icon: Icons.handyman_outlined,
                title: task.title,
                subtitle: task.toolName ?? task.status,
              ),
            ),
          ],
          if (turn.reviewFeedback != null && turn.reviewFeedback!.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              'Review Feedback',
              style: theme.textTheme.labelLarge,
            ),
            const SizedBox(height: 6),
            Text(
              turn.reviewFeedback!,
              style: theme.textTheme.bodySmall,
            ),
          ],
          if (_statusFlags(turn).isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _statusFlags(turn)
                  .map((label) => _MetadataChip(icon: Icons.flag_outlined, label: label))
                  .toList(),
            ),
          ],
          if (turn.error != null && turn.error!.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                turn.error!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onErrorContainer,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<String> _statusFlags(CoquiTurn turn) {
    final flags = <String>[];
    if (turn.restartRequested) flags.add('Restart requested');
    if (turn.iterationLimitReached) flags.add('Iteration limit reached');
    if (turn.budgetExhausted) flags.add('Budget exhausted');
    if (turn.reviewApproved == true) flags.add('Review approved');
    if (turn.reviewApproved == false) flags.add('Review changes requested');
    return flags;
  }
}

class _ActivityEventRow extends StatelessWidget {
  final AgentActivityEvent event;

  const _ActivityEventRow({required this.event});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            _iconForType(event.type),
            size: 14,
            color: _colorForType(theme, event.type),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              event.description,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconForType(AgentActivityType type) {
    return switch (type) {
      AgentActivityType.start => Icons.play_arrow_rounded,
      AgentActivityType.iteration => Icons.loop_rounded,
      AgentActivityType.toolCall => Icons.build_rounded,
      AgentActivityType.toolResult => Icons.check_circle_outline,
      AgentActivityType.childStart => Icons.account_tree_rounded,
      AgentActivityType.childEnd => Icons.account_tree_rounded,
      AgentActivityType.error => Icons.error_outline,
      AgentActivityType.warning => Icons.warning_amber_rounded,
      AgentActivityType.info => Icons.info_outline,
    };
  }

  Color _colorForType(ThemeData theme, AgentActivityType type) {
    return switch (type) {
      AgentActivityType.error => theme.colorScheme.error,
      AgentActivityType.toolCall => theme.colorScheme.tertiary,
      AgentActivityType.toolResult => theme.colorScheme.primary,
      _ => theme.colorScheme.onSurfaceVariant,
    };
  }
}

class _MetadataChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetadataChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;

  const _TaskRow({
    required this.icon,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.bodySmall),
                if (subtitle != null && subtitle!.isNotEmpty)
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
