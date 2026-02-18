import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:coqui_app/Models/coqui_role.dart';
import 'package:coqui_app/Providers/role_provider.dart';
import 'package:coqui_app/Widgets/role_list_tile.dart';

/// Role management card in settings.
///
/// Displays all roles (built-in and custom), allows creating new
/// custom roles, editing existing ones, and deleting custom roles.
class RoleSettings extends StatefulWidget {
  const RoleSettings({super.key});

  @override
  State<RoleSettings> createState() => _RoleSettingsState();
}

class _RoleSettingsState extends State<RoleSettings> {
  @override
  void initState() {
    super.initState();
    // Fetch roles when the widget is first built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RoleProvider>().fetchRoles();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RoleProvider>(
      builder: (context, roleProvider, _) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.person_outline),
                    const SizedBox(width: 8),
                    Text(
                      'Roles',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: roleProvider.isLoading
                          ? null
                          : () => roleProvider.fetchRoles(),
                      tooltip: 'Refresh roles',
                    ),
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () => _showCreateRoleDialog(context),
                      tooltip: 'Create new role',
                    ),
                  ],
                ),
                const Divider(),
                if (roleProvider.error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      roleProvider.error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                if (roleProvider.isLoading && roleProvider.roles.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (roleProvider.roles.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child:
                          Text('No roles found. Check your server connection.'),
                    ),
                  )
                else
                  ...roleProvider.roles.map((role) {
                    return RoleListTile(
                      role: role,
                      selectable: false,
                      trailing: role.isBuiltin
                          ? null
                          : PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'edit') {
                                  _showEditRoleDialog(context, role);
                                } else if (value == 'delete') {
                                  _showDeleteConfirmation(context, role);
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: ListTile(
                                    leading: Icon(Icons.edit_outlined),
                                    title: Text('Edit'),
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: ListTile(
                                    leading: Icon(
                                      Icons.delete_outlined,
                                      color:
                                          Theme.of(context).colorScheme.error,
                                    ),
                                    title: Text(
                                      'Delete',
                                      style: TextStyle(
                                        color:
                                            Theme.of(context).colorScheme.error,
                                      ),
                                    ),
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                              ],
                            ),
                      onSelected: role.isBuiltin
                          ? null
                          : (_) => _showEditRoleDialog(context, role),
                    );
                  }),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showCreateRoleDialog(BuildContext context) async {
    final result = await showDialog<_RoleFormResult>(
      context: context,
      builder: (context) => const _RoleFormDialog(title: 'Create Role'),
    );

    if (result != null && context.mounted) {
      final provider = context.read<RoleProvider>();
      final success = await provider.createRole(
        name: result.name,
        displayName: result.displayName,
        description: result.description,
        accessLevel: result.accessLevel,
        instructions: result.instructions,
      );
      if (success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Role "${result.name}" created')),
        );
      } else if (!success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.error ?? 'Failed to create role'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _showEditRoleDialog(
    BuildContext context,
    CoquiRole role,
  ) async {
    // Fetch full role with instructions
    CoquiRole fullRole;
    try {
      final provider = context.read<RoleProvider>();
      fullRole = await provider.getRole(role.name) ?? role;
    } catch (_) {
      fullRole = role;
    }

    if (!context.mounted) return;

    final result = await showDialog<_RoleFormResult>(
      context: context,
      builder: (context) => _RoleFormDialog(
        title: 'Edit Role',
        initialName: fullRole.name,
        initialDisplayName: fullRole.displayName,
        initialDescription: fullRole.description,
        initialAccessLevel: fullRole.accessLevel,
        initialInstructions: fullRole.instructions ?? '',
        isEditing: true,
      ),
    );

    if (result != null && context.mounted) {
      final provider = context.read<RoleProvider>();
      final success = await provider.updateRole(
        role.name,
        displayName: result.displayName,
        description: result.description,
        accessLevel: result.accessLevel,
        instructions: result.instructions,
      );
      if (success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Role "${role.name}" updated')),
        );
      } else if (!success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.error ?? 'Failed to update role'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _showDeleteConfirmation(
    BuildContext context,
    CoquiRole role,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Role'),
        content: Text('Are you sure you want to delete "${role.label}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final provider = context.read<RoleProvider>();
      final success = await provider.deleteRole(role.name);
      if (success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Role "${role.label}" deleted')),
        );
      }
    }
  }
}

// ── Role Form Dialog ──────────────────────────────────────────────────

class _RoleFormResult {
  final String name;
  final String displayName;
  final String description;
  final String accessLevel;
  final String instructions;

  _RoleFormResult({
    required this.name,
    required this.displayName,
    required this.description,
    required this.accessLevel,
    required this.instructions,
  });
}

class _RoleFormDialog extends StatefulWidget {
  final String title;
  final String initialName;
  final String initialDisplayName;
  final String initialDescription;
  final String initialAccessLevel;
  final String initialInstructions;
  final bool isEditing;

  const _RoleFormDialog({
    required this.title,
    this.initialName = '',
    this.initialDisplayName = '',
    this.initialDescription = '',
    this.initialAccessLevel = 'readonly',
    this.initialInstructions = '',
    this.isEditing = false,
  });

  @override
  State<_RoleFormDialog> createState() => _RoleFormDialogState();
}

class _RoleFormDialogState extends State<_RoleFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _displayNameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _instructionsController;
  late String _accessLevel;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _displayNameController =
        TextEditingController(text: widget.initialDisplayName);
    _descriptionController =
        TextEditingController(text: widget.initialDescription);
    _instructionsController =
        TextEditingController(text: widget.initialInstructions);
    _accessLevel = widget.initialAccessLevel;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _displayNameController.dispose();
    _descriptionController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    hintText: 'my-custom-role',
                    helperText:
                        'Lowercase, alphanumeric + hyphens, max 64 chars',
                  ),
                  enabled: !widget.isEditing,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Name is required';
                    }
                    if (!RegExp(r'^[a-z0-9]([a-z0-9-]*[a-z0-9])?$')
                        .hasMatch(value.trim())) {
                      return 'Lowercase alphanumeric and hyphens only';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _displayNameController,
                  decoration: const InputDecoration(
                    labelText: 'Display Name',
                    hintText: 'My Custom Role',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'What this role does',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _accessLevel,
                  decoration: const InputDecoration(
                    labelText: 'Access Level',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'full',
                      child: Text('Full Access'),
                    ),
                    DropdownMenuItem(
                      value: 'readonly',
                      child: Text('Read Only'),
                    ),
                    DropdownMenuItem(
                      value: 'minimal',
                      child: Text('Minimal'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _accessLevel = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _instructionsController,
                  decoration: const InputDecoration(
                    labelText: 'Instructions',
                    hintText: 'System prompt for this role...',
                    alignLabelWithHint: true,
                  ),
                  maxLines: 8,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Instructions are required';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(widget.isEditing ? 'Save' : 'Create'),
        ),
      ],
    );
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      Navigator.pop(
        context,
        _RoleFormResult(
          name: _nameController.text.trim(),
          displayName: _displayNameController.text.trim(),
          description: _descriptionController.text.trim(),
          accessLevel: _accessLevel,
          instructions: _instructionsController.text.trim(),
        ),
      );
    }
  }
}
