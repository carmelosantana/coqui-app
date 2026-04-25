import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:coqui_app/Models/coqui_role.dart';
import 'package:coqui_app/Models/coqui_schedule.dart';
import 'package:coqui_app/Providers/role_provider.dart';
import 'package:coqui_app/Providers/schedule_provider.dart';
import 'package:coqui_app/Widgets/selection_bottom_sheet.dart';

class ScheduleEditorSheet extends StatefulWidget {
  final CoquiSchedule? schedule;

  const ScheduleEditorSheet({super.key, this.schedule});

  @override
  State<ScheduleEditorSheet> createState() => _ScheduleEditorSheetState();
}

class _ScheduleEditorSheetState extends State<ScheduleEditorSheet> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _expressionController = TextEditingController();
  final _promptController = TextEditingController();
  final _timezoneController = TextEditingController(text: 'UTC');

  String _selectedRole = 'orchestrator';
  int _maxIterations = 48;
  int _maxFailures = 3;

  static const _iterationOptions = [10, 25, 48, 100];
  static const _failureOptions = [1, 3, 5, 10];

  bool get _isEditing => widget.schedule != null;

  @override
  void initState() {
    super.initState();
    final schedule = widget.schedule;
    if (schedule != null) {
      _nameController.text = schedule.name;
      _descriptionController.text = schedule.description ?? '';
      _expressionController.text = schedule.scheduleExpression;
      _promptController.text = schedule.prompt;
      _timezoneController.text = schedule.timezone;
      _selectedRole = schedule.role;
      _maxIterations = schedule.maxIterations;
      _maxFailures = schedule.maxFailures;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final roleProvider = context.read<RoleProvider>();
      if (roleProvider.roles.isEmpty && !roleProvider.isLoading) {
        roleProvider.fetchRoles();
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _expressionController.dispose();
    _promptController.dispose();
    _timezoneController.dispose();
    super.dispose();
  }

  Future<void> _pickRole() async {
    final roleProvider = context.read<RoleProvider>();
    final roles = roleProvider.roles;
    final current = roles.cast<CoquiRole?>().firstWhere(
          (role) => role?.name == _selectedRole,
          orElse: () => CoquiRole(name: _selectedRole, model: ''),
        );

    final selectedRole = await showSelectionBottomSheet<CoquiRole>(
      context: context,
      header: const Text('Schedule Role'),
      fetchItems: () async {
        if (roleProvider.roles.isEmpty) {
          await roleProvider.fetchRoles();
        }
        return roleProvider.roles;
      },
      currentSelection: current,
      itemBuilder: (role, selected, onSelected) {
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            selected
                ? Icons.radio_button_checked
                : Icons.radio_button_unchecked,
          ),
          onTap: () => onSelected(role),
          title: Text(role.label),
          subtitle: role.description.isNotEmpty ? Text(role.description) : null,
        );
      },
    );

    if (!mounted || selectedRole == null) return;
    setState(() => _selectedRole = selectedRole.name);
  }

  Future<void> _submit() async {
    final provider = context.read<ScheduleProvider>();
    final name = _nameController.text.trim();
    final expression = _expressionController.text.trim();
    final prompt = _promptController.text.trim();
    final description = _descriptionController.text.trim();
    final timezone = _timezoneController.text.trim();

    if (name.isEmpty) {
      _showSnackBar('Schedule name is required.');
      return;
    }
    if (expression.isEmpty) {
      _showSnackBar('Schedule expression is required.');
      return;
    }
    if (prompt.isEmpty) {
      _showSnackBar('Prompt is required.');
      return;
    }
    if (timezone.isEmpty) {
      _showSnackBar('Timezone is required.');
      return;
    }

    final schedule = _isEditing
        ? await provider.updateSchedule(
            widget.schedule!.id,
            name: name,
            description: description,
            scheduleExpression: expression,
            prompt: prompt,
            role: _selectedRole,
            timezone: timezone,
            maxIterations: _maxIterations,
            maxFailures: _maxFailures,
          )
        : await provider.createSchedule(
            name: name,
            scheduleExpression: expression,
            prompt: prompt,
            role: _selectedRole,
            timezone: timezone,
            maxIterations: _maxIterations,
            maxFailures: _maxFailures,
            description: description.isEmpty ? null : description,
          );

    if (!mounted) return;

    if (schedule == null) {
      _showSnackBar(provider.error ?? 'Unable to save schedule.');
      provider.clearError();
      return;
    }

    Navigator.pop(context, schedule);
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.84,
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
                      _isEditing ? 'Edit Schedule' : 'New Schedule',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    Consumer<ScheduleProvider>(
                      builder: (context, provider, _) {
                        final isSaving = _isEditing
                            ? provider.isMutating(widget.schedule!.id)
                            : provider.isCreating;
                        return FilledButton(
                          onPressed: isSaving ? null : _submit,
                          child: isSaving
                              ? SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color:
                                        Theme.of(context).colorScheme.onPrimary,
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
                    _Label(label: 'Name *'),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _nameController,
                      enabled: !_isEditing,
                      decoration: const InputDecoration(
                        hintText: 'daily-review',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _Label(label: 'Description'),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        hintText: 'What this schedule should accomplish',
                        border: OutlineInputBorder(),
                      ),
                      minLines: 1,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    _Label(label: 'Schedule Expression *'),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _expressionController,
                      decoration: const InputDecoration(
                        hintText: '0 9 * * 1-5 or @once',
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
                        'Use cron expressions for recurring runs and @once for a one-shot schedule. Trigger runs are picked up on the next API scheduler tick.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _Label(label: 'Prompt *'),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _promptController,
                      decoration: const InputDecoration(
                        hintText:
                            'Describe the automated review or task to run…',
                        border: OutlineInputBorder(),
                      ),
                      minLines: 5,
                      maxLines: 8,
                    ),
                    const SizedBox(height: 16),
                    _Label(label: 'Role'),
                    const SizedBox(height: 6),
                    OutlinedButton.icon(
                      onPressed: _pickRole,
                      icon: const Icon(Icons.build_circle_outlined),
                      label: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(_selectedRole),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _Label(label: 'Timezone'),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _timezoneController,
                      decoration: const InputDecoration(
                        hintText: 'UTC',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _Label(label: 'Max Iterations'),
                    const SizedBox(height: 6),
                    InputDecorator(
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      child: DropdownButton<int>(
                        value: _maxIterations,
                        isDense: true,
                        isExpanded: true,
                        underline: const SizedBox.shrink(),
                        items: _iterationOptions
                            .map(
                              (value) => DropdownMenuItem(
                                value: value,
                                child: Text('$value iterations'),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _maxIterations = value);
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    _Label(label: 'Max Consecutive Failures'),
                    const SizedBox(height: 6),
                    InputDecorator(
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      child: DropdownButton<int>(
                        value: _maxFailures,
                        isDense: true,
                        isExpanded: true,
                        underline: const SizedBox.shrink(),
                        items: _failureOptions
                            .map(
                              (value) => DropdownMenuItem(
                                value: value,
                                child: Text('$value failures'),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _maxFailures = value);
                          }
                        },
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
