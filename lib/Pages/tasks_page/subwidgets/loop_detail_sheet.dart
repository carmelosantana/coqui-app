import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:coqui_app/Models/coqui_loop.dart';
import 'package:coqui_app/Providers/loop_provider.dart';

import 'loop_status_badge.dart';

class LoopDetailSheet extends StatefulWidget {
  final CoquiLoop loop;

  const LoopDetailSheet({super.key, required this.loop});

  @override
  State<LoopDetailSheet> createState() => _LoopDetailSheetState();
}

class _LoopDetailSheetState extends State<LoopDetailSheet> {
  late CoquiLoop _loop;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _loop = widget.loop;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _refresh();
    });
  }

  Future<void> _refresh() async {
    setState(() => _isRefreshing = true);
    final provider = context.read<LoopProvider>();
    final detail = await provider.loadLoopDetail(_loop.id, force: true);
    await provider.refreshLoopIterations(_loop.id);
    if (mounted && detail != null) {
      setState(() => _loop = detail.loop);
    }
    if (mounted) {
      setState(() => _isRefreshing = false);
    }
  }

  Future<void> _pause() async {
    final updated = await context.read<LoopProvider>().pauseLoop(_loop.id);
    if (!mounted || updated == null) return;
    setState(() => _loop = updated);
  }

  Future<void> _resume() async {
    final updated = await context.read<LoopProvider>().resumeLoop(_loop.id);
    if (!mounted || updated == null) return;
    setState(() => _loop = updated);
  }

  Future<void> _stop() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Stop loop?'),
          content:
              Text('Cancel ${_loop.definitionName} and stop further stages?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep running'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Stop'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;

    final updated = await context.read<LoopProvider>().stopLoop(_loop.id);
    if (!mounted || updated == null) return;
    setState(() => _loop = updated);
  }

  Future<void> _openIterationDetail(CoquiLoopIteration iteration) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<LoopProvider>(),
        child:
            _LoopIterationDetailSheet(loopId: _loop.id, iteration: iteration),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.76,
      minChildSize: 0.48,
      maxChildSize: 0.96,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color:
                      theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _loop.definitionName,
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        LoopStatusBadge(loop: _loop),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _isRefreshing ? null : _refresh,
                    icon: _isRefreshing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh),
                  ),
                  if (_loop.isRunning)
                    IconButton(
                      onPressed: _pause,
                      tooltip: 'Pause',
                      icon: const Icon(Icons.pause_circle_outline),
                    ),
                  if (_loop.isPaused)
                    IconButton(
                      onPressed: _resume,
                      tooltip: 'Resume',
                      icon: const Icon(Icons.play_circle_outline),
                    ),
                  if (!_loop.isFinished)
                    IconButton(
                      onPressed: _stop,
                      tooltip: 'Stop',
                      color: theme.colorScheme.error,
                      icon: const Icon(Icons.stop_circle_outlined),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Consumer<LoopProvider>(
                builder: (context, provider, _) {
                  final detail = provider.detailById(_loop.id);
                  final iterations = provider.iterationsForLoop(_loop.id);
                  final currentStages =
                      detail?.stages ?? const <CoquiLoopStage>[];

                  return ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(20),
                    children: [
                      _InfoRow(label: 'Goal', value: _loop.goal),
                      _InfoRow(label: 'Status', value: _loop.statusLabel),
                      _InfoRow(
                        label: 'Iteration',
                        value: '${_loop.currentIteration}',
                      ),
                      _InfoRow(
                        label: 'Current stage',
                        value: '${_loop.currentStage}',
                      ),
                      if (_loop.maxIterations != null)
                        _InfoRow(
                          label: 'Max iterations',
                          value: '${_loop.maxIterations}',
                        ),
                      if (_loop.projectId?.isNotEmpty == true)
                        _InfoRow(label: 'Project', value: _loop.projectId!),
                      if (_loop.sessionId?.isNotEmpty == true)
                        _InfoRow(label: 'Session', value: _loop.sessionId!),
                      if (_loop.lastActivityAt != null)
                        _InfoRow(
                          label: 'Last activity',
                          value: _formatDateTime(_loop.lastActivityAt!),
                        ),
                      if (_loop.metadata.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _SectionLabel(label: 'Runtime Metadata'),
                        _ContentCard(text: _loop.metadata.toString()),
                      ],
                      if (detail?.iteration != null) ...[
                        const SizedBox(height: 16),
                        _SectionLabel(
                          label:
                              'Current Iteration ${detail!.iteration!.iterationNumber}',
                        ),
                        const SizedBox(height: 8),
                        _IterationSummaryCard(iteration: detail.iteration!),
                      ],
                      const SizedBox(height: 16),
                      _SectionLabel(label: 'Current Stage Flow'),
                      const SizedBox(height: 8),
                      if (currentStages.isEmpty)
                        const _EmptyCard(
                          label:
                              'No current stages are available yet. Refresh after the loop manager advances the definition.',
                        )
                      else
                        ...currentStages.map(
                          (stage) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _StageCard(stage: stage),
                          ),
                        ),
                      const SizedBox(height: 16),
                      _SectionLabel(label: 'Iteration History'),
                      const SizedBox(height: 8),
                      if (iterations.isEmpty)
                        const _EmptyCard(
                          label: 'No iterations recorded yet.',
                        )
                      else
                        ...iterations.map(
                          (iteration) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _IterationCard(
                              iteration: iteration,
                              onTap: () => _openIterationDetail(iteration),
                            ),
                          ),
                        ),
                      const SizedBox(height: 32),
                    ],
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  String _formatDateTime(DateTime dt) {
    final local = dt.toLocal();
    return '${local.year}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }
}

class _LoopIterationDetailSheet extends StatefulWidget {
  final String loopId;
  final CoquiLoopIteration iteration;

  const _LoopIterationDetailSheet({
    required this.loopId,
    required this.iteration,
  });

  @override
  State<_LoopIterationDetailSheet> createState() =>
      _LoopIterationDetailSheetState();
}

class _LoopIterationDetailSheetState extends State<_LoopIterationDetailSheet> {
  bool _isLoading = true;
  CoquiLoopIterationDetail? _detail;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final detail = await context.read<LoopProvider>().loadIterationDetail(
            widget.loopId,
            widget.iteration.id,
            force: true,
          );
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _isLoading = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.45,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color:
                      theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Iteration ${widget.iteration.iterationNumber}',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(20),
                      children: [
                        _IterationSummaryCard(iteration: widget.iteration),
                        const SizedBox(height: 16),
                        _SectionLabel(label: 'Stages'),
                        const SizedBox(height: 8),
                        if (_detail == null || _detail!.stages.isEmpty)
                          const _EmptyCard(
                            label:
                                'No stage detail recorded for this iteration.',
                          )
                        else
                          ..._detail!.stages.map(
                            (stage) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _StageCard(stage: stage),
                            ),
                          ),
                        const SizedBox(height: 24),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _IterationCard extends StatelessWidget {
  final CoquiLoopIteration iteration;
  final VoidCallback onTap;

  const _IterationCard({required this.iteration, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Iteration ${iteration.iterationNumber}',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  iteration.statusLabel,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
            if (iteration.outcomeSummary?.isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Text(
                iteration.outcomeSummary!,
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _IterationSummaryCard extends StatelessWidget {
  final CoquiLoopIteration iteration;

  const _IterationSummaryCard({required this.iteration});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Status: ${iteration.statusLabel}'),
          if (iteration.sprintId?.isNotEmpty == true) ...[
            const SizedBox(height: 6),
            Text('Sprint: ${iteration.sprintId}'),
          ],
          if (iteration.outcomeSummary?.isNotEmpty == true) ...[
            const SizedBox(height: 6),
            Text(iteration.outcomeSummary!),
          ],
        ],
      ),
    );
  }
}

class _StageCard extends StatelessWidget {
  final CoquiLoopStage stage;

  const _StageCard({required this.stage});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${stage.stageIndex + 1}. ${stage.role}',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              Text(stage.statusLabel, style: theme.textTheme.labelSmall),
            ],
          ),
          if (stage.resultSummary?.isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Text(stage.resultSummary!, style: theme.textTheme.bodySmall),
          ],
          if (stage.taskId?.isNotEmpty == true ||
              stage.artifactId?.isNotEmpty == true)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (stage.taskId?.isNotEmpty == true)
                    _StageChip(
                        icon: Icons.task_alt_outlined, label: stage.taskId!),
                  if (stage.artifactId?.isNotEmpty == true)
                    _StageChip(
                      icon: Icons.inventory_2_outlined,
                      label: stage.artifactId!,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _StageChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _StageChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final String label;

  const _EmptyCard({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Text(label, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;

  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context)
          .textTheme
          .titleSmall
          ?.copyWith(fontWeight: FontWeight.w600),
    );
  }
}

class _ContentCard extends StatelessWidget {
  final String text;

  const _ContentCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: SelectableText(text),
    );
  }
}
