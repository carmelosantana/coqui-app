import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:coqui_app/Models/coqui_artifact.dart';
import 'package:coqui_app/Models/coqui_artifact_version.dart';
import 'package:coqui_app/Models/coqui_project.dart';
import 'package:coqui_app/Models/coqui_sprint.dart';
import 'package:coqui_app/Providers/work_provider.dart';

import 'artifact_editor_sheet.dart';
import 'artifact_stage_badge.dart';

class ArtifactDetailSheet extends StatefulWidget {
  final String sessionId;
  final CoquiArtifact artifact;
  final List<CoquiProject> availableProjects;
  final List<CoquiSprint> availableSprints;
  final bool readOnly;

  const ArtifactDetailSheet({
    super.key,
    required this.sessionId,
    required this.artifact,
    required this.availableProjects,
    required this.availableSprints,
    required this.readOnly,
  });

  @override
  State<ArtifactDetailSheet> createState() => _ArtifactDetailSheetState();
}

class _ArtifactDetailSheetState extends State<ArtifactDetailSheet> {
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
    final provider = context.read<WorkProvider>();
    await provider.loadArtifactDetail(
      widget.sessionId,
      widget.artifact.id,
      force: force,
    );
    await provider.fetchArtifactVersions(
      widget.sessionId,
      widget.artifact.id,
      force: force,
    );
    if (mounted) {
      setState(() => _isRefreshing = false);
    }
  }

  Future<void> _edit(CoquiArtifact artifact) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<WorkProvider>(),
        child: ArtifactEditorSheet(
          sessionId: widget.sessionId,
          artifact: artifact,
          availableProjects: widget.availableProjects,
          availableSprints: widget.availableSprints,
          initialProjectId: artifact.projectId,
          initialSprintId: artifact.sprintId,
        ),
      ),
    );
    if (mounted) {
      await _refresh(force: true);
    }
  }

  Future<void> _delete(CoquiArtifact artifact) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${artifact.label}?'),
        content: const Text(
          'This removes the artifact and its version history from the current chat session.',
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

    final provider = context.read<WorkProvider>();
    final success =
        await provider.deleteArtifact(widget.sessionId, artifact.id);
    if (!mounted) return;
    if (success) {
      Navigator.pop(context);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Artifact deleted.'
              : provider.error ?? 'Unable to delete artifact',
        ),
      ),
    );
  }

  Future<void> _restoreVersion(CoquiArtifactVersion version) async {
    final provider = context.read<WorkProvider>();
    final restored = await provider.restoreArtifactVersion(
      widget.sessionId,
      widget.artifact.id,
      version.id,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          restored != null
              ? 'Artifact restored to version ${version.version}.'
              : provider.error ?? 'Unable to restore artifact version',
        ),
      ),
    );
  }

  Future<void> _copyPath(String path) async {
    await Clipboard.setData(ClipboardData(text: path));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Path copied to clipboard.')),
    );
  }

  Future<void> _previewVersion(
    CoquiArtifact artifact,
    CoquiArtifactVersion version,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _ArtifactVersionPreviewSheet(
        artifact: artifact,
        version: version,
      ),
    );
  }

  Future<void> _compareVersion(
    CoquiArtifact artifact,
    CoquiArtifactVersion version,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _ArtifactVersionCompareSheet(
        artifact: artifact,
        version: version,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Consumer<WorkProvider>(
      builder: (context, provider, _) {
        final artifact =
            provider.artifactById(widget.sessionId, widget.artifact.id) ??
                widget.artifact;
        final versions = provider.versionsForArtifact(widget.artifact.id);
        final project = widget.availableProjects
            .where((item) => item.id == artifact.projectId)
            .firstOrNull;
        final sprint = widget.availableSprints
            .where((item) => item.id == artifact.sprintId)
            .firstOrNull;

        return SafeArea(
          child: DraggableScrollableSheet(
            initialChildSize: 0.88,
            minChildSize: 0.62,
            maxChildSize: 0.96,
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
                            artifact.label,
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
                            ArtifactStageBadge(artifact: artifact),
                            _InfoChip(label: artifact.type),
                            _InfoChip(label: 'Version ${artifact.version}'),
                            _InfoChip(label: artifact.storageLabel),
                            if (artifact.persistent)
                              const _InfoChip(label: 'Persistent'),
                            if (project != null)
                              _InfoChip(label: project.label),
                            if (sprint != null) _InfoChip(label: sprint.label),
                          ],
                        ),
                        if (artifact.summary != null) ...[
                          const SizedBox(height: 16),
                          Text(artifact.summary!,
                              style: theme.textTheme.bodyMedium),
                        ],
                        if (artifact.tags.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: artifact.tags
                                .map((tag) => _InfoChip(label: '#$tag'))
                                .toList(),
                          ),
                        ],
                        const SizedBox(height: 16),
                        _SectionCard(
                          title: 'Storage',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _MetaRow(
                                label: 'Source',
                                value: artifact.storageLabel,
                              ),
                              if (artifact.hasFilePath)
                                _MetaRow(
                                  label: 'Requested path',
                                  value: artifact.filepath!,
                                  onCopy: () => _copyPath(artifact.filepath!),
                                ),
                              if (artifact.hasCanonicalPath)
                                _MetaRow(
                                  label: 'Canonical path',
                                  value: artifact.canonicalPath!,
                                  onCopy: () =>
                                      _copyPath(artifact.canonicalPath!),
                                ),
                              if (artifact.contentHash?.isNotEmpty == true)
                                _MetaRow(
                                  label: 'Content hash',
                                  value: artifact.contentHash!,
                                ),
                              if (artifact.isFilesystemBacked) ...[
                                const SizedBox(height: 12),
                                const _WorkspaceBackedBanner(
                                  message:
                                      'This artifact is backed by a workspace file. The project or session links still live in Coqui, but the content also has a canonical path on disk.',
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        _SectionCard(
                          title: 'Artifact Actions',
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              FilledButton.tonalIcon(
                                onPressed: widget.readOnly
                                    ? null
                                    : () => _edit(artifact),
                                icon: const Icon(Icons.edit_outlined),
                                label: const Text('Edit'),
                              ),
                              OutlinedButton.icon(
                                onPressed: widget.readOnly
                                    ? null
                                    : () => _delete(artifact),
                                icon: const Icon(Icons.delete_outline),
                                label: const Text('Delete'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        _SectionCard(
                          title: 'Content',
                          child: SelectableText(
                            artifact.content,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _SectionCard(
                          title: 'Versions',
                          child: versions.isEmpty
                              ? Text(
                                  'No prior versions recorded yet.',
                                  style: theme.textTheme.bodySmall,
                                )
                              : Column(
                                  children: versions.map((version) {
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 12),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme
                                            .surfaceContainerHighest,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Version ${version.version}',
                                            style: theme.textTheme.titleSmall
                                                ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            version.changeSummary?.isNotEmpty ==
                                                    true
                                                ? version.changeSummary!
                                                : 'No change summary',
                                            style: theme.textTheme.bodySmall,
                                          ),
                                          if (version.createdAt != null) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              'Saved ${_formatDateTime(version.createdAt!)}',
                                              style: theme.textTheme.bodySmall,
                                            ),
                                          ],
                                          const SizedBox(height: 12),
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            children: [
                                              OutlinedButton.icon(
                                                onPressed: () =>
                                                    _previewVersion(
                                                  artifact,
                                                  version,
                                                ),
                                                icon: const Icon(
                                                  Icons.preview_outlined,
                                                ),
                                                label: const Text('Preview'),
                                              ),
                                              OutlinedButton.icon(
                                                onPressed: () =>
                                                    _compareVersion(
                                                  artifact,
                                                  version,
                                                ),
                                                icon: const Icon(
                                                  Icons.compare_arrows_outlined,
                                                ),
                                                label: const Text('Compare'),
                                              ),
                                              if (!widget.readOnly)
                                                TextButton(
                                                  onPressed: () =>
                                                      _restoreVersion(version),
                                                  child: const Text('Restore'),
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
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

class _MetaRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback? onCopy;

  const _MetaRow({
    required this.label,
    required this.value,
    this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                  ),
            ),
          ),
          if (onCopy != null)
            IconButton(
              onPressed: onCopy,
              icon: const Icon(Icons.copy_all_outlined),
              tooltip: 'Copy',
            ),
        ],
      ),
    );
  }
}

class _WorkspaceBackedBanner extends StatelessWidget {
  final String message;

  const _WorkspaceBackedBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Text(message, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}

class _ArtifactVersionPreviewSheet extends StatelessWidget {
  final CoquiArtifact artifact;
  final CoquiArtifactVersion version;

  const _ArtifactVersionPreviewSheet({
    required this.artifact,
    required this.version,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.48,
      maxChildSize: 0.94,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color:
                    theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${artifact.label} · Version ${version.version}',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
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
                  if (version.changeSummary?.isNotEmpty == true) ...[
                    _SectionCard(
                      title: 'Change Summary',
                      child: Text(version.changeSummary!),
                    ),
                    const SizedBox(height: 16),
                  ],
                  _SectionCard(
                    title: 'Snapshot Content',
                    child: SelectableText(
                      version.content,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ArtifactVersionCompareSheet extends StatelessWidget {
  final CoquiArtifact artifact;
  final CoquiArtifactVersion version;

  const _ArtifactVersionCompareSheet({
    required this.artifact,
    required this.version,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.56,
      maxChildSize: 0.96,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color:
                    theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Compare Current vs Version ${version.version}',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
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
                  if (artifact.isFilesystemBacked)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: _WorkspaceBackedBanner(
                        message:
                            'The current pane reflects the artifact currently linked to the workspace-backed source.',
                      ),
                    ),
                  _SectionCard(
                    title: 'Current Content',
                    child: SelectableText(
                      artifact.content,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _SectionCard(
                    title: 'Version ${version.version} Snapshot',
                    child: SelectableText(
                      version.content,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

String _formatDateTime(DateTime dateTime) {
  final local = dateTime.toLocal();
  return '${local.year}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')} '
      '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
}
