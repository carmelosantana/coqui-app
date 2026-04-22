import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:coqui_app/Models/coqui_project.dart';
import 'package:coqui_app/Providers/project_provider.dart';

class ProjectEditorSheet extends StatefulWidget {
  final CoquiProject? project;

  const ProjectEditorSheet({
    super.key,
    this.project,
  });

  @override
  State<ProjectEditorSheet> createState() => _ProjectEditorSheetState();
}

class _ProjectEditorSheetState extends State<ProjectEditorSheet> {
  final _titleController = TextEditingController();
  final _slugController = TextEditingController();
  final _descriptionController = TextEditingController();

  bool get _isEditing => widget.project != null;

  @override
  void initState() {
    super.initState();
    final project = widget.project;
    if (project != null) {
      _titleController.text = project.title;
      _slugController.text = project.slug;
      _descriptionController.text = project.description ?? '';
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _slugController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final provider = context.read<ProjectProvider>();
    final title = _titleController.text.trim();
    final slug = _slugController.text.trim().isEmpty
        ? _slugify(title)
        : _slugController.text.trim();
    final description = _descriptionController.text.trim();

    if (title.isEmpty) {
      _showSnack('Please enter a project title');
      return;
    }

    if (!_isEditing && slug.isEmpty) {
      _showSnack('Please enter a valid slug');
      return;
    }

    final result = _isEditing
        ? await provider.updateProject(
            widget.project!.id,
            title: title,
            description: description.isEmpty ? '' : description,
          )
        : await provider.createProject(
            title: title,
            slug: slug,
            description: description.isEmpty ? null : description,
          );

    if (!mounted) return;
    if (result != null) {
      Navigator.pop(context, result);
    } else {
      _showSnack(provider.error ?? 'Unable to save project');
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
        initialChildSize: 0.55,
        minChildSize: 0.42,
        maxChildSize: 0.82,
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
                      _isEditing ? 'Edit Project' : 'New Project',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    Consumer<ProjectProvider>(
                      builder: (context, provider, _) {
                        final busy = _isEditing
                            ? provider.isProjectMutating(widget.project!.id)
                            : provider.isLoading;
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
                        hintText: 'Career Ops',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _slugController,
                      enabled: !_isEditing,
                      decoration: InputDecoration(
                        labelText: 'Slug',
                        hintText: 'career-ops',
                        helperText: _isEditing
                            ? 'Slug is fixed after creation.'
                            : 'If left blank, Coqui generates one from the title.',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _descriptionController,
                      minLines: 3,
                      maxLines: 6,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        hintText:
                            'A focused workspace for the next app tranche.',
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

  String _slugify(String input) {
    final value = input
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    return value;
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
