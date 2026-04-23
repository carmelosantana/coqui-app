import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:coqui_app/Models/coqui_session.dart';
import 'package:coqui_app/Providers/chat_provider.dart';
import 'package:coqui_app/Services/coqui_api_service.dart';
import 'package:coqui_app/Widgets/bottom_sheet_header.dart';

Future<CoquiSession?> showChannelBoundSessionPicker({
  required BuildContext context,
  required CoquiApiService apiService,
  String? currentChannelId,
  String? currentSelectionId,
}) {
  return showModalBottomSheet<CoquiSession>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => _ChannelBoundSessionPickerSheet(
      apiService: apiService,
      currentChannelId: currentChannelId,
      currentSelectionId: currentSelectionId,
    ),
  );
}

class _ChannelBoundSessionPickerSheet extends StatefulWidget {
  final CoquiApiService apiService;
  final String? currentChannelId;
  final String? currentSelectionId;

  const _ChannelBoundSessionPickerSheet({
    required this.apiService,
    required this.currentChannelId,
    required this.currentSelectionId,
  });

  @override
  State<_ChannelBoundSessionPickerSheet> createState() =>
      _ChannelBoundSessionPickerSheetState();
}

class _ChannelBoundSessionPickerSheetState
    extends State<_ChannelBoundSessionPickerSheet> {
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  String? _errorMessage;
  List<CoquiSession> _sessions = const [];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_handleSearchChanged);
    _loadSessions();
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_handleSearchChanged)
      ..dispose();
    super.dispose();
  }

  void _handleSearchChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadSessions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final sessions = await widget.apiService.listSessions(
        limit: 200,
        status: 'all',
      );
      sessions.sort((left, right) => right.updatedAt.compareTo(left.updatedAt));

      setState(() {
        _sessions = sessions
            .where((session) => !session.isReadOnly && !session.isGroupSession)
            .toList(growable: false);
        _isLoading = false;
      });
    } catch (error) {
      setState(() {
        _errorMessage = error.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredSessions = _filteredSessions();

    return DraggableScrollableSheet(
      initialChildSize: 0.84,
      minChildSize: 0.55,
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
                  color: Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant
                      .withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const BottomSheetHeader(title: 'Choose Bound Session'),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bind this channel to one active interactive session. Coqui will reuse that session for inbound messages instead of creating per-conversation sessions.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: 'Search by title, profile, role, or session ID',
                      suffixIcon: _searchController.text.isEmpty
                          ? null
                          : IconButton(
                              onPressed: _searchController.clear,
                              icon: const Icon(Icons.close),
                            ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Only active one-on-one interactive sessions are shown. Group, closed, and archived sessions are excluded.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _buildBody(context, scrollController, filteredSessions),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBody(
    BuildContext context,
    ScrollController scrollController,
    List<CoquiSession> filteredSessions,
  ) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                color: Theme.of(context).colorScheme.error,
                size: 32,
              ),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _loadSessions,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (filteredSessions.isEmpty) {
      return ListView(
        controller: scrollController,
        padding: const EdgeInsets.all(24),
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 36,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(
            _searchController.text.isEmpty
                ? 'No active interactive sessions are available to bind.'
                : 'No sessions match that search.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            _searchController.text.isEmpty
                ? 'Start or resume a chat session first, then come back here to bind the channel.'
                : 'Try a different title, profile, model role, or session ID fragment.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      );
    }

    return ListView.separated(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: filteredSessions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final session = filteredSessions[index];
        final disabled = _isDisabled(session);
        final selected = session.id == widget.currentSelectionId;

        return _ChannelBoundSessionOptionCard(
          session: session,
          selected: selected,
          disabled: disabled,
          onTap: disabled ? null : () => Navigator.of(context).pop(session),
          disabledReason: disabled
              ? 'Already linked to ${session.channel?.displayLabel ?? 'another channel'}.'
              : null,
        );
      },
    );
  }

  List<CoquiSession> _filteredSessions() {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      return _sessions;
    }

    return _sessions.where((session) {
      final haystack = [
        session.displayTitle,
        session.profileLabel,
        session.compactParticipantSummary,
        session.modelRole,
        session.id,
        session.channelSummaryLabel,
      ].whereType<String>().join(' ').toLowerCase();

      return haystack.contains(query);
    }).toList(growable: false);
  }

  bool _isDisabled(CoquiSession session) {
    if (!session.isChannelBound) {
      return false;
    }

    final boundInstanceId = session.channel?.instanceId;
    return boundInstanceId != null &&
        boundInstanceId != widget.currentChannelId;
  }
}

class _ChannelBoundSessionOptionCard extends StatelessWidget {
  final CoquiSession session;
  final bool selected;
  final bool disabled;
  final String? disabledReason;
  final VoidCallback? onTap;

  const _ChannelBoundSessionOptionCard({
    required this.session,
    required this.selected,
    required this.disabled,
    required this.onTap,
    required this.disabledReason,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor =
        selected ? theme.colorScheme.primary : theme.dividerColor;
    final backgroundColor = selected
        ? theme.colorScheme.primaryContainer.withValues(alpha: 0.35)
        : theme.colorScheme.surface;

    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      session.displayTitle,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: disabled
                            ? theme.colorScheme.onSurfaceVariant
                            : null,
                      ),
                    ),
                  ),
                  if (selected)
                    Icon(
                      Icons.check_circle,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _SessionMetaChip(label: session.profileLabel ?? 'Unprofiled'),
                  _SessionMetaChip(label: session.modelRole),
                  _SessionMetaChip(
                    label:
                        'Last active ${formatSessionRelativeTime(session.updatedAt)}',
                  ),
                  _SessionMetaChip(label: session.shortId),
                  if (session.channelSummaryLabel != null)
                    _SessionMetaChip(label: session.channelSummaryLabel!),
                ],
              ),
              if (disabledReason != null) ...[
                const SizedBox(height: 8),
                Text(
                  disabledReason!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class SessionSummaryCard extends StatelessWidget {
  final CoquiSession? session;
  final String? fallbackSessionId;
  final bool isLoading;
  final String? errorText;
  final String title;
  final String emptyText;
  final VoidCallback? onSelect;
  final VoidCallback? onClear;
  final VoidCallback? onOpenSession;

  const SessionSummaryCard({
    super.key,
    required this.title,
    required this.emptyText,
    this.session,
    this.fallbackSessionId,
    this.isLoading = false,
    this.errorText,
    this.onSelect,
    this.onClear,
    this.onOpenSession,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              if (isLoading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (session != null) ...[
            Text(
              session!.displayTitle,
              style: theme.textTheme.bodyLarge
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _SessionMetaChip(label: session!.profileLabel ?? 'Unprofiled'),
                _SessionMetaChip(label: session!.modelRole),
                _SessionMetaChip(
                  label:
                      'Last active ${formatSessionRelativeTime(session!.updatedAt)}',
                ),
                _SessionMetaChip(label: session!.shortId),
                if (session!.channelSummaryLabel != null)
                  _SessionMetaChip(label: session!.channelSummaryLabel!),
              ],
            ),
          ] else if (fallbackSessionId?.isNotEmpty ?? false) ...[
            Text(
              'Session ${_shortId(fallbackSessionId!)}',
              style: theme.textTheme.bodyLarge
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              errorText ??
                  'Coqui has a saved bound session ID, but the session details could not be loaded right now.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: errorText != null
                    ? theme.colorScheme.error
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ] else ...[
            Text(
              emptyText,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (onSelect != null || onClear != null) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (onSelect != null)
                  FilledButton.tonalIcon(
                    onPressed: onSelect,
                    icon: const Icon(Icons.search),
                    label: Text(session == null ? 'Choose Session' : 'Change'),
                  ),
                if (onOpenSession != null && session != null)
                  OutlinedButton.icon(
                    onPressed: onOpenSession,
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Open Session'),
                  ),
                if (onClear != null &&
                    (session != null || fallbackSessionId != null))
                  TextButton.icon(
                    onPressed: onClear,
                    icon: const Icon(Icons.link_off),
                    label: const Text('Clear'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SessionMetaChip extends StatelessWidget {
  final String label;

  const _SessionMetaChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall,
      ),
    );
  }
}

Future<void> openChannelBoundSession(
  BuildContext context,
  CoquiSession session,
) async {
  final chatProvider = context.read<ChatProvider>();
  final navigator = Navigator.of(context);
  final messenger = ScaffoldMessenger.of(context);

  await chatProvider.refreshSessions();

  final sessionExists = chatProvider.sessions.any(
    (candidate) => candidate.id == session.id,
  );

  if (!context.mounted) {
    return;
  }

  if (!sessionExists) {
    messenger.showSnackBar(
      const SnackBar(
        content: Text(
            'The selected session is not available in the active chat list.'),
      ),
    );
    return;
  }

  chatProvider.openSession(session.id);
  navigator.popUntil((route) => route.isFirst);
}

String formatSessionRelativeTime(DateTime dateTime) {
  final delta = DateTime.now().difference(dateTime.toLocal());
  if (delta.inSeconds < 60) return '${delta.inSeconds}s ago';
  if (delta.inMinutes < 60) return '${delta.inMinutes}m ago';
  if (delta.inHours < 24) return '${delta.inHours}h ago';
  return '${delta.inDays}d ago';
}

String _shortId(String id) {
  return id.length <= 8 ? id : id.substring(0, 8);
}
