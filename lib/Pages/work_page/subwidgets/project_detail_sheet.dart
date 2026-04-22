import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:coqui_app/Models/coqui_project.dart';
import 'package:coqui_app/Providers/chat_provider.dart';
import 'package:coqui_app/Providers/project_provider.dart';

import 'project_editor_sheet.dart';
import 'project_status_badge.dart';
import 'sprint_status_badge.dart';

class ProjectDetailSheet extends StatefulWidget {
  final CoquiProject project;

  const ProjectDetailSheet({
    super.key,
    required this.project,
  });

  @override
  State<ProjectDetailSheet> createState() => _ProjectDetailSheetState();
}

class _ProjectDetailSheetState extends State<ProjectDetailSheet> {
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refresh(force: true);
    });
  }

  Future<void> _refresh({bool force = false}) async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    final provider = context.read<ProjectProvider>();
    await provider.loadProjectDetail(widget.project.id, force: force);
    await provider.fetchProjectSprints(widget.project.id, force: force);
    if (mounted) {
      setState(() => _isRefreshing = false);
    }
  }

  Future<void> _edit(CoquiProject project) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<ProjectProvider>(),
        child: ProjectEditorSheet(project: project),
      ),
    );
    if (mounted) {
      await _refresh(force: true);
    }
  }

  Future<void> _toggleStatus(CoquiProject project) async {
    final provider = context.read<ProjectProvider>();
    final updated = project.isArchived
        ? await provider.activateProject(project.id)
        : await provider.archiveProject(project.id);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          updated != null
              ? (updated.isArchived
                  ? 'Project archived.'
                  : 'Project activated.')
              : provider.error ?? 'Unable to update project',
        ),
      ),
    );
  }

  Future<void> _deleteProject(CoquiProject project) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${project.label}?'),
        content: const Text(
          'Archived projects can be permanently deleted. This also clears any session active-project references.',
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

    if (confirmed != true || !mounted) return;

    final provider = context.read<ProjectProvider>();
    final success = await provider.deleteProject(project.id);
    if (!mounted) return;
    if (success) {
      Navigator.pop(context);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Project deleted.'
              : provider.error ?? 'Unable to delete project',
        ),
      ),
    );
  }

  Future<void> _setActiveProject(CoquiProject project) async {
    final chatProvider = context.read<ChatProvider>();
    final session = chatProvider.currentSession;
    if (session == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Open a chat session first')),
      );
      return;
    }

    await chatProvider.updateSessionActiveProject(
      session.id,
      projectId: project.id,
    );

    if (!mounted) return;
    final error = chatProvider.currentSessionError;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error == null
              ? 'Current chat is now linked to ${project.label}.'
              : error.message,
        ),
      ),
    );
  }

  Future<void> _clearActiveProject() async {
    final chatProvider = context.read<ChatProvider>();
    final session = chatProvider.currentSession;
    if (session == null) return;

    await chatProvider.updateSessionActiveProject(session.id, clear: true);

    if (!mounted) return;
    final error = chatProvider.currentSessionError;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error == null ? 'Current chat project cleared.' : error.message,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Consumer2<ProjectProvider, ChatProvider>(
      builder: (context, provider, chatProvider, _) {
        final project =
            provider.projectById(widget.project.id) ?? widget.project;
        final sprints = provider.sprintsForProject(project.id);
        final currentSession = chatProvider.currentSession;
        final isCurrentChatProject =
            currentSession?.activeProjectId == project.id;
        final canAssign =
            currentSession != null && !chatProvider.isCurrentSessionReadOnly;
        final isReadOnly = project.isReadOnlyInApp;

        return SafeArea(
          child: DraggableScrollableSheet(
            initialChildSize: 0.82,
            minChildSize: 0.58,
            maxChildSize: 0.94,
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
                        Expanded(
                          child: Text(
                            project.label,
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        IconButton(
                          onPressed: _isRefreshing
                              ? null
                              : () => _refresh(force: true),
                          icon: _isRefreshing
                              ? SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: theme.colorScheme.primary,
                                  ),
                                )
                              : const Icon(Icons.refresh),
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
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ProjectStatusBadge(project: project),
                            _InfoChip(label: project.slug),
                            _InfoChip(label: '${project.sprintCount} sprints'),
                            if (project.hasActiveSprint)
                              _InfoChip(label: 'Active sprint linked'),
                          ],
                        ),
                        if (project.hasDescription) ...[
                          const SizedBox(height: 16),
                          Text(project.description!,
                              style: theme.textTheme.bodyMedium),
                        ],
                        if (isReadOnly) ...[
                          const SizedBox(height: 16),
                          _SectionCard(
                            title: 'Read Only',
                            child: Text(
                              'Completed projects are view-only in the app to keep finished work distinct from active planning.',
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        _SectionCard(
                          title: 'Current Chat Context',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                currentSession == null
                                    ? 'Open a chat session to attach this project to your active conversation.'
                                    : isCurrentChatProject
                                        ? 'This project is already the active project for the current chat.'
                                        : 'Attach this project to the current chat so tasks, loops, and later work items inherit the right context.',
                                style: theme.textTheme.bodySmall,
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  FilledButton.icon(
                                    onPressed:
                                        canAssign && !isCurrentChatProject
                                            ? () => _setActiveProject(project)
                                            : null,
                                    icon: const Icon(Icons.link_outlined),
                                    label: const Text('Set For Current Chat'),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: canAssign && isCurrentChatProject
                                        ? _clearActiveProject
                                        : null,
                                    icon: const Icon(Icons.link_off_outlined),
                                    label: const Text('Clear Chat Project'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        _SectionCard(
                          title: 'Project Actions',
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              FilledButton.tonalIcon(
                                onPressed:
                                    isReadOnly ? null : () => _edit(project),
                                icon: const Icon(Icons.edit_outlined),
                                label: const Text('Edit'),
                              ),
                              FilledButton.tonalIcon(
                                onPressed: isReadOnly
                                    ? null
                                    : () => _toggleStatus(project),
                                icon: Icon(project.isArchived
                                    ? Icons.unarchive_outlined
                                    : Icons.archive_outlined),
                                label: Text(project.isArchived
                                    ? 'Activate'
                                    : 'Archive'),
                              ),
                              OutlinedButton.icon(
                                onPressed: project.canDelete
                                    ? () => _deleteProject(project)
                                    : null,
                                icon: const Icon(Icons.delete_outline),
                                label: const Text('Delete'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        _SectionCard(
                          title: 'Sprints',
                          child: sprints.isEmpty
                              ? Text(
                                  'No sprints exist yet for this project.',
                                  style: theme.textTheme.bodySmall,
                                )
                              : Column(
                                  children: sprints.take(4).map((sprint) {
                                    return ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      title: Text(sprint.label),
                                      subtitle: sprint.hasAcceptanceCriteria
                                          ? Text(
                                              sprint.acceptanceCriteria!,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            )
                                          : null,
                                      trailing:
                                          SprintStatusBadge(sprint: sprint),
                                    );
                                  }).toList(),
                                ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;

  const _InfoChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelSmall),
    );
  }
}
