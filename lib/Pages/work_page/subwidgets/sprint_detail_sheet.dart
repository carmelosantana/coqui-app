import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:coqui_app/Models/coqui_sprint.dart';
import 'package:coqui_app/Providers/project_provider.dart';

import 'sprint_editor_sheet.dart';
import 'sprint_status_badge.dart';

class SprintDetailSheet extends StatefulWidget {
  final CoquiSprint sprint;

  const SprintDetailSheet({
    super.key,
    required this.sprint,
  });

  @override
  State<SprintDetailSheet> createState() => _SprintDetailSheetState();
}

class _SprintDetailSheetState extends State<SprintDetailSheet> {
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refresh(force: true);
    });
  }

  Future<void> _refresh({bool force = false}) async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    await context
        .read<ProjectProvider>()
        .loadSprintDetail(widget.sprint.id, force: force);
    if (mounted) {
      setState(() => _isRefreshing = false);
    }
  }

  Future<void> _edit(CoquiSprint sprint) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<ProjectProvider>(),
        child: SprintEditorSheet(
          projectId: sprint.projectId,
          sprint: sprint,
        ),
      ),
    );
    if (mounted) {
      await _refresh(force: true);
    }
  }

  Future<void> _transition(
    Future<CoquiSprint?> Function() action,
    String successMessage,
  ) async {
    final provider = context.read<ProjectProvider>();
    final result = await action();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result != null
              ? successMessage
              : provider.error ?? 'Unable to update sprint',
        ),
      ),
    );
  }

  Future<void> _reject(CoquiSprint sprint) async {
    final controller = TextEditingController(text: sprint.reviewerNotes ?? '');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Sprint'),
        content: TextField(
          controller: controller,
          minLines: 3,
          maxLines: 6,
          decoration: const InputDecoration(
            labelText: 'Reviewer Notes',
            hintText: 'Capture why the sprint needs another pass.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    await _transition(
      () => context.read<ProjectProvider>().rejectSprint(
            sprint.id,
            reviewerNotes:
                controller.text.trim().isEmpty ? null : controller.text.trim(),
          ),
      'Sprint rejected.',
    );
  }

  Future<void> _delete(CoquiSprint sprint) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${sprint.label}?'),
        content: const Text('Only planned sprints can be deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final provider = context.read<ProjectProvider>();
    final success = await provider.deleteSprint(sprint.id);
    if (!mounted) return;
    if (success) {
      Navigator.pop(context);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Sprint deleted.'
              : provider.error ?? 'Unable to delete sprint',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Consumer<ProjectProvider>(
      builder: (context, provider, _) {
        final sprint = provider.sprintById(widget.sprint.id) ?? widget.sprint;
        final project = provider.projectById(sprint.projectId);
        final isReadOnly = sprint.isReadOnlyInApp;

        return SafeArea(
          child: DraggableScrollableSheet(
            initialChildSize: 0.8,
            minChildSize: 0.58,
            maxChildSize: 0.94,
            expand: false,
            builder: (context, scrollController) {
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 8),
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            sprint.label,
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        IconButton(
                          onPressed: _isRefreshing
                              ? null
                              : () => _refresh(force: true),
                          icon: _isRefreshing
                              ? SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: theme.colorScheme.primary,
                                  ),
                                )
                              : const Icon(Icons.refresh),
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
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            SprintStatusBadge(sprint: sprint),
                            if (project != null)
                              _InfoChip(label: project.label),
                            if (sprint.reviewRound > 0)
                              _InfoChip(
                                label:
                                    'Review ${sprint.reviewRound}/${sprint.maxReviewRounds}',
                              ),
                          ],
                        ),
                        if (sprint.hasAcceptanceCriteria) ...[
                          const SizedBox(height: 16),
                          Text(
                            sprint.acceptanceCriteria!,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                        if (sprint.reviewerNotes?.isNotEmpty == true) ...[
                          const SizedBox(height: 16),
                          _SectionCard(
                            title: 'Reviewer Notes',
                            child: Text(
                              sprint.reviewerNotes!,
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                        ],
                        if (isReadOnly) ...[
                          const SizedBox(height: 16),
                          _SectionCard(
                            title: 'Read Only',
                            child: Text(
                              'Completed sprints are view-only in the app to avoid accidental changes after delivery.',
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        _SectionCard(
                          title: 'Sprint Actions',
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              FilledButton.tonalIcon(
                                onPressed:
                                    isReadOnly ? null : () => _edit(sprint),
                                icon: const Icon(Icons.edit_outlined),
                                label: const Text('Edit'),
                              ),
                              FilledButton.tonalIcon(
                                onPressed: sprint.canStart
                                    ? () => _transition(
                                          () => provider.startSprint(sprint.id),
                                          'Sprint started.',
                                        )
                                    : null,
                                icon: const Icon(Icons.play_arrow_outlined),
                                label: const Text('Start'),
                              ),
                              FilledButton.tonalIcon(
                                onPressed: sprint.canSubmitReview
                                    ? () => _transition(
                                          () => provider
                                              .submitSprintReview(sprint.id),
                                          'Sprint submitted for review.',
                                        )
                                    : null,
                                icon: const Icon(Icons.rate_review_outlined),
                                label: const Text('Submit Review'),
                              ),
                              FilledButton.tonalIcon(
                                onPressed: sprint.canComplete
                                    ? () => _transition(
                                          () => provider
                                              .completeSprint(sprint.id),
                                          'Sprint completed.',
                                        )
                                    : null,
                                icon: const Icon(Icons.check_circle_outline),
                                label: const Text('Complete'),
                              ),
                              FilledButton.tonalIcon(
                                onPressed: sprint.canReject
                                    ? () => _reject(sprint)
                                    : null,
                                icon: const Icon(Icons.cancel_outlined),
                                label: const Text('Reject'),
                              ),
                              OutlinedButton.icon(
                                onPressed: sprint.canDelete
                                    ? () => _delete(sprint)
                                    : null,
                                icon: const Icon(Icons.delete_outline),
                                label: const Text('Delete'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;

  const _InfoChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelSmall),
    );
  }
}
