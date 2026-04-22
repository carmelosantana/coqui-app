import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:coqui_app/Models/coqui_artifact.dart';
import 'package:coqui_app/Models/coqui_project.dart';
import 'package:coqui_app/Models/coqui_sprint.dart';
import 'package:coqui_app/Providers/work_provider.dart';

class ArtifactEditorSheet extends StatefulWidget {
  final String sessionId;
  final CoquiArtifact? artifact;
  final List<CoquiProject> availableProjects;
  final List<CoquiSprint> availableSprints;
  final String? initialProjectId;
  final String? initialSprintId;

  const ArtifactEditorSheet({
    super.key,
    required this.sessionId,
    required this.availableProjects,
    required this.availableSprints,
    this.artifact,
    this.initialProjectId,
    this.initialSprintId,
  });

  @override
  State<ArtifactEditorSheet> createState() => _ArtifactEditorSheetState();
}

class _ArtifactEditorSheetState extends State<ArtifactEditorSheet> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _languageController = TextEditingController();
  final _filepathController = TextEditingController();
  final _summaryController = TextEditingController();
  final _tagsController = TextEditingController();
  final _changeSummaryController = TextEditingController();

  String _type = 'code';
  String _stage = 'draft';
  String? _selectedProjectId;
  String? _selectedSprintId;
  bool _persistent = false;

  bool get _isEditing => widget.artifact != null;

  @override
  void initState() {
    super.initState();
    final artifact = widget.artifact;
    _titleController.text = artifact?.title ?? '';
    _contentController.text = artifact?.content ?? '';
    _languageController.text = artifact?.language ?? '';
    _filepathController.text = artifact?.filepath ?? '';
    _summaryController.text = artifact?.summary ?? '';
    _tagsController.text = artifact?.tags.join(', ') ?? '';
    _type = artifact?.type ?? 'code';
    _stage = artifact?.stage ?? 'draft';
    _selectedProjectId = artifact?.projectId ?? widget.initialProjectId;
    _selectedSprintId = artifact?.sprintId ?? widget.initialSprintId;
    _persistent = artifact?.persistent ?? (_selectedProjectId != null);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _languageController.dispose();
    _filepathController.dispose();
    _summaryController.dispose();
    _tagsController.dispose();
    _changeSummaryController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final provider = context.read<WorkProvider>();
    final title = _titleController.text.trim();
    final content = _contentController.text;
    final language = _languageController.text.trim();
    final filepath = _filepathController.text.trim();
    final summary = _summaryController.text.trim();
    final tags = _tagsController.text
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
    final changeSummary = _changeSummaryController.text.trim();

    if (title.isEmpty) {
      _showSnack('Please enter an artifact title');
      return;
    }

    if (content.trim().isEmpty) {
      _showSnack('Please enter artifact content');
      return;
    }

    final result = _isEditing
        ? await provider.updateArtifact(
            widget.sessionId,
            widget.artifact!.id,
            title: title,
            content: content,
            changeSummary: changeSummary.isEmpty ? null : changeSummary,
            stage: _stage,
            language: language.isEmpty ? null : language,
            projectId: _selectedProjectId,
            sprintId: _selectedSprintId,
            persistent: _persistent,
            tags: tags,
            summary: summary.isEmpty ? null : summary,
            clearLanguage:
                widget.artifact!.language != null && language.isEmpty,
            clearProject: widget.artifact!.projectId != null &&
                _selectedProjectId == null,
            clearSprint:
                widget.artifact!.sprintId != null && _selectedSprintId == null,
            clearSummary: widget.artifact!.summary != null && summary.isEmpty,
          )
        : await provider.createArtifact(
            widget.sessionId,
            title: title,
            content: content,
            type: _type,
            stage: _stage,
            language: language.isEmpty ? null : language,
            filepath: filepath.isEmpty ? null : filepath,
            projectId: _selectedProjectId,
            sprintId: _selectedSprintId,
            persistent: _persistent,
            tags: tags.isEmpty ? null : tags,
            summary: summary.isEmpty ? null : summary,
          );

    if (!mounted) return;
    if (result != null) {
      Navigator.pop(context, result);
    } else {
      _showSnack(provider.error ?? 'Unable to save artifact');
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
        initialChildSize: 0.8,
        minChildSize: 0.58,
        maxChildSize: 0.96,
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
                      _isEditing ? 'Edit Artifact' : 'New Artifact',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    Consumer<WorkProvider>(
                      builder: (context, provider, _) {
                        final busy = _isEditing
                            ? provider.isArtifactMutating(widget.artifact!.id)
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
                        hintText: 'Work tab implementation notes',
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _type,
                      decoration: const InputDecoration(labelText: 'Type'),
                      items: const [
                        DropdownMenuItem(value: 'code', child: Text('Code')),
                        DropdownMenuItem(
                            value: 'markdown', child: Text('Markdown')),
                        DropdownMenuItem(value: 'text', child: Text('Text')),
                        DropdownMenuItem(
                            value: 'config', child: Text('Config')),
                        DropdownMenuItem(value: 'plan', child: Text('Plan')),
                      ],
                      onChanged: _isEditing
                          ? null
                          : (value) {
                              if (value != null) {
                                setState(() => _type = value);
                              }
                            },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _stage,
                      decoration: const InputDecoration(labelText: 'Stage'),
                      items: const [
                        DropdownMenuItem(value: 'draft', child: Text('Draft')),
                        DropdownMenuItem(
                            value: 'review', child: Text('Review')),
                        DropdownMenuItem(value: 'final', child: Text('Final')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _stage = value);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String?>(
                      initialValue: _selectedProjectId,
                      decoration: const InputDecoration(
                        labelText: 'Linked Project',
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('None'),
                        ),
                        ...widget.availableProjects.map(
                          (project) => DropdownMenuItem<String?>(
                            value: project.id,
                            child: Text(project.label),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedProjectId = value;
                          if (value == null) {
                            _selectedSprintId = null;
                            _persistent = false;
                          } else {
                            _persistent = true;
                          }
                        });
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
                    TextField(
                      controller: _languageController,
                      decoration: const InputDecoration(
                        labelText: 'Language',
                        hintText: 'dart',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _filepathController,
                      decoration: const InputDecoration(
                        labelText: 'File Path',
                        hintText: 'lib/Pages/work_page/work_page.dart',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _summaryController,
                      minLines: 2,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Summary',
                        hintText:
                            'A short human summary of what this artifact is for.',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _tagsController,
                      decoration: const InputDecoration(
                        labelText: 'Tags',
                        hintText: 'work, planning, ui',
                      ),
                    ),
                    if (_isEditing) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: _changeSummaryController,
                        decoration: const InputDecoration(
                          labelText: 'Change Summary',
                          hintText: 'Added todo and artifact tabs',
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    SwitchListTile.adaptive(
                      value: _persistent,
                      onChanged: (value) {
                        setState(() => _persistent = value);
                      },
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Persistent'),
                      subtitle: const Text(
                        'Project-linked artifacts should usually remain persistent so they survive later loop stages.',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _contentController,
                      minLines: 10,
                      maxLines: 18,
                      decoration: const InputDecoration(
                        labelText: 'Content',
                        alignLabelWithHint: true,
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
