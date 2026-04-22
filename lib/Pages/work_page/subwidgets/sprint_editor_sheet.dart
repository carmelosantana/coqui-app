import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:coqui_app/Models/coqui_sprint.dart';
import 'package:coqui_app/Providers/project_provider.dart';

class SprintEditorSheet extends StatefulWidget {
  final String projectId;
  final CoquiSprint? sprint;
  final String? suggestedSessionId;

  const SprintEditorSheet({
    super.key,
    required this.projectId,
    this.sprint,
    this.suggestedSessionId,
  });

  @override
  State<SprintEditorSheet> createState() => _SprintEditorSheetState();
}

class _SprintEditorSheetState extends State<SprintEditorSheet> {
  final _titleController = TextEditingController();
  final _acceptanceCriteriaController = TextEditingController();
  late final TextEditingController _maxReviewRoundsController;

  bool get _isEditing => widget.sprint != null;

  @override
  void initState() {
    super.initState();
    final sprint = widget.sprint;
    _titleController.text = sprint?.title ?? '';
    _acceptanceCriteriaController.text = sprint?.acceptanceCriteria ?? '';
    _maxReviewRoundsController = TextEditingController(
      text: '${sprint?.maxReviewRounds ?? 3}',
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _acceptanceCriteriaController.dispose();
    _maxReviewRoundsController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final provider = context.read<ProjectProvider>();
    final title = _titleController.text.trim();
    final acceptanceCriteria = _acceptanceCriteriaController.text.trim();
    final maxReviewRounds = int.tryParse(_maxReviewRoundsController.text) ?? 3;

    if (title.isEmpty) {
      _showSnack('Please enter a sprint title');
      return;
    }

    if (maxReviewRounds < 1) {
      _showSnack('Max review rounds must be at least 1');
      return;
    }

    final result = _isEditing
        ? await provider.updateSprint(
            widget.sprint!.id,
            title: title,
            acceptanceCriteria:
                acceptanceCriteria.isEmpty ? '' : acceptanceCriteria,
            lastSessionId: widget.suggestedSessionId,
            maxReviewRounds: maxReviewRounds,
          )
        : await provider.createSprint(
            projectIdOrSlug: widget.projectId,
            title: title,
            acceptanceCriteria:
                acceptanceCriteria.isEmpty ? null : acceptanceCriteria,
            lastSessionId: widget.suggestedSessionId,
            maxReviewRounds: maxReviewRounds,
          );

    if (!mounted) return;
    if (result != null) {
      Navigator.pop(context, result);
    } else {
      _showSnack(provider.error ?? 'Unable to save sprint');
      provider.clearError();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.62,
        minChildSize: 0.48,
        maxChildSize: 0.86,
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
                    Text(
                      _isEditing ? 'Edit Sprint' : 'New Sprint',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    Consumer<ProjectProvider>(
                      builder: (context, provider, _) {
                        final busy = _isEditing
                            ? provider.isSprintMutating(widget.sprint!.id)
                            : provider.isProjectMutating(widget.projectId);
                        return FilledButton(
                          onPressed: busy ? null : _save,
                          child: busy
                              ? SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: theme.colorScheme.onPrimary,
                                  ),
                                )
                              : Text(_isEditing ? 'Save' : 'Create'),
                        );
                      },
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
                    TextField(
                      controller: _titleController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Title',
                        hintText: 'MVP Sprint',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _acceptanceCriteriaController,
                      minLines: 4,
                      maxLines: 8,
                      decoration: const InputDecoration(
                        labelText: 'Acceptance Criteria',
                        hintText:
                            'Core app shell is navigable and the next workflow is wired end to end.',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _maxReviewRoundsController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Max Review Rounds',
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
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
