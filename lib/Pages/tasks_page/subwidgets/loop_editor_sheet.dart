import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:coqui_app/Models/coqui_loop.dart';
import 'package:coqui_app/Models/coqui_project.dart';
import 'package:coqui_app/Models/coqui_sprint.dart';
import 'package:coqui_app/Providers/loop_provider.dart';
import 'package:coqui_app/Widgets/selection_bottom_sheet.dart';

class LoopEditorSheet extends StatefulWidget {
  const LoopEditorSheet({super.key});

  @override
  State<LoopEditorSheet> createState() => _LoopEditorSheetState();
}

class _LoopEditorSheetState extends State<LoopEditorSheet> {
  final _goalController = TextEditingController();
  final _maxIterationsController = TextEditingController();
  final Map<String, TextEditingController> _parameterControllers = {};

  CoquiLoopDefinition? _selectedDefinition;
  CoquiProject? _selectedProject;
  CoquiSprint? _selectedSprint;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<LoopProvider>();
      provider.fetchDefinitions();
      provider.fetchProjects();
    });
  }

  @override
  void dispose() {
    _goalController.dispose();
    _maxIterationsController.dispose();
    for (final controller in _parameterControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDefinition() async {
    final provider = context.read<LoopProvider>();
    final selected = await showSelectionBottomSheet<CoquiLoopDefinition>(
      context: context,
      header: const Text('Loop Definition'),
      fetchItems: () async {
        await provider.fetchDefinitions(force: true);
        return provider.definitions;
      },
      currentSelection: _selectedDefinition,
      itemBuilder: (definition, selected, onSelected) {
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            selected
                ? Icons.radio_button_checked
                : Icons.radio_button_unchecked,
          ),
          onTap: () => onSelected(definition),
          title: Text(definition.name),
          subtitle: definition.description.isNotEmpty
              ? Text(definition.description, maxLines: 2)
              : null,
        );
      },
    );
    if (!mounted || selected == null) return;

    setState(() {
      _selectedDefinition = selected;
      _syncParameterControllers(selected);
    });
  }

  Future<void> _pickProject() async {
    final provider = context.read<LoopProvider>();
    final selected = await showSelectionBottomSheet<CoquiProject>(
      context: context,
      header: const Text('Project'),
      fetchItems: () async {
        await provider.fetchProjects(force: true);
        return provider.projects;
      },
      currentSelection: _selectedProject,
      itemBuilder: (project, selected, onSelected) {
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            selected
                ? Icons.radio_button_checked
                : Icons.radio_button_unchecked,
          ),
          onTap: () => onSelected(project),
          title: Text(project.label),
          subtitle: Text(
            project.hasDescription
                ? project.description!
                : '${project.sprintCount} sprint${project.sprintCount == 1 ? '' : 's'}',
            maxLines: 2,
          ),
        );
      },
    );
    if (!mounted || selected == null) return;

    setState(() {
      _selectedProject = selected;
      _selectedSprint = null;
    });
    await provider.fetchProjectSprints(selected.id, force: true);
  }

  Future<void> _pickSprint() async {
    final project = _selectedProject;
    if (project == null) return;

    final provider = context.read<LoopProvider>();
    final selected = await showSelectionBottomSheet<CoquiSprint>(
      context: context,
      header: Text('${project.label} Sprint'),
      fetchItems: () async {
        await provider.fetchProjectSprints(project.id, force: true);
        return provider.sprintsForProject(project.id);
      },
      currentSelection: _selectedSprint,
      itemBuilder: (sprint, selected, onSelected) {
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            selected
                ? Icons.radio_button_checked
                : Icons.radio_button_unchecked,
          ),
          onTap: () => onSelected(sprint),
          title: Text(sprint.label),
          subtitle: Text(sprint.status),
        );
      },
    );
    if (!mounted || selected == null) return;

    setState(() => _selectedSprint = selected);
  }

  void _clearProject() {
    setState(() {
      _selectedProject = null;
      _selectedSprint = null;
    });
  }

  void _clearSprint() {
    setState(() => _selectedSprint = null);
  }

  void _syncParameterControllers(CoquiLoopDefinition definition) {
    final nextNames = definition.parameters.map((item) => item.name).toSet();

    final existingNames = _parameterControllers.keys.toList();
    for (final name in existingNames) {
      if (!nextNames.contains(name)) {
        _parameterControllers.remove(name)?.dispose();
      }
    }

    for (final parameter in definition.parameters) {
      _parameterControllers.putIfAbsent(
        parameter.name,
        () => TextEditingController(text: parameter.defaultValue ?? ''),
      );
    }
  }

  Future<void> _submit() async {
    final provider = context.read<LoopProvider>();
    final definition = _selectedDefinition;
    final goal = _goalController.text.trim();

    if (definition == null) {
      _showSnackBar('Select a loop definition.');
      return;
    }
    if (goal.isEmpty) {
      _showSnackBar('Loop goal is required.');
      return;
    }

    final parameters = <String, String>{};
    for (final parameter in definition.parameters) {
      final value = _parameterControllers[parameter.name]?.text.trim() ?? '';
      if (parameter.required && value.isEmpty) {
        _showSnackBar('${parameter.name} is required.');
        return;
      }
      if (value.isNotEmpty) {
        parameters[parameter.name] = value;
      }
    }

    final maxIterationsText = _maxIterationsController.text.trim();
    final maxIterations =
        maxIterationsText.isEmpty ? null : int.tryParse(maxIterationsText);
    if (maxIterationsText.isNotEmpty && maxIterations == null) {
      _showSnackBar('Max iterations must be a number.');
      return;
    }

    final detail = await provider.createLoop(
      definition: definition.name,
      goal: goal,
      projectId: _selectedProject?.id,
      sprintId: _selectedSprint?.id,
      parameters: parameters.isEmpty ? null : parameters,
      maxIterations: maxIterations,
    );

    if (!mounted) return;

    if (detail == null) {
      _showSnackBar(provider.error ?? 'Unable to start loop.');
      provider.clearError();
      return;
    }

    Navigator.pop(context, detail.loop);
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final definition = _selectedDefinition;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.86,
        minChildSize: 0.55,
        maxChildSize: 0.95,
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
                      'Start Loop',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    Consumer<LoopProvider>(
                      builder: (context, provider, _) {
                        return FilledButton(
                          onPressed: provider.isCreating ? null : _submit,
                          child: provider.isCreating
                              ? SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color:
                                        Theme.of(context).colorScheme.onPrimary,
                                  ),
                                )
                              : const Text('Start'),
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
                    _Label(label: 'Definition *'),
                    const SizedBox(height: 6),
                    OutlinedButton.icon(
                      onPressed: _pickDefinition,
                      icon: const Icon(Icons.account_tree_outlined),
                      label: Align(
                        alignment: Alignment.centerLeft,
                        child:
                            Text(definition?.name ?? 'Select loop definition'),
                      ),
                    ),
                    if (definition != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: theme.dividerColor),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (definition.description.isNotEmpty)
                              Text(
                                definition.description,
                                style: theme.textTheme.bodySmall,
                              ),
                            if (definition.roles.isNotEmpty) ...[
                              if (definition.description.isNotEmpty)
                                const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: definition.roles
                                    .map((role) => _TagChip(label: role.role))
                                    .toList(),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    _Label(label: 'Goal *'),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _goalController,
                      decoration: const InputDecoration(
                        hintText:
                            'Describe the outcome this loop should drive toward…',
                        border: OutlineInputBorder(),
                      ),
                      minLines: 4,
                      maxLines: 6,
                    ),
                    const SizedBox(height: 16),
                    _Label(label: 'Project (optional)'),
                    const SizedBox(height: 6),
                    OutlinedButton.icon(
                      onPressed: _pickProject,
                      icon: const Icon(Icons.workspaces_outline),
                      label: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(_selectedProject?.label ?? 'No project'),
                      ),
                    ),
                    if (_selectedProject != null) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _clearProject,
                          child: const Text('Clear project'),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    _Label(label: 'Sprint (optional)'),
                    const SizedBox(height: 6),
                    OutlinedButton.icon(
                      onPressed: _selectedProject == null ? null : _pickSprint,
                      icon: const Icon(Icons.flag_outlined),
                      label: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(_selectedSprint?.label ?? 'No sprint'),
                      ),
                    ),
                    if (_selectedSprint != null) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _clearSprint,
                          child: const Text('Clear sprint'),
                        ),
                      ),
                    ],
                    if (definition != null &&
                        definition.parameters.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _Label(label: 'Parameters'),
                      const SizedBox(height: 8),
                      ...definition.parameters.map((parameter) {
                        final controller =
                            _parameterControllers[parameter.name]!;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                parameter.required
                                    ? '${parameter.name} *'
                                    : parameter.name,
                                style: theme.textTheme.labelMedium,
                              ),
                              if (parameter.description.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  parameter.description,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 6),
                              TextField(
                                controller: controller,
                                decoration: InputDecoration(
                                  hintText: parameter.example ??
                                      parameter.defaultValue,
                                  border: const OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                    const SizedBox(height: 16),
                    _Label(label: 'Max Iterations (optional)'),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _maxIterationsController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        hintText: 'Leave blank to use the definition default',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: theme.dividerColor),
                      ),
                      child: Text(
                        'Loops are immutable once started. Use the detail sheet to pause, resume, stop, and inspect iterations instead of editing the loop in place.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String label;

  const _Label({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final String label;

  const _TagChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelSmall),
    );
  }
}
