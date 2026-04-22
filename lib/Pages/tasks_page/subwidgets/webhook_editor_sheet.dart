import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:coqui_app/Models/coqui_role.dart';
import 'package:coqui_app/Models/coqui_webhook.dart';
import 'package:coqui_app/Providers/role_provider.dart';
import 'package:coqui_app/Providers/webhook_provider.dart';
import 'package:coqui_app/Services/coqui_api_service.dart';
import 'package:coqui_app/Widgets/profile_picker_dialog.dart';
import 'package:coqui_app/Widgets/selection_bottom_sheet.dart';

class WebhookEditorSheet extends StatefulWidget {
  final CoquiWebhook? webhook;

  const WebhookEditorSheet({super.key, this.webhook});

  @override
  State<WebhookEditorSheet> createState() => _WebhookEditorSheetState();
}

class _WebhookEditorSheetState extends State<WebhookEditorSheet> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _eventFilterController = TextEditingController();
  final _promptTemplateController = TextEditingController();

  String _selectedSource = 'generic';
  String _selectedRole = 'orchestrator';
  String? _selectedProfile;
  int _maxIterations = 48;
  bool _enabled = true;

  static const _sourceOptions = ['generic', 'github', 'slack'];
  static const _iterationOptions = [10, 25, 48, 100];

  bool get _isEditing => widget.webhook != null;

  @override
  void initState() {
    super.initState();
    final webhook = widget.webhook;
    if (webhook != null) {
      _nameController.text = webhook.name;
      _descriptionController.text = webhook.description ?? '';
      _eventFilterController.text = webhook.eventFilter ?? '';
      _promptTemplateController.text = webhook.promptTemplate;
      _selectedSource = webhook.source;
      _selectedRole = webhook.role;
      _selectedProfile = webhook.profile;
      _maxIterations = webhook.maxIterations;
      _enabled = webhook.enabled;
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
    _eventFilterController.dispose();
    _promptTemplateController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final provider = context.read<WebhookProvider>();
    final name = _nameController.text.trim();
    final promptTemplate = _promptTemplateController.text.trim();
    final description = _descriptionController.text.trim();
    final eventFilter = _eventFilterController.text.trim();

    if (name.isEmpty) {
      _showSnackBar('Webhook name is required.');
      return;
    }
    if (promptTemplate.isEmpty) {
      _showSnackBar('Prompt template is required.');
      return;
    }

    final webhook = _isEditing
        ? await provider.updateWebhook(
            widget.webhook!.id,
            name: name,
            description: description.isEmpty ? null : description,
            source: _selectedSource,
            promptTemplate: promptTemplate,
            role: _selectedRole,
            profile: _selectedProfile,
            clearProfile: _selectedProfile == null,
            maxIterations: _maxIterations,
            enabled: _enabled,
            eventFilter: eventFilter.isEmpty ? null : eventFilter,
          )
        : await provider.createWebhook(
            name: name,
            promptTemplate: promptTemplate,
            source: _selectedSource,
            role: _selectedRole,
            profile: _selectedProfile,
            maxIterations: _maxIterations,
            description: description.isEmpty ? null : description,
            eventFilter: eventFilter.isEmpty ? null : eventFilter,
            enabled: _enabled,
          );

    if (!mounted) return;

    if (webhook == null) {
      _showSnackBar(provider.error ?? 'Unable to save webhook.');
      provider.clearError();
      return;
    }

    if (!_isEditing && !webhook.isSecretMasked && webhook.secret.isNotEmpty) {
      await _showSecretDialog(webhook.secret);
    }

    if (!mounted) return;
    Navigator.pop(context, webhook);
  }

  Future<void> _pickProfile() async {
    final api = context.read<CoquiApiService>();
    final selectedProfile = await showProfilePickerDialog(
      context: context,
      title: 'Webhook Profile',
      fetchProfiles: api.getProfiles,
      initialValue: _selectedProfile,
    );
    if (!mounted || selectedProfile == null) return;

    setState(() {
      _selectedProfile = selectedProfile.isEmpty ? null : selectedProfile;
    });
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
      header: const Text('Execution Role'),
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

  Future<void> _showSecretDialog(String secret) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Store this signing secret'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'The API only returns the full webhook secret when it is created or rotated. Save it where your sender can use it.',
              ),
              const SizedBox(height: 12),
              SelectableText(secret),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: secret));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Secret copied to clipboard')),
                  );
                }
              },
              child: const Text('Copy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );
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
        initialChildSize: 0.82,
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
                      _isEditing ? 'Edit Webhook' : 'New Webhook',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    Consumer<WebhookProvider>(
                      builder: (context, provider, _) {
                        final isSaving = _isEditing
                            ? provider.isMutating(widget.webhook!.id)
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
                        hintText: 'release-alerts',
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
                        hintText: 'What this webhook is responsible for',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                      minLines: 1,
                    ),
                    const SizedBox(height: 16),
                    _Label(label: 'Source'),
                    const SizedBox(height: 6),
                    InputDecorator(
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      child: DropdownButton<String>(
                        value: _selectedSource,
                        isDense: true,
                        isExpanded: true,
                        underline: const SizedBox.shrink(),
                        items: _sourceOptions
                            .map(
                              (source) => DropdownMenuItem(
                                value: source,
                                child: Text(source.toUpperCase()),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _selectedSource = value);
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    _Label(label: 'Execution Role'),
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
                    _Label(label: 'Profile'),
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
                              (iterations) => DropdownMenuItem(
                                value: iterations,
                                child: Text('$iterations iterations'),
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
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Enabled'),
                      subtitle: const Text(
                        'Disabled webhooks keep their configuration but reject incoming deliveries.',
                      ),
                      value: _enabled,
                      onChanged: (value) => setState(() => _enabled = value),
                    ),
                    const SizedBox(height: 8),
                    _Label(label: 'Event Filter'),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _eventFilterController,
                      decoration: const InputDecoration(
                        hintText: 'Optional comma-separated event names',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _Label(label: 'Prompt Template *'),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _promptTemplateController,
                      decoration: const InputDecoration(
                        hintText:
                            'Summarize {{event_type}} and explain what action to take using {{summary}}.',
                        border: OutlineInputBorder(),
                      ),
                      minLines: 6,
                      maxLines: 10,
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
                        'Tip: prompt templates support {{payload}}, {{event_type}}, {{summary}}, and field paths like {{repository.full_name}}.',
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
