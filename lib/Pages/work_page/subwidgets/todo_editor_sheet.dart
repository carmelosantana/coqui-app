import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:coqui_app/Models/coqui_artifact.dart';
import 'package:coqui_app/Models/coqui_sprint.dart';
import 'package:coqui_app/Models/coqui_todo.dart';
import 'package:coqui_app/Providers/work_provider.dart';

class TodoEditorSheet extends StatefulWidget {
  final String sessionId;
  final CoquiTodo? todo;
  final List<CoquiSprint> availableSprints;
  final List<CoquiArtifact> availableArtifacts;
  final String? initialSprintId;

  const TodoEditorSheet({
    super.key,
    required this.sessionId,
    required this.availableSprints,
    required this.availableArtifacts,
    this.todo,
    this.initialSprintId,
  });

  @override
  State<TodoEditorSheet> createState() => _TodoEditorSheetState();
}

class _TodoEditorSheetState extends State<TodoEditorSheet> {
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();
  String _priority = 'medium';
  String? _selectedSprintId;
  String? _selectedArtifactId;

  bool get _isEditing => widget.todo != null;

  @override
  void initState() {
    super.initState();
    final todo = widget.todo;
    _titleController.text = todo?.title ?? '';
    _notesController.text = todo?.notes ?? '';
    _priority = todo?.priority ?? 'medium';
    _selectedSprintId = todo?.sprintId ?? widget.initialSprintId;
    _selectedArtifactId = todo?.artifactId;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final provider = context.read<WorkProvider>();
    final title = _titleController.text.trim();
    final notes = _notesController.text.trim();

    if (title.isEmpty) {
      _showSnack('Please enter a todo title');
      return;
    }

    final result = _isEditing
        ? await provider.updateTodo(
            widget.sessionId,
            widget.todo!.id,
            title: title,
            priority: _priority,
            notes: notes,
            artifactId: _selectedArtifactId,
            sprintId: _selectedSprintId,
            clearArtifact:
                widget.todo!.artifactId != null && _selectedArtifactId == null,
            clearSprint:
                widget.todo!.sprintId != null && _selectedSprintId == null,
          )
        : await provider.createTodo(
            widget.sessionId,
            title: title,
            priority: _priority,
            notes: notes.isEmpty ? null : notes,
            artifactId: _selectedArtifactId,
            sprintId: _selectedSprintId,
          );

    if (!mounted) return;
    if (result != null) {
      Navigator.pop(context, result);
    } else {
      _showSnack(provider.error ?? 'Unable to save todo');
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
        initialChildSize: 0.64,
        minChildSize: 0.48,
        maxChildSize: 0.9,
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
                      _isEditing ? 'Edit Todo' : 'New Todo',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    Consumer<WorkProvider>(
                      builder: (context, provider, _) {
                        final busy = _isEditing
                            ? provider.isTodoMutating(widget.todo!.id)
                            : false;
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
                        hintText: 'Wire the artifact detail flow',
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _priority,
                      decoration: const InputDecoration(
                        labelText: 'Priority',
                      ),
                      items: const [
                        DropdownMenuItem(value: 'high', child: Text('High')),
                        DropdownMenuItem(
                            value: 'medium', child: Text('Medium')),
                        DropdownMenuItem(value: 'low', child: Text('Low')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _priority = value);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String?>(
                      initialValue: _selectedSprintId,
                      decoration: const InputDecoration(
                        labelText: 'Linked Sprint',
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('None'),
                        ),
                        ...widget.availableSprints.map(
                          (sprint) => DropdownMenuItem<String?>(
                            value: sprint.id,
                            child: Text(sprint.label),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() => _selectedSprintId = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String?>(
                      initialValue: _selectedArtifactId,
                      decoration: const InputDecoration(
                        labelText: 'Linked Artifact',
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('None'),
                        ),
                        ...widget.availableArtifacts.map(
                          (artifact) => DropdownMenuItem<String?>(
                            value: artifact.id,
                            child: Text(artifact.label),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() => _selectedArtifactId = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _notesController,
                      minLines: 3,
                      maxLines: 6,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Notes',
                        hintText:
                            'Capture context, blockers, or acceptance notes for this work item.',
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
