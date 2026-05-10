import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';

import 'package:coqui_app/Models/coqui_backstory_inspection.dart';
import 'package:coqui_app/Models/coqui_profile.dart';
import 'package:coqui_app/Providers/instance_provider.dart';
import 'package:coqui_app/Providers/profile_provider.dart';
import 'package:coqui_app/Services/analytics_service.dart';

class ProfileManager extends StatefulWidget {
  const ProfileManager({super.key});

  @override
  State<ProfileManager> createState() => _ProfileManagerState();
}

class _ProfileManagerState extends State<ProfileManager> {
  String? _loadedInstanceId;
  String? _loadingProfileName;
  String? _selectedProfileName;
  String? _queuedSelectionName;
  bool _isLoadingWorkspace = false;
  bool _isSavingSelectedProfile = false;
  late final TextEditingController _descriptionController;
  late final TextEditingController _soulController;

  @override
  void initState() {
    super.initState();
    _descriptionController = TextEditingController();
    _soulController = TextEditingController();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _soulController.dispose();
    super.dispose();
  }

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
      _resetSelection();
      profileProvider.clear();
      return;
    }

    _resetSelection();
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

        _ensureSelection(
          profileProvider,
          hasActiveInstance: activeInstance != null,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Profiles',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Profiles shape Coqui\'s continuity, identity, and companion behavior. Use the larger workspace here to refine soul markdown and review backstory state.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: activeInstance == null ||
                          profileProvider.isLoading ||
                          profileProvider.isMutating
                      ? null
                      : () => _openCreateDialog(profileProvider),
                  icon: const Icon(Icons.add),
                  label: const Text('Create Profile'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (activeInstance == null)
              const Card(
                child: ListTile(
                  leading: Icon(Icons.person_off_outlined),
                  title: Text('No active server'),
                  subtitle: Text(
                    'Connect to a Coqui instance before managing profiles.',
                  ),
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
              if (profileProvider.profiles.isEmpty &&
                  !profileProvider.isLoading)
                const Card(
                  child: ListTile(
                    leading: Icon(Icons.person_outline),
                    title: Text('No profiles discovered'),
                    subtitle: Text(
                      'Create the first profile for this Coqui server here.',
                    ),
                  ),
                )
              else
                LayoutBuilder(
                  builder: (context, constraints) {
                    final useSplitLayout = constraints.maxWidth >= 960;
                    final listPane = _buildProfileListPane(profileProvider);
                    final detailPane = _buildDetailPane(profileProvider);

                    if (!useSplitLayout) {
                      return Column(
                        children: [
                          listPane,
                          const SizedBox(height: 16),
                          detailPane,
                        ],
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(width: 320, child: listPane),
                        const SizedBox(width: 16),
                        Expanded(child: detailPane),
                      ],
                    );
                  },
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
      await _selectProfile(profileProvider, created.name, force: true);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Created profile ${created.label}.')),
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
      if (_selectedProfileName == profile.name) {
        _resetSelection();
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Deleted profile ${profile.label}.')),
      );
    }
  }

  Widget _buildProfileListPane(ProfileProvider profileProvider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Available Profiles',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            if (profileProvider.isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              ...profileProvider.profiles.map(
                (profile) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _ProfileTile(
                    profile: profile,
                    selected: _selectedProfileName == profile.name,
                    busy: profileProvider.isMutating &&
                        _loadingProfileName == profile.name,
                    onTap: () => _selectProfile(profileProvider, profile.name),
                    onDelete: () => _confirmDelete(profileProvider, profile),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailPane(ProfileProvider profileProvider) {
    final profileName = _selectedProfileName;
    if (profileName == null) {
      return const Card(
        child: ListTile(
          leading: Icon(Icons.edit_note_outlined),
          title: Text('Select a profile'),
          subtitle: Text(
            'Choose a profile to edit its description, soul markdown, and inspect backstory state.',
          ),
        ),
      );
    }

    final detail = profileProvider.detailFor(profileName) ??
        profileProvider.profiles.cast<CoquiProfile?>().firstWhere(
              (profile) => profile?.name == profileName,
              orElse: () => null,
            );
    final inspection = profileProvider.backstoryFor(profileName);
    final isLoadingBackstory = profileProvider.isLoadingBackstory(profileName);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        detail?.label ?? profileName,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Edit profile metadata inline and use the larger panel to work on soul markdown without bouncing through a dialog.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
                if (detail?.isDefault == true)
                  Chip(
                    label: const Text('Default'),
                    avatar: Icon(
                      Icons.star_outline,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isLoadingWorkspace)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: CircularProgressIndicator(),
                ),
              )
            else ...[
              TextFormField(
                key: const ValueKey('profile-description-field'),
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  helperText:
                      'Used when Coqui generates soul content without a custom markdown override.',
                ),
                minLines: 3,
                maxLines: 4,
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const ValueKey('profile-soul-field'),
                controller: _soulController,
                decoration: const InputDecoration(
                  labelText: 'Soul Markdown',
                  alignLabelWithHint: true,
                  helperText:
                      'This writes soul.md directly through the profile API. Leave it blank only when the description should define the profile voice.',
                ),
                minLines: 14,
                maxLines: 22,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: _isSavingSelectedProfile
                        ? null
                        : () => _resetEditorsFromDetail(detail),
                    child: const Text('Reset'),
                  ),
                  FilledButton.icon(
                    key: const ValueKey('profile-save-button'),
                    onPressed: _isSavingSelectedProfile
                        ? null
                        : () => _saveSelectedProfile(profileProvider),
                    icon: _isSavingSelectedProfile
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: const Text('Save Changes'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'Backstory Preview',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              if (isLoadingBackstory)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: CircularProgressIndicator(),
                )
              else
                _BackstoryPreview(inspection: inspection),
            ],
          ],
        ),
      ),
    );
  }

  void _ensureSelection(
    ProfileProvider profileProvider, {
    required bool hasActiveInstance,
  }) {
    if (!hasActiveInstance || profileProvider.profiles.isEmpty) {
      _queuedSelectionName = null;
      return;
    }

    final selectionExists = profileProvider.profiles.any(
      (profile) => profile.name == _selectedProfileName,
    );
    final nextName =
        selectionExists ? null : profileProvider.profiles.first.name;

    if (nextName == null || _queuedSelectionName == nextName) {
      return;
    }

    _queuedSelectionName = nextName;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _queuedSelectionName = null;
      if (!mounted) {
        return;
      }
      await _selectProfile(profileProvider, nextName, force: true);
    });
  }

  Future<void> _selectProfile(
    ProfileProvider profileProvider,
    String profileName, {
    bool force = false,
  }) async {
    if (!force && _selectedProfileName == profileName) {
      return;
    }

    setState(() {
      _selectedProfileName = profileName;
      _isLoadingWorkspace = true;
    });

    final detail = await profileProvider.fetchProfileDetail(profileName);
    await profileProvider.fetchBackstoryInspection(profileName);

    if (!mounted || _selectedProfileName != profileName) {
      return;
    }

    _resetEditorsFromDetail(detail);
    setState(() {
      _isLoadingWorkspace = false;
    });
  }

  void _resetEditorsFromDetail(CoquiProfile? detail) {
    _descriptionController.text = detail?.description ?? '';
    _soulController.text = detail?.soul ?? '';
  }

  void _resetSelection() {
    _selectedProfileName = null;
    _queuedSelectionName = null;
    _isLoadingWorkspace = false;
    _descriptionController.clear();
    _soulController.clear();
  }

  Future<void> _saveSelectedProfile(ProfileProvider profileProvider) async {
    final profileName = _selectedProfileName;
    if (profileName == null) {
      return;
    }

    final description = _descriptionController.text.trim();
    final soul = _soulController.text.trim();
    if (description.isEmpty && soul.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Provide a description or soul before saving.'),
        ),
      );
      return;
    }

    setState(() => _isSavingSelectedProfile = true);
    final updated = await profileProvider.updateProfile(
      profileName,
      description: description,
      soul: soul,
    );
    if (!mounted) {
      return;
    }
    setState(() => _isSavingSelectedProfile = false);

    if (updated != null) {
      AnalyticsService.trackEvent('profile_updated');
      _resetEditorsFromDetail(updated);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Updated profile ${updated.label}.')),
      );
    }
  }
}

class _ProfileTile extends StatelessWidget {
  final CoquiProfile profile;
  final bool selected;
  final bool busy;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ProfileTile({
    required this.profile,
    required this.selected,
    required this.busy,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: selected ? colorScheme.secondaryContainer : colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: busy ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: busy
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.person_outline),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            profile.label,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (profile.isDefault)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  colorScheme.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'Default',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(color: colorScheme.primary),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      profile.description.isNotEmpty
                          ? profile.description
                          : profile.name,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                children: [
                  IconButton(
                    tooltip: 'Open profile workspace',
                    onPressed: busy ? null : onTap,
                    icon: const Icon(Icons.chevron_right),
                  ),
                  IconButton(
                    tooltip: 'Delete profile',
                    onPressed: busy || profile.isDefault ? null : onDelete,
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BackstoryPreview extends StatelessWidget {
  final CoquiBackstoryInspection? inspection;

  const _BackstoryPreview({required this.inspection});

  @override
  Widget build(BuildContext context) {
    final data = inspection;
    if (data == null) {
      return Text(
        'Select a profile to inspect its generated backstory and source state.',
        style: Theme.of(context).textTheme.bodyMedium,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _BackstoryMetricChip(label: 'Files', value: '${data.totalFiles}'),
            _BackstoryMetricChip(
              label: 'Supported',
              value: '${data.supportedFileCount}',
            ),
            _BackstoryMetricChip(
              label: 'Tokens',
              value: '${data.totalTokens}',
            ),
            _BackstoryMetricChip(
              label: 'Needs regen',
              value: data.needsRegeneration ? 'Yes' : 'No',
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          data.sourceFolderExists
              ? (data.sourceFolder ?? 'Backstory source folder available')
              : (data.reason ?? 'No backstory source folder available yet.'),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: data.content != null && data.content!.trim().isNotEmpty
              ? MarkdownBody(
                  data: data.content!,
                  selectable: true,
                )
              : Text(
                  'No generated backstory content is available yet for this profile.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
        ),
      ],
    );
  }
}

class _BackstoryMetricChip extends StatelessWidget {
  final String label;
  final String value;

  const _BackstoryMetricChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label: $value',
        style: Theme.of(context).textTheme.labelLarge,
      ),
    );
  }
}

class _ProfileEditorDialog extends StatefulWidget {
  const _ProfileEditorDialog();

  @override
  State<_ProfileEditorDialog> createState() => _ProfileEditorDialogState();
}

class _ProfileEditorDialogState extends State<_ProfileEditorDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _soulController;
  late final TextEditingController _backstoryController;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _descriptionController = TextEditingController();
    _soulController = TextEditingController();
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
      title: const Text('Create Profile'),
      content: SizedBox(
        width: 560,
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
                    helperText:
                        'Lowercase letters, numbers, hyphens, or underscores.',
                  ),
                  validator: (value) {
                    final normalized = value?.trim() ?? '';
                    if (normalized.isEmpty) {
                      return 'Name is required.';
                    }
                    if (!RegExp(r'^[a-z0-9](?:[a-z0-9_-]*[a-z0-9])?$')
                        .hasMatch(normalized)) {
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
                    helperText:
                        'Used as the default generated soul content when no soul override is provided.',
                  ),
                  minLines: 2,
                  maxLines: 3,
                  validator: (value) {
                    if (value!.trim().isEmpty &&
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
                    helperText:
                        'Optional markdown for soul.md. Leave blank to keep generated soul content based on description.',
                  ),
                  minLines: 8,
                  maxLines: 14,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _backstoryController,
                  decoration: const InputDecoration(
                    labelText: 'Initial Backstory',
                    helperText:
                        'Optional inline backstory.md content for the new profile.',
                  ),
                  minLines: 5,
                  maxLines: 10,
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
          child: const Text('Create'),
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
