import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:coqui_app/Models/coqui_task.dart';
import 'package:coqui_app/Providers/task_provider.dart';
import 'package:provider/provider.dart';
import 'task_status_badge.dart';

/// Bottom sheet showing full task details with actions.
class TaskDetailSheet extends StatefulWidget {
  final CoquiTask task;

  const TaskDetailSheet({super.key, required this.task});

  @override
  State<TaskDetailSheet> createState() => _TaskDetailSheetState();
}

class _TaskDetailSheetState extends State<TaskDetailSheet> {
  late CoquiTask _task;
  final _inputController = TextEditingController();
  bool _isSendingInput = false;
  bool _isCancelling = false;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _task = widget.task;
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() => _isRefreshing = true);
    final updated =
        await context.read<TaskProvider>().refreshTask(_task.id);
    if (mounted && updated != null) {
      setState(() => _task = updated);
    }
    if (mounted) setState(() => _isRefreshing = false);
  }

  Future<void> _cancel() async {
    setState(() => _isCancelling = true);
    await context.read<TaskProvider>().cancelTask(_task.id);
    if (mounted) {
      final updated =
          await context.read<TaskProvider>().refreshTask(_task.id);
      if (mounted && updated != null) setState(() => _task = updated);
      setState(() => _isCancelling = false);
    }
  }

  Future<void> _sendInput() async {
    final content = _inputController.text.trim();
    if (content.isEmpty) return;
    setState(() => _isSendingInput = true);
    await context.read<TaskProvider>().injectInput(_task.id, content);
    if (mounted) {
      _inputController.clear();
      setState(() => _isSendingInput = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Input sent to task'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Handle
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
            // Header row
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _task.displayTitle,
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        TaskStatusBadge(task: _task),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: _isRefreshing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh),
                    tooltip: 'Refresh',
                    onPressed: _isRefreshing ? null : _refresh,
                  ),
                  if (_task.isActive)
                    IconButton(
                      icon: _isCancelling
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.stop_circle_outlined),
                      tooltip: 'Cancel task',
                      color: theme.colorScheme.error,
                      onPressed: _isCancelling ? null : _cancel,
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Scrollable body
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(20),
                children: [
                  _InfoRow(label: 'Role', value: _task.role),
                  _InfoRow(label: 'Session', value: _task.sessionId),
                  _InfoRow(
                    label: 'Created',
                    value: _formatDateTime(_task.createdAt),
                  ),
                  if (_task.startedAt != null)
                    _InfoRow(
                      label: 'Started',
                      value: _formatDateTime(_task.startedAt!),
                    ),
                  if (_task.completedAt != null)
                    _InfoRow(
                      label: 'Finished',
                      value: _formatDateTime(_task.completedAt!),
                    ),
                  if (_task.isActive)
                    _InfoRow(label: 'Running for', value: _task.ageFormatted),
                  const SizedBox(height: 16),
                  _SectionLabel(label: 'Prompt'),
                  _ContentCard(text: _task.prompt),
                  if (_task.result != null && _task.result!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _SectionLabel(label: 'Result'),
                    _ContentCard(text: _task.result!),
                  ],
                  if (_task.error != null && _task.error!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _SectionLabel(label: 'Error'),
                    _ContentCard(
                      text: _task.error!,
                      isError: true,
                    ),
                  ],
                  // Input injection for running tasks
                  if (_task.isRunning) ...[
                    const SizedBox(height: 24),
                    _SectionLabel(label: 'Send Input to Task'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _inputController,
                            decoration: const InputDecoration(
                              hintText: 'Send additional instructions…',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            maxLines: 3,
                            minLines: 1,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _sendInput(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          icon: _isSendingInput
                              ? SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Theme.of(context).colorScheme.onPrimary),
                                )
                              : const Icon(Icons.send),
                          onPressed: _isSendingInput ? null : _sendInput,
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 40),
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
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodySmall,
            ),
          ),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _ContentCard extends StatelessWidget {
  final String text;
  final bool isError;

  const _ContentCard({required this.text, this.isError = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor = isError
        ? theme.colorScheme.errorContainer
        : theme.colorScheme.surfaceContainerHighest;
    final textColor = isError
        ? theme.colorScheme.onErrorContainer
        : theme.colorScheme.onSurface;

    final borderColor = isError
        ? theme.colorScheme.error.withValues(alpha: 0.4)
        : theme.dividerColor;

    return GestureDetector(
      onLongPress: () {
        Clipboard.setData(ClipboardData(text: text));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Copied to clipboard'),
            duration: Duration(seconds: 2),
          ),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor),
        ),
        child: Text(
          text,
          style: theme.textTheme.bodySmall?.copyWith(color: textColor),
        ),
      ),
    );
  }
}
