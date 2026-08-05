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
  final _cronController = TextEditingController();
  final _promptController = TextEditingController();

  // CAP `persona_id`. NOTE: the picker below still lists roles via
  // RoleProvider; migrating it to a persona picker is out of scope for the
  // B4 wire-boundary reshape (see task report concern).
  String _selectedPersona = 'orchestrator';

  bool get _isEditing => widget.schedule != null;

  @override
  void initState() {
    super.initState();
    final schedule = widget.schedule;
    if (schedule != null) {
      _nameController.text = schedule.name;
      _cronController.text = schedule.cron;
      _promptController.text = schedule.action.prompt ?? '';
      if (schedule.personaId.isNotEmpty) {
        _selectedPersona = schedule.personaId;
      }
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
    _cronController.dispose();
    _promptController.dispose();
    super.dispose();
  }

  Future<void> _pickPersona() async {
    final roleProvider = context.read<RoleProvider>();
    final roles = roleProvider.roles;
    final current = roles.cast<CoquiRole?>().firstWhere(
          (role) => role?.name == _selectedPersona,
          orElse: () => CoquiRole(name: _selectedPersona, model: ''),
        );

    final selectedRole = await showSelectionBottomSheet<CoquiRole>(
      context: context,
      header: const Text('Schedule Persona'),
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
    setState(() => _selectedPersona = selectedRole.name);
  }

  Future<void> _submit() async {
    final provider = context.read<ScheduleProvider>();
    final name = _nameController.text.trim();
    final cron = _cronController.text.trim();
    final prompt = _promptController.text.trim();

    if (name.isEmpty) {
      _showSnackBar('Schedule name is required.');
      return;
    }
    if (cron.isEmpty) {
      _showSnackBar('Cron expression is required.');
      return;
    }
    if (prompt.isEmpty) {
      _showSnackBar('Prompt is required.');
      return;
    }

    final action = ScheduleAction.turn(prompt);
    final schedule = _isEditing
        ? await provider.updateSchedule(
            widget.schedule!.id,
            name: name,
            cron: cron,
            personaId: _selectedPersona,
            action: action,
          )
        : await provider.createSchedule(
            name: name,
            cron: cron,
            personaId: _selectedPersona,
            action: action,
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
                    _Label(label: 'Cron *'),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _cronController,
                      decoration: const InputDecoration(
                        hintText: '0 9 * * 1-5',
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
                        'Use a cron expression for recurring runs. Trigger runs are picked up on the next API scheduler tick.',
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
                    _Label(label: 'Persona'),
                    const SizedBox(height: 6),
                    OutlinedButton.icon(
                      onPressed: _pickPersona,
                      icon: const Icon(Icons.person_outline),
                      label: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(_selectedPersona),
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
