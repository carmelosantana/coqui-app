import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:coqui_app/Models/coqui_profile.dart';
import 'package:coqui_app/Providers/instance_provider.dart';
import 'package:coqui_app/Providers/profile_provider.dart';
import 'package:coqui_app/Services/analytics_service.dart';

class ProfileSettings extends StatefulWidget {
  const ProfileSettings({super.key});

  @override
  State<ProfileSettings> createState() => _ProfileSettingsState();
}

class _ProfileSettingsState extends State<ProfileSettings> {
  String? _loadedInstanceId;
  String? _loadingProfileName;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final instanceId = context.read<InstanceProvider>().activeInstance?.id;
    if (_loadedInstanceId == instanceId) {
      return;
    }

    _loadedInstanceId = instanceId;
    final profileProvider = context.read<ProfileProvider>();
    if (instanceId == null) {
      profileProvider.clear();
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      profileProvider.fetchProfiles();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<InstanceProvider, ProfileProvider>(
      builder: (context, instanceProvider, profileProvider, _) {
        final activeInstance = instanceProvider.activeInstance;
        final theme = Theme.of(context);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Profiles',
              style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            if (activeInstance == null)
              const ListTile(
                leading: Icon(Icons.person_off_outlined),
                title: Text('No active server'),
                subtitle: Text(
                  'Connect to a Coqui instance before managing profiles.',
                ),
              )
            else ...[
              if (profileProvider.error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    profileProvider.error!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
              ListTile(
                leading: profileProvider.isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_circle_outline),
                title: const Text('Create Profile'),
                subtitle: const Text(
                  'Add a new profile with a name, description, and optional soul override.',
                ),
                enabled: !profileProvider.isLoading && !profileProvider.isMutating,
                onTap: () => _openCreateDialog(profileProvider),
              ),
              if (profileProvider.profiles.isEmpty && !profileProvider.isLoading)
                const ListTile(
                  leading: Icon(Icons.person_outline),
                  title: Text('No profiles discovered'),
                  subtitle: Text(
                    'Create the first profile for this Coqui server here.',
                  ),
                )
              else
                ...profileProvider.profiles.map(
                  (profile) => _ProfileTile(
                    profile: profile,
                    busy: profileProvider.isMutating &&
                        _loadingProfileName == profile.name,
                    onEdit: () => _openEditDialog(profileProvider, profile.name),
                    onDelete: () => _confirmDelete(profileProvider, profile),
                  ),
                ),
            ],
          ],
        );
      },
    );
  }

  Future<void> _openCreateDialog(ProfileProvider profileProvider) async {
    final draft = await showDialog<_ProfileDraft>(
      context: context,
      builder: (context) => const _ProfileEditorDialog(),
    );

    if (draft == null || !mounted) {
      return;
    }

    final created = await profileProvider.createProfile(
      name: draft.name,
      description: draft.description,
      soul: draft.soul,
      backstory: draft.backstory,
    );

    if (!mounted) {
      return;
    }

    if (created != null) {
      AnalyticsService.trackEvent('profile_created');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Created profile ${created.label}.')),
      );
    }
  }

  Future<void> _openEditDialog(
    ProfileProvider profileProvider,
    String profileName,
  ) async {
    setState(() => _loadingProfileName = profileName);
    final detail = await profileProvider.fetchProfileDetail(profileName);
    if (!mounted) {
      return;
    }
    setState(() => _loadingProfileName = null);

    if (detail == null) {
      return;
    }

    final draft = await showDialog<_ProfileDraft>(
      context: context,
      builder: (context) => _ProfileEditorDialog(
        initialProfile: detail,
      ),
    );

    if (draft == null || !mounted) {
      return;
    }

    final updated = await profileProvider.updateProfile(
      profileName,
      description: draft.description,
      soul: draft.soul,
    );

    if (!mounted) {
      return;
    }

    if (updated != null) {
      AnalyticsService.trackEvent('profile_updated');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Updated profile ${updated.label}.')),
      );
    }
  }

  Future<void> _confirmDelete(
    ProfileProvider profileProvider,
    CoquiProfile profile,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${profile.label}?'),
        content: const Text(
          'This removes the profile directory from the server workspace. Default profiles cannot be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() => _loadingProfileName = profile.name);
    final deleted = await profileProvider.deleteProfile(profile.name);
    if (!mounted) {
      return;
    }
    setState(() => _loadingProfileName = null);

    if (deleted) {
      AnalyticsService.trackEvent('profile_deleted');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Deleted profile ${profile.label}.')),
      );
    }
  }
}

class _ProfileTile extends StatelessWidget {
  final CoquiProfile profile;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ProfileTile({
    required this.profile,
    required this.busy,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: busy
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.person_outline),
      title: Row(
        children: [
          Expanded(child: Text(profile.label)),
          if (profile.isDefault)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'Default',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
            ),
        ],
      ),
      subtitle: Text(
        profile.description.isNotEmpty ? profile.description : profile.name,
      ),
      trailing: Wrap(
        spacing: 4,
        children: [
          IconButton(
            tooltip: 'Edit profile',
            onPressed: busy ? null : onEdit,
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: 'Delete profile',
            onPressed: busy || profile.isDefault ? null : onDelete,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
    );
  }
}

class _ProfileEditorDialog extends StatefulWidget {
  final CoquiProfile? initialProfile;

  const _ProfileEditorDialog({this.initialProfile});

  @override
  State<_ProfileEditorDialog> createState() => _ProfileEditorDialogState();
}

class _ProfileEditorDialogState extends State<_ProfileEditorDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _soulController;
  late final TextEditingController _backstoryController;
  final _formKey = GlobalKey<FormState>();

  bool get _isCreate => widget.initialProfile == null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialProfile?.name ?? '');
    _descriptionController = TextEditingController(
      text: widget.initialProfile?.description ?? '',
    );
    _soulController = TextEditingController(text: widget.initialProfile?.soul ?? '');
    _backstoryController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _soulController.dispose();
    _backstoryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isCreate ? 'Create Profile' : 'Edit Profile'),
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
                  enabled: _isCreate,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    helperText: 'Lowercase letters, numbers, hyphens, or underscores.',
                  ),
                  validator: (value) {
                    final normalized = value?.trim() ?? '';
                    if (normalized.isEmpty) {
                      return 'Name is required.';
                    }
                    if (!RegExp(r'^[a-z0-9](?:[a-z0-9_-]*[a-z0-9])?$').hasMatch(normalized)) {
                      return 'Use lowercase letters, numbers, hyphens, or underscores.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    helperText: 'Used as the default generated soul content when no soul override is provided.',
                  ),
                  minLines: 2,
                  maxLines: 3,
                  validator: (value) {
                    if (_isCreate &&
                        value!.trim().isEmpty &&
                        _soulController.text.trim().isEmpty) {
                      return 'Provide a description or soul.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _soulController,
                  decoration: const InputDecoration(
                    labelText: 'Soul Override',
                    helperText: 'Optional markdown for soul.md. Leave blank to keep generated soul content based on description.',
                  ),
                  minLines: 4,
                  maxLines: 8,
                ),
                if (_isCreate) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _backstoryController,
                    decoration: const InputDecoration(
                      labelText: 'Initial Backstory',
                      helperText: 'Optional inline backstory.md content for the new profile.',
                    ),
                    minLines: 3,
                    maxLines: 6,
                  ),
                ],
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
          child: Text(_isCreate ? 'Create' : 'Save'),
        ),
      ],
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    Navigator.pop(
      context,
      _ProfileDraft(
        name: _nameController.text.trim(),
        description: _nullIfEmpty(_descriptionController.text),
        soul: _nullIfEmpty(_soulController.text),
        backstory: _nullIfEmpty(_backstoryController.text),
      ),
    );
  }

  String? _nullIfEmpty(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

class _ProfileDraft {
  final String name;
  final String? description;
  final String? soul;
  final String? backstory;

  const _ProfileDraft({
    required this.name,
    this.description,
    this.soul,
    this.backstory,
  });
}