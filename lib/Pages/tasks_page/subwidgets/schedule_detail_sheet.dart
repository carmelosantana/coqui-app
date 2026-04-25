import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:coqui_app/Models/coqui_schedule.dart';
import 'package:coqui_app/Providers/schedule_provider.dart';

import 'schedule_editor_sheet.dart';
import 'schedule_status_badge.dart';

class ScheduleDetailSheet extends StatefulWidget {
  final CoquiSchedule schedule;

  const ScheduleDetailSheet({super.key, required this.schedule});

  @override
  State<ScheduleDetailSheet> createState() => _ScheduleDetailSheetState();
}

class _ScheduleDetailSheetState extends State<ScheduleDetailSheet> {
  late CoquiSchedule _schedule;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _schedule = widget.schedule;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _refresh();
    });
  }

  Future<void> _refresh() async {
    setState(() => _isRefreshing = true);
    final updated = await context
        .read<ScheduleProvider>()
        .loadScheduleDetail(_schedule.id, force: true);
    if (mounted && updated != null) {
      setState(() => _schedule = updated);
    }
    if (mounted) {
      setState(() => _isRefreshing = false);
    }
  }

  Future<void> _openEditor() async {
    final updated = await showModalBottomSheet<CoquiSchedule>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<ScheduleProvider>(),
        child: ScheduleEditorSheet(schedule: _schedule),
      ),
    );
    if (!mounted || updated == null) return;
    setState(() => _schedule = updated);
  }

  Future<void> _toggleEnabled() async {
    final updated = await context
        .read<ScheduleProvider>()
        .setScheduleEnabled(_schedule.id, !_schedule.enabled);
    if (!mounted || updated == null) return;
    setState(() => _schedule = updated);
  }

  Future<void> _trigger() async {
    final updated = await context.read<ScheduleProvider>().triggerSchedule(
          _schedule.id,
        );
    if (!mounted || updated == null) return;

    setState(() => _schedule = updated);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Schedule queued for the next scheduler tick')),
    );
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete schedule?'),
          content: Text(
              'Delete ${_schedule.name} from the API-managed schedule list?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;

    final deleted =
        await context.read<ScheduleProvider>().deleteSchedule(_schedule.id);
    if (!mounted) return;

    if (deleted) {
      Navigator.pop(context, true);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.read<ScheduleProvider>().error ??
              'Unable to delete schedule.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMutable = !_schedule.isFilesystemSource;
    return DraggableScrollableSheet(
      initialChildSize: 0.74,
      minChildSize: 0.45,
      maxChildSize: 0.94,
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
                          _schedule.name,
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        ScheduleStatusBadge(schedule: _schedule),
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
                  IconButton(
                    onPressed: _trigger,
                    tooltip: 'Trigger now',
                    icon: const Icon(Icons.play_circle_outline),
                  ),
                  IconButton(
                    onPressed: _toggleEnabled,
                    tooltip: _schedule.enabled ? 'Disable' : 'Enable',
                    icon: Icon(
                      _schedule.enabled
                          ? Icons.pause_circle_outline
                          : Icons.play_circle_outline,
                    ),
                  ),
                  if (isMutable)
                    IconButton(
                      onPressed: _openEditor,
                      tooltip: 'Edit',
                      icon: const Icon(Icons.edit_outlined),
                    ),
                  if (isMutable)
                    IconButton(
                      onPressed: _delete,
                      tooltip: 'Delete',
                      color: theme.colorScheme.error,
                      icon: const Icon(Icons.delete_outline),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(20),
                children: [
                  _InfoRow(label: 'Source', value: _schedule.sourceLabel),
                  _InfoRow(
                      label: 'Expression', value: _schedule.scheduleExpression),
                  _InfoRow(label: 'Role', value: _schedule.role),
                  _InfoRow(label: 'Timezone', value: _schedule.timezone),
                  _InfoRow(
                    label: 'Max iterations',
                    value: '${_schedule.maxIterations}',
                  ),
                  _InfoRow(
                    label: 'Failure limit',
                    value: '${_schedule.maxFailures}',
                  ),
                  _InfoRow(label: 'Runs', value: '${_schedule.runCount}'),
                  _InfoRow(
                    label: 'Failures',
                    value: '${_schedule.failureCount}',
                  ),
                  if (_schedule.createdBy?.isNotEmpty == true)
                    _InfoRow(label: 'Created by', value: _schedule.createdBy!),
                  if (_schedule.nextRunAt != null)
                    _InfoRow(
                      label: 'Next run',
                      value: _formatDateTime(_schedule.nextRunAt!),
                    ),
                  if (_schedule.lastRunAt != null)
                    _InfoRow(
                      label: 'Last run',
                      value: _formatDateTime(_schedule.lastRunAt!),
                    ),
                  if (_schedule.lastStatus?.isNotEmpty == true)
                    _InfoRow(
                        label: 'Last status', value: _schedule.lastStatus!),
                  if (_schedule.isFilesystemSource) ...[
                    const SizedBox(height: 16),
                    _SectionLabel(label: 'Read-only source'),
                    _ContentCard(
                      text: _schedule.sourcePath ??
                          'This schedule is backed by a workspace JSON file.',
                      subtitle:
                          'Edit or delete it in the workspace file instead of from the app.',
                    ),
                  ],
                  if (_schedule.hasDescription) ...[
                    const SizedBox(height: 16),
                    _SectionLabel(label: 'Description'),
                    _ContentCard(text: _schedule.description!),
                  ],
                  const SizedBox(height: 16),
                  _SectionLabel(label: 'Prompt'),
                  _ContentCard(text: _schedule.prompt),
                  const SizedBox(height: 32),
                ],
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
  final String? subtitle;

  const _ContentCard({required this.text, this.subtitle});

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText(text),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle!,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}
