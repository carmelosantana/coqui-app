import 'package:flutter/material.dart';
import 'package:coqui_app/Providers/task_provider.dart';
import 'package:coqui_app/Providers/role_provider.dart';
import 'package:coqui_app/Services/coqui_api_service.dart';
import 'package:coqui_app/Widgets/profile_picker_dialog.dart';
import 'package:provider/provider.dart';

/// Bottom sheet for creating a new background task.
class CreateTaskSheet extends StatefulWidget {
  const CreateTaskSheet({super.key});

  @override
  State<CreateTaskSheet> createState() => _CreateTaskSheetState();
}

class _CreateTaskSheetState extends State<CreateTaskSheet> {
  final _promptController = TextEditingController();
  final _titleController = TextEditingController();
  String _selectedRole = 'orchestrator';
  String? _selectedProfile;
  int _maxIterations = 25;

  static const _iterationOptions = [10, 25, 50, 100];

  @override
  void initState() {
    super.initState();
    // Fetch roles if not already loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final roleProvider = context.read<RoleProvider>();
      if (roleProvider.roles.isEmpty && !roleProvider.isLoading) {
        roleProvider.fetchRoles();
      }
    });
  }

  @override
  void dispose() {
    _promptController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a task prompt')),
      );
      return;
    }

    final title = _titleController.text.trim();
    final task = await context.read<TaskProvider>().createTask(
          prompt: prompt,
          role: _selectedRole,
          title: title.isEmpty ? null : title,
          profile: _selectedProfile,
          maxIterations: _maxIterations,
        );

    if (mounted) {
      if (task != null) {
        Navigator.pop(context, task);
      } else {
        final error = context.read<TaskProvider>().error;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error ?? 'Failed to create task')),
        );
        context.read<TaskProvider>().clearError();
      }
    }
  }

  Future<void> _pickProfile() async {
    final api = context.read<CoquiApiService>();
    final selectedProfile = await showProfilePickerDialog(
      context: context,
      title: 'Task Profile',
      fetchProfiles: api.getProfiles,
      initialValue: _selectedProfile,
    );
    if (!mounted || selectedProfile == null) return;

    setState(() {
      _selectedProfile = selectedProfile.isEmpty ? null : selectedProfile;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.92,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              // Handle
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
                    Text('New Background Task',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    const Spacer(),
                    Consumer<TaskProvider>(
                      builder: (context, provider, _) {
                        return FilledButton(
                          onPressed: provider.isCreating ? null : _submit,
                          child: provider.isCreating
                              ? SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onPrimary),
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
                    // Prompt
                    Text('Prompt *',
                        style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _promptController,
                      decoration: const InputDecoration(
                        hintText:
                            'Describe what the background agent should do…',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 5,
                      minLines: 3,
                      autofocus: true,
                    ),
                    const SizedBox(height: 16),
                    // Title (optional)
                    Text('Title (optional)',
                        style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        hintText: 'A short label for this task',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('Profile (optional)',
                        style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 6),
                    OutlinedButton.icon(
                      onPressed: _pickProfile,
                      icon: const Icon(Icons.person_outline),
                      label: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(_selectedProfile ?? 'No profile'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Role selector
                    Text('Role',
                        style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 6),
                    Consumer<RoleProvider>(
                      builder: (context, roleProvider, _) {
                        final roles = roleProvider.roles;
                        final roleNames = roles.map((r) => r.name).toList();
                        if (!roleNames.contains(_selectedRole)) {
                          roleNames.insert(0, _selectedRole);
                        }
                        return InputDecorator(
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                          ),
                          child: DropdownButton<String>(
                            value: _selectedRole,
                            isExpanded: true,
                            underline: const SizedBox.shrink(),
                            isDense: true,
                            items: roleNames
                                .map((r) => DropdownMenuItem(
                                      value: r,
                                      child: Text(r),
                                    ))
                                .toList(),
                            onChanged: (v) {
                              if (v != null) setState(() => _selectedRole = v);
                            },
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    // Max iterations
                    Text('Max Iterations',
                        style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant)),
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
                        isExpanded: true,
                        underline: const SizedBox.shrink(),
                        isDense: true,
                        items: _iterationOptions
                            .map((n) => DropdownMenuItem(
                                  value: n,
                                  child: Text('$n iterations'),
                                ))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _maxIterations = v);
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
