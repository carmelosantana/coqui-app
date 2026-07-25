import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:coqui_app/Models/coqui_loop.dart';
import 'package:coqui_app/Pages/shell/shell_controller.dart';
import 'package:coqui_app/Theme/coqui_tokens.dart';
import 'package:coqui_app/Theme/coqui_typography.dart';

/// Presentational inline card summarising a multi-role agent [CoquiLoop].
///
/// Renders a header (status dot + name + role chain + `ITER n/N`) and a stage
/// stepper whose nodes are derived from [CoquiLoop.currentStage]: done nodes
/// (index `< currentStage`) are filled green, the active node (`== currentStage`)
/// is filled lime, and pending nodes (`> currentStage`) are outlined. Tapping the
/// card opens the loop monitor via [ShellController.openLoopPanel].
class LoopCard extends StatelessWidget {
  const LoopCard({
    super.key,
    required this.loop,
    required this.definition,
  });

  final CoquiLoop loop;
  final CoquiLoopDefinition definition;

  Color _statusColor() {
    switch (loop.status) {
      case 'running':
        return CoquiTokens.brand.primaryLime;
      case 'done':
      case 'complete':
      case 'completed':
        return CoquiTokens.status.online;
      case 'error':
      case 'failed':
        return CoquiTokens.status.error;
      default:
        return CoquiTokens.text.muted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final roles = definition.roles;
    final title = definition.name.isNotEmpty
        ? definition.name
        : loop.definitionName;
    final roleChain = roles.map((r) => r.role).join(' → ');
    final iterLabel =
        'ITER ${loop.currentIteration}/${loop.maxIterations ?? '∞'}';

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => context.read<ShellController>().openLoopPanel(loop.id),
      child: Container(
        decoration: BoxDecoration(
          color: CoquiTokens.surface.card,
          border: Border.all(color: CoquiTokens.border.loopCard),
          borderRadius: BorderRadius.circular(CoquiTokens.radii.card),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _statusColor(),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: CoquiTokens.text.high,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (roleChain.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      roleChain,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: CoquiTypography.mono(color: CoquiTokens.text.muted),
                    ),
                  ),
                ],
                const SizedBox(width: 8),
                Text(
                  iterLabel,
                  style: CoquiTypography.mono(color: CoquiTokens.text.muted),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _StageStepper(roles: roles, currentStage: loop.currentStage),
          ],
        ),
      ),
    );
  }
}

/// Horizontal stepper: one node per role connected by 2px bars, with the role
/// name in small mono beneath each node.
class _StageStepper extends StatelessWidget {
  const _StageStepper({required this.roles, required this.currentStage});

  final List<CoquiLoopRoleStep> roles;
  final int currentStage;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var i = 0; i < roles.length; i++) {
      if (i > 0) {
        children.add(
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Container(
                height: 2,
                color: i <= currentStage
                    ? CoquiTokens.status.online
                    : CoquiTokens.border.loopCard,
              ),
            ),
          ),
        );
      }
      children.add(_StageNode(index: i, role: roles[i].role, currentStage: currentStage));
    }

    return Row(
      key: const ValueKey('loop-stepper'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}

class _StageNode extends StatelessWidget {
  const _StageNode({
    required this.index,
    required this.role,
    required this.currentStage,
  });

  final int index;
  final String role;
  final int currentStage;

  @override
  Widget build(BuildContext context) {
    final bool isDone = index < currentStage;
    final bool isActive = index == currentStage;

    late final Color fill;
    Border? border;
    if (isDone) {
      fill = CoquiTokens.status.online;
    } else if (isActive) {
      fill = CoquiTokens.brand.primaryLime;
    } else {
      fill = Colors.transparent;
      border = Border.all(color: CoquiTokens.border.loopCard, width: 2);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          key: ValueKey('loop-stage-$index'),
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: fill,
            shape: BoxShape.circle,
            border: border,
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: 56,
          child: Text(
            role,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: CoquiTypography.mono(
              size: 9,
              color: isActive ? CoquiTokens.text.body : CoquiTokens.text.muted,
            ),
          ),
        ),
      ],
    );
  }
}
