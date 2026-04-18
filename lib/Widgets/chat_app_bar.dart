import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:coqui_app/Models/coqui_child_run.dart';
import 'package:coqui_app/Theme/coqui_typography.dart';
import 'package:coqui_app/Models/coqui_role.dart';
import 'package:coqui_app/Models/coqui_session_file.dart';
import 'package:coqui_app/Providers/chat_provider.dart';
import 'package:coqui_app/Providers/instance_provider.dart';
import 'package:coqui_app/Services/coqui_api_service.dart';
import 'package:coqui_app/Widgets/bottom_sheet_header.dart';
import 'package:coqui_app/Widgets/profile_picker_dialog.dart';
import 'package:coqui_app/Widgets/role_list_tile.dart';
import 'package:coqui_app/Widgets/selection_bottom_sheet.dart';
import 'package:provider/provider.dart';
import 'package:responsive_framework/responsive_framework.dart';

class ChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  const ChatAppBar({super.key});

  @override
  Widget build(BuildContext context) {
    final chatProvider = Provider.of<ChatProvider>(context);
    final instanceProvider = Provider.of<InstanceProvider>(context);

    return AppBar(
      centerTitle: false,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Server selector dropdown
          _ServerDropdown(instanceProvider: instanceProvider),
          if (chatProvider.currentSession != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  ActionChip(
                    label: Text(
                      chatProvider.currentSession!.modelRole,
                      style: CoquiTypography.monoStyle(
                        Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                    onPressed: () => _handleRoleSelectionButton(context),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.person_outline, size: 16),
                    label: Text(
                      chatProvider.currentSession!.profile?.isNotEmpty == true
                          ? chatProvider.currentSession!.profile!
                          : 'No profile',
                    ),
                    onPressed: () => _handleProfileSelection(context),
                  ),
                ],
              ),
            ),
        ],
      ),
      actions: [
        if (chatProvider.currentSession != null)
          IconButton(
            icon: const Icon(Icons.tune),
            onPressed: () {
              _handleConfigureButton(context);
            },
          ),
      ],
      forceMaterialTransparency: !ResponsiveBreakpoints.of(context).isMobile,
    );
  }

  Future<void> _handleRoleSelectionButton(BuildContext context) async {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final currentSession = chatProvider.currentSession;
    if (currentSession == null) return;

    final selectedRole = await showSelectionBottomSheet<CoquiRole>(
      context: context,
      header: const BottomSheetHeader(title: "Available Roles"),
      fetchItems: () async {
        return await chatProvider.fetchAvailableRoles();
      },
      currentSelection: CoquiRole(
        name: currentSession.modelRole,
        model: currentSession.model,
      ),
      itemBuilder: (role, selected, onSelected) {
        return RoleListTile(
          role: role,
          selected: selected,
          onSelected: onSelected,
        );
      },
    );

    if (selectedRole != null &&
        selectedRole.name != currentSession.modelRole &&
        context.mounted) {
      await chatProvider.updateSessionRole(currentSession.id, selectedRole.name);
    }
  }

  Future<void> _handleProfileSelection(BuildContext context) async {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final session = chatProvider.currentSession;
    if (session == null) return;

    final selectedProfile = await showProfilePickerDialog(
      context: context,
      title: 'Session Profile',
      fetchProfiles: chatProvider.fetchKnownProfiles,
      initialValue: session.profile,
    );

    if (selectedProfile != null && context.mounted) {
      await chatProvider.updateSessionProfile(
        session.id,
        selectedProfile.isEmpty ? null : selectedProfile,
      );
    }
  }

  Future<void> _handleConfigureButton(BuildContext context) async {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);

    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          minimum: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const BottomSheetHeader(title: 'Session Options'),
              const Divider(),
              if (chatProvider.lastTurnSummary != null)
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('Last Turn'),
                  subtitle: Text(chatProvider.lastTurnSummary!),
                ),
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text('Change Profile'),
                subtitle: Text(
                  chatProvider.currentSession?.profile?.isNotEmpty == true
                      ? chatProvider.currentSession!.profile!
                      : 'No profile selected',
                ),
                onTap: () => Navigator.pop(context, 'profile'),
              ),
              ListTile(
                leading: const Icon(Icons.folder_outlined),
                title: const Text('Session Files'),
                onTap: () => Navigator.pop(context, 'files'),
              ),
              ListTile(
                leading: const Icon(Icons.account_tree_outlined),
                title: const Text('Child Runs'),
                onTap: () => Navigator.pop(context, 'child_runs'),
              ),
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Rename Session'),
                onTap: () => Navigator.pop(context, 'rename'),
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Delete Session'),
                textColor: Theme.of(context).colorScheme.error,
                iconColor: Theme.of(context).colorScheme.error,
                onTap: () => Navigator.pop(context, 'delete'),
              ),
            ],
          ),
        );
      },
    );

    if (action == 'delete') {
      await chatProvider.deleteCurrentSession();
    } else if (action == 'profile') {
      if (context.mounted) {
        await _handleProfileSelection(context);
      }
    } else if (action == 'files') {
      final session = chatProvider.currentSession;
      if (session != null && context.mounted) {
        await showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          builder: (_) => _SessionFilesSheet(sessionId: session.id),
        );
      }
    } else if (action == 'child_runs') {
      final session = chatProvider.currentSession;
      if (session != null && context.mounted) {
        await showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          builder: (_) => _ChildRunsSheet(sessionId: session.id),
        );
      }
    } else if (action == 'rename') {
      if (context.mounted) {
        await _showRenameDialog(context, chatProvider);
      }
    }
  }

  Future<void> _showRenameDialog(
    BuildContext context,
    ChatProvider chatProvider,
  ) async {
    final session = chatProvider.currentSession;
    if (session == null) return;

    final controller = TextEditingController(text: session.title ?? '');
    final newTitle = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Session'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Session title',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (value) => Navigator.pop(context, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newTitle != null && newTitle.isNotEmpty) {
      await chatProvider.renameSession(session.id, newTitle);
    }
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _SessionFilesSheet extends StatefulWidget {
  final String sessionId;

  const _SessionFilesSheet({required this.sessionId});

  @override
  State<_SessionFilesSheet> createState() => _SessionFilesSheetState();
}

class _SessionFilesSheetState extends State<_SessionFilesSheet> {
  bool _isLoading = true;
  List<CoquiSessionFile> _files = const [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = context.read<CoquiApiService>();
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final files = await api.listSessionFiles(widget.sessionId);
      if (!mounted) return;
      setState(() {
        _files = files;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteFile(CoquiSessionFile file) async {
    final api = context.read<CoquiApiService>();
    await api.deleteSessionFile(widget.sessionId, file.id);
    await _load();
  }

  void _openFile(CoquiSessionFile file) {
    final api = context.read<CoquiApiService>();
    if (api.apiKey.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Direct file open is only available when the server does not require an API key.',
          ),
        ),
      );
      return;
    }

    launchUrlString(api.getSessionFileUrl(widget.sessionId, file.id).toString());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 12, bottom: 8),
              child: BottomSheetHeader(title: 'Session Files'),
            ),
            const Divider(height: 1),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(_error!, textAlign: TextAlign.center),
                          ),
                        )
                      : _files.isEmpty
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(24),
                                child: Text('No uploaded files for this session.'),
                              ),
                            )
                          : ListView.separated(
                              controller: scrollController,
                              padding: const EdgeInsets.all(16),
                              itemCount: _files.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final file = _files[index];
                                return Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: theme.dividerColor),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        file.isImage
                                            ? Icons.image_outlined
                                            : Icons.description_outlined,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              file.originalName,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: theme.textTheme.titleSmall,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${file.mimeType} · ${file.sizeLabel}',
                                              style: theme.textTheme.bodySmall?.copyWith(
                                                color: theme.colorScheme.onSurfaceVariant,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: 'Open',
                                        icon: const Icon(Icons.open_in_new),
                                        onPressed: () => _openFile(file),
                                      ),
                                      IconButton(
                                        tooltip: 'Delete',
                                        icon: const Icon(Icons.delete_outline),
                                        onPressed: () => _deleteFile(file),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
            ),
          ],
        );
      },
    );
  }
}

class _ChildRunsSheet extends StatefulWidget {
  final String sessionId;

  const _ChildRunsSheet({required this.sessionId});

  @override
  State<_ChildRunsSheet> createState() => _ChildRunsSheetState();
}

class _ChildRunsSheetState extends State<_ChildRunsSheet> {
  bool _isLoading = true;
  List<CoquiChildRun> _runs = const [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = context.read<CoquiApiService>();
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final runs = await api.listChildRuns(widget.sessionId);
      if (!mounted) return;
      setState(() {
        _runs = runs;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 12, bottom: 8),
              child: BottomSheetHeader(title: 'Child Runs'),
            ),
            const Divider(height: 1),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(_error!, textAlign: TextAlign.center),
                          ),
                        )
                      : _runs.isEmpty
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(24),
                                child: Text('No child runs recorded for this session.'),
                              ),
                            )
                          : ListView.separated(
                              controller: scrollController,
                              padding: const EdgeInsets.all(16),
                              itemCount: _runs.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final run = _runs[index];
                                return Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: theme.dividerColor),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${run.agentRole} · iteration ${run.parentIteration}',
                                        style: theme.textTheme.titleSmall,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        run.model,
                                        style: theme.textTheme.labelSmall?.copyWith(
                                          color: theme.colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        run.promptPreview,
                                        style: theme.textTheme.bodySmall,
                                      ),
                                      if (run.result.isNotEmpty) ...[
                                        const SizedBox(height: 8),
                                        Text(
                                          run.resultPreview,
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            color: theme.colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                );
                              },
                            ),
            ),
          ],
        );
      },
    );
  }
}

/// Dropdown for quick server switching directly in the app bar.
class _ServerDropdown extends StatelessWidget {
  final InstanceProvider instanceProvider;

  const _ServerDropdown({required this.instanceProvider});

  Color _statusColor(BuildContext context) {
    return switch (instanceProvider.isOnline) {
      true => Colors.green,
      false => Theme.of(context).colorScheme.error,
      null => Theme.of(context).colorScheme.onSurfaceVariant,
    };
  }

  @override
  Widget build(BuildContext context) {
    final instances = instanceProvider.instances;
    final active = instanceProvider.activeInstance;

    if (instances.isEmpty) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.dns_outlined,
            size: 16,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 4),
          Text(
            'No Server',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      );
    }

    Widget statusDot = Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _statusColor(context),
      ),
    );

    if (instances.length == 1) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          statusDot,
          const SizedBox(width: 6),
          Icon(
            Icons.dns,
            size: 16,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              active?.name ?? instances.first.name,
              style: Theme.of(context).textTheme.labelMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }

    return PopupMenuButton<String>(
      tooltip: 'Switch server',
      offset: const Offset(0, 40),
      onSelected: (id) {
        instanceProvider.setActiveInstance(id);
      },
      itemBuilder: (context) => instances.map((instance) {
        final isActive = instance.id == active?.id;
        return PopupMenuItem<String>(
          value: instance.id,
          child: Row(
            children: [
              Icon(
                isActive ? Icons.dns : Icons.dns_outlined,
                size: 18,
                color: isActive ? Theme.of(context).colorScheme.primary : null,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  instance.name,
                  style: isActive
                      ? TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        )
                      : null,
                ),
              ),
              if (isActive)
                Icon(
                  Icons.check,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
            ],
          ),
        );
      }).toList(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          statusDot,
          const SizedBox(width: 6),
          Icon(
            Icons.dns,
            size: 16,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              active?.name ?? 'Select Server',
              style: Theme.of(context).textTheme.labelMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Icon(Icons.arrow_drop_down, size: 18),
        ],
      ),
    );
  }
}
