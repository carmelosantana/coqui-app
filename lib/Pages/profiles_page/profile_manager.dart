import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';

import 'package:coqui_app/Models/coqui_backstory_inspection.dart';
import 'package:coqui_app/Models/coqui_profile.dart';
import 'package:coqui_app/Models/coqui_profile_preference_schema.dart';
import 'package:coqui_app/Providers/instance_provider.dart';
import 'package:coqui_app/Providers/profile_provider.dart';
import 'package:coqui_app/Services/analytics_service.dart';

class ProfileManagerController {
  Future<bool> Function()? _confirmPageExit;

  Future<bool> confirmPageExit() async {
    final handler = _confirmPageExit;
    if (handler == null) {
      return true;
    }

    return handler();
  }
}

class ProfileManager extends StatefulWidget {
  final ProfileManagerController? controller;

  const ProfileManager({super.key, this.controller});

  @override
  State<ProfileManager> createState() => _ProfileManagerState();
}

class _ProfileManagerState extends State<ProfileManager> {
  String? _loadedInstanceId;
  String? _loadingProfileName;
  String? _selectedProfileName;
  String? _queuedSelectionName;
  final Map<String, String> _selectedBackstoryFolders = <String, String>{};
  bool _isLoadingWorkspace = false;
  bool _isSavingSelectedProfile = false;
  String _savedDescription = '';
  String _savedSoul = '';
  late final TextEditingController _descriptionController;
  late final TextEditingController _soulController;

  bool get _hasUnsavedChanges {
    return _selectedProfileName != null &&
        (_descriptionController.text != _savedDescription ||
            _soulController.text != _savedSoul);
  }

  @override
  void initState() {
    super.initState();
    _descriptionController = TextEditingController();
    _soulController = TextEditingController();
    _attachController();
  }

  @override
  void didUpdateWidget(covariant ProfileManager oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._confirmPageExit = null;
      _attachController();
    }
  }

  @override
  void dispose() {
    widget.controller?._confirmPageExit = null;
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
      profileProvider.fetchPreferenceSchema();
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
    final canContinue = await _confirmSelectionChange(profileProvider);
    if (!canContinue || !mounted) {
      return;
    }

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
    if (_selectedProfileName == profile.name && _hasUnsavedChanges) {
      final canContinue = await _confirmSelectionChange(profileProvider);
      if (!canContinue || !mounted) {
        return;
      }
    }

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
    final preferenceValues = Map<String, dynamic>.from(
      detail?.preferenceValues ?? const <String, dynamic>{},
    );
    final preferenceSchema = profileProvider.preferenceSchema;

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
              _InlineSectionCard(
                title: 'Identity',
                subtitle:
                    'Edit description and soul markdown here. These are the only inline edits that stay draftable before save.',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.save_outlined),
                          label: const Text('Save Changes'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _buildPreferencesSection(
                profileProvider,
                detail,
                preferenceSchema,
                preferenceValues,
              ),
              const SizedBox(height: 24),
              _buildBackstorySourcesSection(
                profileProvider,
                profileName,
                inspection,
                isLoadingBackstory,
              ),
              const SizedBox(height: 24),
              _InlineSectionCard(
                title: 'Backstory Preview',
                subtitle:
                    'This is generated output. It stays read-only here and reflects the source files managed above.',
                child: isLoadingBackstory
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: CircularProgressIndicator(),
                      )
                    : _BackstoryPreview(inspection: inspection),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPreferencesSection(
    ProfileProvider profileProvider,
    CoquiProfile? detail,
    CoquiProfilePreferenceSchema? schema,
    Map<String, dynamic> preferenceValues,
  ) {
    final profileName = detail?.name;

    return _InlineSectionCard(
      title: 'Preferences',
      subtitle:
          'Use curated sections instead of raw preference keys. Unsupported fields stay deferred to a later expert mode.',
      child: schema == null
          ? Text(
              'Loading curated preference sections for this server...',
              style: Theme.of(context).textTheme.bodyMedium,
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: schema.sections
                  .map(
                    (section) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    section.label,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                ),
                                if (profileName != null)
                                  FilledButton.tonalIcon(
                                    onPressed: profileProvider.isMutating
                                        ? null
                                        : () => _openPreferenceSectionEditor(
                                              profileProvider,
                                              detail!,
                                              section,
                                            ),
                                    icon: const Icon(Icons.tune_outlined),
                                    label: const Text('Edit'),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              section.description,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                            ),
                            const SizedBox(height: 12),
                            ...section.fields.map(
                              (field) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(field.label),
                                  subtitle: Text(
                                    _formatPreferenceDisplayValue(
                                      _resolvePreferenceValue(
                                        preferenceValues,
                                        field.storagePath,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
    );
  }

  Widget _buildBackstorySourcesSection(
    ProfileProvider profileProvider,
    String profileName,
    CoquiBackstoryInspection? inspection,
    bool isLoadingBackstory,
  ) {
    final folders = _normalizedBackstoryFolders(inspection);
    final files = inspection?.files ?? const <Map<String, dynamic>>[];
    final unsupportedFiles =
        inspection?.unsupportedFiles ?? const <Map<String, dynamic>>[];
    final selectedFolder = _selectedBackstoryFolderPath(profileName, inspection);
    final childFolders = _childFolders(folders, selectedFolder);
    final folderFiles = _filesForFolder(files, selectedFolder);

    return _InlineSectionCard(
      title: 'Backstory Source Files',
      subtitle:
          'Generated backstory is read-only. Create folders and manage the source files that feed it.',
      action: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          OutlinedButton.icon(
            onPressed: profileProvider.isMutating || isLoadingBackstory
                ? null
                : () => _openCreateFolderDialog(
                      profileProvider,
                      profileName,
                      parentFolder: selectedFolder,
                    ),
            icon: const Icon(Icons.create_new_folder_outlined),
            label: const Text('Create Folder'),
          ),
          FilledButton.icon(
            onPressed: profileProvider.isMutating || isLoadingBackstory
                ? null
                : () => _openBackstoryEntryEditor(
                      profileProvider,
                      profileName,
                      parentFolder: selectedFolder,
                    ),
            icon: const Icon(Icons.note_add_outlined),
            label: const Text('New Source File'),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isLoadingBackstory)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: CircularProgressIndicator(),
            )
          else ...[
            LayoutBuilder(
              builder: (context, constraints) {
                final useSplit = constraints.maxWidth >= 860;
                final treePane = _buildBackstoryFolderTree(
                  profileName,
                  folders,
                  selectedFolder,
                );
                final contentPane = _buildBackstoryFolderContent(
                  profileProvider,
                  profileName,
                  selectedFolder,
                  childFolders,
                  folderFiles,
                );

                if (!useSplit) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      treePane,
                      const SizedBox(height: 16),
                      contentPane,
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 260, child: treePane),
                    const SizedBox(width: 16),
                    Expanded(child: contentPane),
                  ],
                );
              },
            ),
            if (unsupportedFiles.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Unsupported Files',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              ...unsupportedFiles.map(
                (file) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    tileColor:
                        Theme.of(context).colorScheme.surfaceContainerLowest,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    leading: const Icon(Icons.warning_amber_outlined),
                    title: Text(file['relative_path'] as String? ?? ''),
                    subtitle: Text(file['reason'] as String? ?? 'Unsupported'),
                  ),
                ),
              ),
            ],
          ],
        ],
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

    final canContinue = await _confirmSelectionChange(
      profileProvider,
      nextProfileName: profileName,
    );
    if (!canContinue || !mounted) {
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
    _selectedBackstoryFolders[profileName] = '';
    setState(() {
      _isLoadingWorkspace = false;
    });
  }

  void _resetEditorsFromDetail(CoquiProfile? detail) {
    _savedDescription = detail?.description ?? '';
    _savedSoul = detail?.soul ?? '';
    _descriptionController.text = _savedDescription;
    _soulController.text = _savedSoul;
  }

  void _resetSelection() {
    _selectedProfileName = null;
    _queuedSelectionName = null;
    _isLoadingWorkspace = false;
    _savedDescription = '';
    _savedSoul = '';
    _descriptionController.clear();
    _soulController.clear();
  }

  Future<bool> _saveSelectedProfile(ProfileProvider profileProvider) async {
    final profileName = _selectedProfileName;
    if (profileName == null) {
      return false;
    }

    final description = _descriptionController.text.trim();
    final soul = _soulController.text.trim();
    if (description.isEmpty && soul.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Provide a description or soul before saving.'),
        ),
      );
      return false;
    }

    setState(() => _isSavingSelectedProfile = true);
    final updated = await profileProvider.updateProfile(
      profileName,
      description: description,
      soul: soul,
    );
    if (!mounted) {
      return false;
    }
    setState(() => _isSavingSelectedProfile = false);

    if (updated != null) {
      AnalyticsService.trackEvent('profile_updated');
      _resetEditorsFromDetail(updated);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Updated profile ${updated.label}.')),
      );
      return true;
    }

    return false;
  }

  Future<void> _openPreferenceSectionEditor(
    ProfileProvider profileProvider,
    CoquiProfile profile,
    CoquiProfilePreferenceSection section,
  ) async {
    final initialValues = <String, dynamic>{
      for (final field in section.fields)
        field.storagePath: _resolvePreferenceValue(
          Map<String, dynamic>.from(
            profile.preferenceValues ?? const <String, dynamic>{},
          ),
          field.storagePath,
        ),
    };

    final draft = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _PreferenceSectionEditorDialog(
        section: section,
        initialValues: initialValues,
      ),
    );

    if (draft == null || !mounted) {
      return;
    }

    final nextPreferences = _clonePreferenceDocument(
      profile.preferenceDocument ?? const <String, dynamic>{},
    );

    for (final field in section.fields) {
      _applyPreferenceValue(
        nextPreferences,
        field.storagePath,
        draft[field.storagePath],
      );
    }

    final normalizedPreferences = _pruneEmptyPreferenceMaps(nextPreferences);
    final updated = await profileProvider.updateProfile(
      profile.name,
      preferences: normalizedPreferences.isEmpty ? null : normalizedPreferences,
      clearPreferences: normalizedPreferences.isEmpty,
    );

    if (!mounted || updated == null) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Saved ${section.label.toLowerCase()}.')),
    );
  }

  Future<void> _openCreateFolderDialog(
    ProfileProvider profileProvider,
    String profileName,
    {required String parentFolder}
  ) async {
    final folderName = await showDialog<String>(
      context: context,
      builder: (context) => _BackstoryFolderDialog(parentFolder: parentFolder),
    );

    if (folderName == null || !mounted) {
      return;
    }

    final folderPath = _joinBackstoryPath(parentFolder, folderName);

    final inspection = await profileProvider.createBackstoryFolder(
      profileName,
      path: folderPath,
    );
    if (!mounted || inspection == null) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Created backstory folder $folderPath.')),
    );
  }

  Future<void> _openBackstoryEntryEditor(
    ProfileProvider profileProvider,
    String profileName, {
    String? relativePath,
    String parentFolder = '',
  }) async {
    String? initialContent;
    if (relativePath != null) {
      initialContent = profileProvider.backstoryEntryContentFor(
        profileName,
        relativePath,
      );
      initialContent ??= await profileProvider.fetchBackstoryEntryContent(
        profileName,
        relativePath,
      );
      if (!mounted || initialContent == null) {
        return;
      }
    }

    final draft = await showDialog<_BackstoryEntryDraft>(
      context: context,
      builder: (context) => _BackstoryEntryEditorDialog(
        initialPath: relativePath,
        initialContent: initialContent,
        parentFolder: parentFolder,
      ),
    );

    if (draft == null || !mounted) {
      return;
    }

    final inspection = await profileProvider.saveBackstoryEntry(
      profileName,
      path: draft.path,
      content: draft.content,
    );
    if (!mounted || inspection == null) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Saved source file ${draft.path}.')),
    );
  }

  Future<void> _deleteBackstoryEntry(
    ProfileProvider profileProvider,
    String profileName,
    String relativePath,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete $relativePath?'),
        content: const Text(
          'This removes the source file and updates the generated backstory output.',
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

    final inspection = await profileProvider.deleteBackstoryEntry(
      profileName,
      path: relativePath,
    );
    if (!mounted || inspection == null) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Deleted source file $relativePath.')),
    );
  }

  Future<bool> _confirmSelectionChange(
    ProfileProvider profileProvider, {
    String? nextProfileName,
  }) async {
    if (!_hasUnsavedChanges || _selectedProfileName == nextProfileName) {
      return true;
    }

    final decision = await showDialog<_UnsavedProfileDecision>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unsaved profile changes'),
        content: const Text(
          'You have unsaved edits for the current profile. Save them before leaving, or discard them.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(
              context,
              _UnsavedProfileDecision.cancel,
            ),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(
              context,
              _UnsavedProfileDecision.discard,
            ),
            child: const Text('Discard'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              _UnsavedProfileDecision.save,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    switch (decision) {
      case _UnsavedProfileDecision.save:
        return _saveSelectedProfile(profileProvider);
      case _UnsavedProfileDecision.discard:
        return true;
      case _UnsavedProfileDecision.cancel:
      case null:
        return false;
    }
  }

  Future<bool> confirmPageExit() async {
    final profileProvider = context.read<ProfileProvider>();
    return _confirmSelectionChange(
      profileProvider,
    );
  }

  void _attachController() {
    widget.controller?._confirmPageExit = confirmPageExit;
  }

  Widget _buildBackstoryFolderTree(
    String profileName,
    List<Map<String, dynamic>> folders,
    String selectedFolder,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Text(
              'Folders',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          ...folders.map((folder) {
            final path = (folder['path'] as String? ?? '').trim();
            final depth = path.isEmpty ? 0 : path.split('/').length;
            final fileCount = folder['file_count'] as int? ?? 0;

            return ListTile(
              key: ValueKey('backstory-folder-$path'),
              dense: true,
              selected: selectedFolder == path,
              contentPadding: EdgeInsets.only(
                left: 12 + (depth * 16),
                right: 12,
              ),
              leading: Icon(
                path.isEmpty ? Icons.home_outlined : Icons.folder_outlined,
                size: 18,
              ),
              title: Text(path.isEmpty ? 'Root' : _backstoryLeafName(path)),
              subtitle: Text('$fileCount file${fileCount == 1 ? '' : 's'}'),
              onTap: () => setState(() {
                _selectedBackstoryFolders[profileName] = path;
              }),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildBackstoryFolderContent(
    ProfileProvider profileProvider,
    String profileName,
    String selectedFolder,
    List<Map<String, dynamic>> childFolders,
    List<Map<String, dynamic>> folderFiles,
  ) {
    final breadcrumbs = _backstoryBreadcrumbs(selectedFolder);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: breadcrumbs
                .map(
                  (crumb) => ActionChip(
                    label: Text(crumb.$2),
                    onPressed: () => setState(() {
                      _selectedBackstoryFolders[profileName] = crumb.$1;
                    }),
                  ),
                )
                .toList(growable: false),
          ),
          const SizedBox(height: 12),
          if (childFolders.isNotEmpty) ...[
            Text(
              'Folders in this location',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: childFolders
                  .map(
                    (folder) => ActionChip(
                      label: Text(_backstoryLeafName(
                        folder['path'] as String? ?? '',
                      )),
                      avatar: const Icon(Icons.folder_outlined, size: 18),
                      onPressed: () => setState(() {
                        _selectedBackstoryFolders[profileName] =
                            folder['path'] as String? ?? '';
                      }),
                    ),
                  )
                  .toList(growable: false),
            ),
            const SizedBox(height: 16),
          ],
          Text(
            'Source files in this folder',
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          if (folderFiles.isEmpty)
            Text(
              'No source files are in this folder yet. Create one in the current folder context.',
              style: Theme.of(context).textTheme.bodyMedium,
            )
          else
            ...folderFiles.map(
              (file) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  key: ValueKey(
                    'backstory-file-${file['relative_path'] as String? ?? ''}',
                  ),
                  tileColor:
                      Theme.of(context).colorScheme.surfaceContainerLowest,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  title: Text(_backstoryLeafName(
                    file['relative_path'] as String? ?? '',
                  )),
                  subtitle: Text(
                    '${file['token_estimate'] ?? 0} tokens · ${file['status'] ?? 'unknown'}',
                  ),
                  trailing: Wrap(
                    spacing: 4,
                    children: [
                      IconButton(
                        tooltip: 'Edit source file',
                        onPressed: profileProvider.isMutating
                            ? null
                            : () => _openBackstoryEntryEditor(
                                  profileProvider,
                                  profileName,
                                  relativePath:
                                      file['relative_path'] as String? ?? '',
                                  parentFolder: selectedFolder,
                                ),
                        icon: const Icon(Icons.edit_note_outlined),
                      ),
                      IconButton(
                        tooltip: 'Delete source file',
                        onPressed: profileProvider.isMutating
                            ? null
                            : () => _deleteBackstoryEntry(
                                  profileProvider,
                                  profileName,
                                  file['relative_path'] as String? ?? '',
                                ),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  dynamic _resolvePreferenceValue(
    Map<String, dynamic> values,
    String storagePath,
  ) {
    final segments = storagePath.split('.');
    dynamic current = values;
    for (final segment in segments) {
      if (current is! Map<String, dynamic>) {
        return null;
      }
      current = current[segment];
    }

    return current;
  }

  Map<String, dynamic> _clonePreferenceDocument(Map<String, dynamic> value) {
    return (jsonDecode(jsonEncode(value)) as Map).cast<String, dynamic>();
  }

  void _applyPreferenceValue(
    Map<String, dynamic> values,
    String storagePath,
    dynamic value,
  ) {
    final segments = storagePath.split('.');
    final normalized = _normalizePreferenceFieldValue(value);
    if (normalized == null) {
      _removeNestedValue(values, segments);
      return;
    }

    Map<String, dynamic> current = values;
    for (var index = 0; index < segments.length - 1; index++) {
      final segment = segments[index];
      final next = current[segment];
      if (next is Map<String, dynamic>) {
        current = next;
        continue;
      }

      final created = <String, dynamic>{};
      current[segment] = created;
      current = created;
    }

    current[segments.last] = normalized;
  }

  dynamic _normalizePreferenceFieldValue(dynamic value) {
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    if (value is List) {
      return value.isEmpty ? null : value;
    }
    return value;
  }

  void _removeNestedValue(Map<String, dynamic> values, List<String> segments) {
    if (segments.isEmpty) {
      return;
    }

    if (segments.length == 1) {
      values.remove(segments.first);
      return;
    }

    final next = values[segments.first];
    if (next is! Map<String, dynamic>) {
      return;
    }

    _removeNestedValue(next, segments.sublist(1));
    if (next.isEmpty) {
      values.remove(segments.first);
    }
  }

  Map<String, dynamic> _pruneEmptyPreferenceMaps(Map<String, dynamic> values) {
    final next = <String, dynamic>{};

    values.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        final nested = _pruneEmptyPreferenceMaps(value);
        if (nested.isNotEmpty) {
          next[key] = nested;
        }
        return;
      }

      if (value is List && value.isEmpty) {
        return;
      }
      if (value is String && value.trim().isEmpty) {
        return;
      }
      next[key] = value;
    });

    return next;
  }

  List<Map<String, dynamic>> _normalizedBackstoryFolders(
    CoquiBackstoryInspection? inspection,
  ) {
    final folders = [...?inspection?.folders];
    final hasRoot = folders.any((folder) => (folder['path'] as String? ?? '') == '');
    if (!hasRoot) {
      folders.insert(0, {'path': '', 'file_count': inspection?.files.length ?? 0});
    }

    folders.sort((left, right) {
      final leftPath = (left['path'] as String? ?? '').trim();
      final rightPath = (right['path'] as String? ?? '').trim();
      final depthCompare = _backstoryDepth(leftPath).compareTo(_backstoryDepth(rightPath));
      if (depthCompare != 0) {
        return depthCompare;
      }
      return leftPath.compareTo(rightPath);
    });
    return folders;
  }

  String _selectedBackstoryFolderPath(
    String profileName,
    CoquiBackstoryInspection? inspection,
  ) {
    final selected = _selectedBackstoryFolders[profileName] ?? '';
    final folders = _normalizedBackstoryFolders(inspection);
    final exists = folders.any((folder) => (folder['path'] as String? ?? '') == selected);
    return exists ? selected : '';
  }

  List<Map<String, dynamic>> _childFolders(
    List<Map<String, dynamic>> folders,
    String parentFolder,
  ) {
    return folders.where((folder) {
      final path = (folder['path'] as String? ?? '').trim();
      return path.isNotEmpty && _backstoryParentPath(path) == parentFolder;
    }).toList(growable: false);
  }

  List<Map<String, dynamic>> _filesForFolder(
    List<Map<String, dynamic>> files,
    String folder,
  ) {
    return files.where((file) {
      final path = (file['relative_path'] as String? ?? '').trim();
      return _backstoryParentPath(path) == folder;
    }).toList(growable: false);
  }

  int _backstoryDepth(String path) {
    if (path.isEmpty) {
      return 0;
    }
    return path.split('/').length;
  }

  String _backstoryParentPath(String path) {
    final trimmed = path.trim();
    if (trimmed.isEmpty || !trimmed.contains('/')) {
      return '';
    }
    return trimmed.substring(0, trimmed.lastIndexOf('/'));
  }

  String _backstoryLeafName(String path) {
    final trimmed = path.trim();
    if (trimmed.isEmpty) {
      return 'Root';
    }
    final segments = trimmed.split('/');
    return segments.last;
  }

  String _joinBackstoryPath(String parent, String name) {
    final trimmedParent = parent.trim();
    final trimmedName = name.trim();
    return trimmedParent.isEmpty ? trimmedName : '$trimmedParent/$trimmedName';
  }

  List<(String, String)> _backstoryBreadcrumbs(String folder) {
    final crumbs = <(String, String)>[('', 'Root')];
    if (folder.isEmpty) {
      return crumbs;
    }

    final segments = folder.split('/');
    var current = '';
    for (final segment in segments) {
      current = current.isEmpty ? segment : '$current/$segment';
      crumbs.add((current, segment));
    }
    return crumbs;
  }

  String _formatPreferenceDisplayValue(dynamic value) {
    if (value == null) {
      return 'Not set';
    }
    if (value is bool) {
      return value ? 'Enabled' : 'Disabled';
    }
    if (value is List) {
      return value.isEmpty ? 'None' : value.join(', ');
    }
    if (value is Map) {
      return value.isEmpty ? 'None' : jsonEncode(value);
    }

    return value.toString();
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
        'Backstory inspection is unavailable for this profile on the current server, or no generated content exists yet.',
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

enum _UnsavedProfileDecision {
  save,
  discard,
  cancel,
}

class _InlineSectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? action;

  const _InlineSectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              if (action != null) action!,
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
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

class _PreferenceSectionEditorDialog extends StatefulWidget {
  final CoquiProfilePreferenceSection section;
  final Map<String, dynamic> initialValues;

  const _PreferenceSectionEditorDialog({
    required this.section,
    required this.initialValues,
  });

  @override
  State<_PreferenceSectionEditorDialog> createState() =>
      _PreferenceSectionEditorDialogState();
}

class _PreferenceSectionEditorDialogState
    extends State<_PreferenceSectionEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, dynamic> _values;
  late final Map<String, TextEditingController> _textControllers;

  @override
  void initState() {
    super.initState();
    _values = Map<String, dynamic>.from(widget.initialValues);
    _textControllers = {
      for (final field in widget.section.fields)
        if (field.input == 'suggested_text')
          field.storagePath: TextEditingController(
            text: (_values[field.storagePath] as String?) ?? '',
          ),
    };
  }

  @override
  void dispose() {
    for (final controller in _textControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Edit ${widget.section.label}'),
      content: SizedBox(
        width: 620,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: widget.section.fields
                  .map((field) => Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _buildField(field),
                      ))
                  .toList(growable: false),
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
          child: const Text('Save'),
        ),
      ],
    );
  }

  Widget _buildField(CoquiProfilePreferenceField field) {
    switch (field.input) {
      case 'toggle':
        return SwitchListTile(
          key: ValueKey('preference-field-${field.storagePath}'),
          contentPadding: EdgeInsets.zero,
          title: Text(field.label),
          subtitle: Text(field.description),
          value: (_values[field.storagePath] as bool?) ?? false,
          onChanged: (value) => setState(() {
            _values[field.storagePath] = value;
          }),
        );
      case 'select':
        return DropdownButtonFormField<String>(
          key: ValueKey('preference-field-${field.storagePath}'),
          value: _values[field.storagePath] as String?,
          decoration: InputDecoration(
            labelText: field.label,
            helperText: field.description,
          ),
          items: field.options
              .map(
                (option) => DropdownMenuItem<String>(
                  value: option,
                  child: Text(option),
                ),
              )
              .toList(growable: false),
          onChanged: (value) => setState(() {
            _values[field.storagePath] = value;
          }),
        );
      case 'multi_select':
        final selected = List<String>.from(
          (_values[field.storagePath] as List?)?.whereType<String>() ?? const [],
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(field.label, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              field.description,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: field.optionItems
                  .map(
                    (option) => FilterChip(
                      key: ValueKey(
                        'preference-field-${field.storagePath}-${option.value}',
                      ),
                      label: Text(option.label),
                      selected: selected.contains(option.value),
                      onSelected: (isSelected) {
                        setState(() {
                          final next = [...selected];
                          if (isSelected) {
                            next.add(option.value);
                          } else {
                            next.remove(option.value);
                          }
                          _values[field.storagePath] = next.toSet().toList()..sort();
                        });
                      },
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
        );
      case 'suggested_text':
      default:
        final controller = _textControllers[field.storagePath]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              key: ValueKey('preference-field-${field.storagePath}'),
              controller: controller,
              decoration: InputDecoration(
                labelText: field.label,
                helperText: field.description,
              ),
              minLines: 1,
              maxLines: 3,
              onChanged: (value) => _values[field.storagePath] = value,
            ),
            if (field.suggestions.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: field.suggestions
                    .map(
                      (suggestion) => ActionChip(
                        label: Text(suggestion),
                        onPressed: () {
                          controller.text = suggestion;
                          _values[field.storagePath] = suggestion;
                        },
                      ),
                    )
                    .toList(growable: false),
              ),
            ],
          ],
        );
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    Navigator.pop(context, _values);
  }
}

class _BackstoryFolderDialog extends StatefulWidget {
  final String parentFolder;

  const _BackstoryFolderDialog({required this.parentFolder});

  @override
  State<_BackstoryFolderDialog> createState() => _BackstoryFolderDialogState();
}

class _BackstoryFolderDialogState extends State<_BackstoryFolderDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create Backstory Folder'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InputDecorator(
                decoration: const InputDecoration(labelText: 'Create In'),
                child: Text(
                  widget.parentFolder.isEmpty ? 'Root' : widget.parentFolder,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Folder Name',
                  helperText: 'Use a single folder name. The current folder is chosen for you.',
                ),
                validator: (value) {
                  final path = value?.trim() ?? '';
                  if (path.isEmpty) {
                    return 'Folder name is required.';
                  }
                  if (path.contains('/')) {
                    return 'Use a folder name, not a full path.';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) {
              return;
            }
            Navigator.pop(context, _nameController.text.trim());
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
}

class _BackstoryEntryDraft {
  final String path;
  final String content;

  const _BackstoryEntryDraft({required this.path, required this.content});
}

class _BackstoryEntryEditorDialog extends StatefulWidget {
  final String? initialPath;
  final String? initialContent;
  final String parentFolder;

  const _BackstoryEntryEditorDialog({
    this.initialPath,
    this.initialContent,
    required this.parentFolder,
  });

  @override
  State<_BackstoryEntryEditorDialog> createState() =>
      _BackstoryEntryEditorDialogState();
}

class _BackstoryEntryEditorDialogState
    extends State<_BackstoryEntryEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _contentController;

  bool get _isEditingExisting => widget.initialPath != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.initialPath == null
          ? ''
          : _leafName(widget.initialPath!),
    );
    _contentController = TextEditingController(text: widget.initialContent ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditingExisting ? 'Edit Source File' : 'New Source File'),
      content: SizedBox(
        width: 640,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                InputDecorator(
                  decoration: const InputDecoration(labelText: 'Folder'),
                  child: Text(
                    _isEditingExisting
                        ? _parentPath(widget.initialPath!)
                                .replaceFirst(RegExp(r'^$'), 'Root')
                        : (widget.parentFolder.isEmpty ? 'Root' : widget.parentFolder),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nameController,
                  enabled: !_isEditingExisting,
                  decoration: InputDecoration(
                    labelText: _isEditingExisting ? 'File Name' : 'File Name',
                    helperText: 'Use a single file name with extension. The folder is chosen for you.',
                  ),
                  validator: (value) {
                    final path = value?.trim() ?? '';
                    if (path.isEmpty) {
                      return 'Source file name is required.';
                    }
                    if (path.contains('/')) {
                      return 'Use a file name, not a full path.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _contentController,
                  decoration: const InputDecoration(
                    labelText: 'Content',
                    alignLabelWithHint: true,
                  ),
                  minLines: 14,
                  maxLines: 22,
                  validator: (value) {
                    if ((value?.trim() ?? '').isEmpty) {
                      return 'Source content is required.';
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
          onPressed: () {
            if (!_formKey.currentState!.validate()) {
              return;
            }
            Navigator.pop(
              context,
              _BackstoryEntryDraft(
                path: _isEditingExisting
                    ? widget.initialPath!
                    : _joinPath(widget.parentFolder, _nameController.text.trim()),
                content: _contentController.text.trim(),
              ),
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }

  String _joinPath(String parent, String name) {
    return parent.isEmpty ? name : '$parent/$name';
  }

  String _parentPath(String path) {
    if (!path.contains('/')) {
      return '';
    }
    return path.substring(0, path.lastIndexOf('/'));
  }

  String _leafName(String path) {
    final segments = path.split('/');
    return segments.last;
  }
}
