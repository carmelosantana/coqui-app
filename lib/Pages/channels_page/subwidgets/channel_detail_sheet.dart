import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:coqui_app/Models/coqui_channel.dart';
import 'package:coqui_app/Models/coqui_channel_conversation.dart';
import 'package:coqui_app/Models/coqui_channel_delivery.dart';
import 'package:coqui_app/Models/coqui_channel_event.dart';
import 'package:coqui_app/Models/coqui_channel_link.dart';
import 'package:coqui_app/Models/coqui_session.dart';
import 'package:coqui_app/Providers/channel_provider.dart';
import 'package:coqui_app/Services/coqui_api_service.dart';
import 'package:coqui_app/Theme/coqui_colors.dart';
import 'package:coqui_app/Utils/server_restart_prompt.dart';
import 'package:coqui_app/Widgets/profile_picker_dialog.dart';

import 'channel_bound_session_picker.dart';
import 'channel_editor_sheet.dart';
import 'channel_status_badge.dart';

class ChannelDetailSheet extends StatefulWidget {
  final CoquiChannel channel;

  const ChannelDetailSheet({
    super.key,
    required this.channel,
  });

  @override
  State<ChannelDetailSheet> createState() => _ChannelDetailSheetState();
}

class _ChannelDetailSheetState extends State<ChannelDetailSheet> {
  Timer? _refreshTimer;
  bool _isRefreshing = false;
  bool _isLoadingBoundSession = false;
  CoquiSession? _boundSession;
  String? _boundSessionError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _refresh(force: true);
      _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
        unawaited(_refresh(force: true));
      });
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _refresh({bool force = false}) async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    final channel = await context
        .read<ChannelProvider>()
        .loadChannelDetail(widget.channel.id, force: force);
    await _loadBoundSession(
        channel?.boundSessionId ?? widget.channel.boundSessionId);
    if (mounted) {
      setState(() => _isRefreshing = false);
    }
  }

  Future<void> _loadBoundSession(String? sessionId) async {
    if (sessionId == null || sessionId.isEmpty) {
      if (mounted) {
        setState(() {
          _boundSession = null;
          _boundSessionError = null;
          _isLoadingBoundSession = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isLoadingBoundSession = true;
        _boundSessionError = null;
      });
    }

    try {
      final session =
          await context.read<CoquiApiService>().getSession(sessionId);
      if (!mounted) {
        return;
      }

      setState(() {
        _boundSession = session;
        _boundSessionError = session == null
            ? 'The saved bound session could not be loaded.'
            : null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _boundSession = null;
        _boundSessionError = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingBoundSession = false;
        });
      }
    }
  }

  Future<void> _testChannel() async {
    final provider = context.read<ChannelProvider>();
    final updated = await provider.testChannel(widget.channel.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          updated != null
              ? 'Channel reconcile completed. Review runtime health below.'
              : provider.error ?? 'Unable to test channel',
        ),
      ),
    );
  }

  Future<void> _toggleEnabled(CoquiChannel channel) async {
    final provider = context.read<ChannelProvider>();
    final updated =
        await provider.toggleChannelEnabled(channel.id, !channel.enabled);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          updated != null
              ? (updated.enabled ? 'Channel enabled.' : 'Channel disabled.')
              : provider.error ?? 'Unable to update channel',
        ),
      ),
    );
    if (updated != null) {
      await promptForPendingServerRestart(
        context,
        onRestarted: () => _refresh(force: true),
      );
    }
  }

  Future<void> _edit(CoquiChannel channel) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<ChannelProvider>(),
        child: ChannelEditorSheet(channel: channel),
      ),
    );
    if (mounted) {
      await _refresh(force: true);
    }
  }

  Future<void> _addLink(CoquiChannel channel) async {
    final remoteUserController = TextEditingController();
    final remoteScopeController = TextEditingController();
    String? selectedProfile;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            title: const Text('Add Linked Sender'),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: remoteUserController,
                    decoration: const InputDecoration(
                      labelText: 'Remote user key',
                      hintText: '+15557654321',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: remoteScopeController,
                    decoration: const InputDecoration(
                      labelText: 'Remote scope key (optional)',
                      hintText: 'Signal group ID',
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Profile'),
                    subtitle: Text(selectedProfile ?? 'Choose a profile'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      final selected = await showProfilePickerDialog(
                        context: dialogContext,
                        title: 'Linked Sender Profile',
                        fetchProfiles: () =>
                            context.read<CoquiApiService>().getProfiles(),
                        initialValue: selectedProfile,
                        allowClear: false,
                      );
                      if (selected != null && dialogContext.mounted) {
                        setDialogState(() => selectedProfile = selected);
                      }
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  if (remoteUserController.text.trim().isEmpty ||
                      (selectedProfile == null || selectedProfile!.isEmpty)) {
                    return;
                  }
                  Navigator.pop(dialogContext, true);
                },
                child: const Text('Add Link'),
              ),
            ],
          );
        },
      ),
    );

    if (confirmed != true || !mounted) return;

    final provider = context.read<ChannelProvider>();
    final link = await provider.createLink(
      channel.id,
      remoteUserKey: remoteUserController.text.trim(),
      profile: selectedProfile!,
      remoteScopeKey: remoteScopeController.text.trim().isEmpty
          ? null
          : remoteScopeController.text.trim(),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          link != null
              ? 'Linked sender added.'
              : provider.error ?? 'Unable to add linked sender',
        ),
      ),
    );
  }

  Future<void> _deleteLink(CoquiChannel channel, CoquiChannelLink link) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove linked sender?'),
        content: Text(
            'This removes ${link.remoteUserKey} from ${channel.displayName}.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final provider = context.read<ChannelProvider>();
    final success = await provider.deleteLink(channel.id, link.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Linked sender removed.'
              : provider.error ?? 'Unable to remove link',
        ),
      ),
    );
  }

  Future<void> _deleteChannel(CoquiChannel channel) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${channel.displayName}?'),
        content: const Text(
            'The channel configuration will be removed from the Coqui server.'),
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

    final provider = context.read<ChannelProvider>();
    final success = await provider.deleteChannel(channel.id);
    if (!mounted) return;
    if (success) {
      await promptForPendingServerRestart(
        context,
        onRestarted: () =>
            context.read<ChannelProvider>().refreshDashboard(silent: true),
      );
      if (!mounted) return;
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.error ?? 'Unable to delete channel')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ChannelProvider>(
      builder: (context, provider, _) {
        final channel =
            provider.channelById(widget.channel.id) ?? widget.channel;
        final conversations = provider.conversationsForChannel(channel.id);
        final links = provider.linksForChannel(channel.id);
        final events = provider.eventsForChannel(channel.id);
        final deliveries = provider.deliveriesForChannel(channel.id);

        return DraggableScrollableSheet(
          initialChildSize: 0.74,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 4),
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
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              channel.displayName,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                ChannelStatusBadge(channel: channel),
                                Text(
                                  '${channel.driverLabel} • ${channel.name}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: _isRefreshing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.refresh),
                        tooltip: 'Refresh',
                        onPressed: _isRefreshing ? null : _refresh,
                      ),
                      IconButton(
                        icon: provider.isTesting(channel.id)
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.network_check_outlined),
                        tooltip: 'Test Connection',
                        onPressed: provider.isTesting(channel.id)
                            ? null
                            : _testChannel,
                      ),
                      PopupMenuButton<String>(
                        onSelected: (value) async {
                          if (value == 'toggle') {
                            await _toggleEnabled(channel);
                          } else if (value == 'edit') {
                            await _edit(channel);
                          } else if (value == 'delete') {
                            await _deleteChannel(channel);
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'toggle',
                            child: Text(channel.enabled ? 'Disable' : 'Enable'),
                          ),
                          const PopupMenuItem(
                              value: 'edit', child: Text('Edit')),
                          const PopupMenuItem(
                              value: 'delete', child: Text('Delete')),
                        ],
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
                      _InfoGrid(
                        channel: channel,
                        boundSessionTitle: _boundSession?.displayTitle ??
                            channel.boundSessionId,
                      ),
                      if (channel.lastError?.isNotEmpty ?? false) ...[
                        const SizedBox(height: 16),
                        _ContentCard(text: channel.lastError!, isError: true),
                      ],
                      const SizedBox(height: 16),
                      _HintBlock(channel: channel),
                      const SizedBox(height: 16),
                      _SectionTitle(
                        title: 'Capabilities',
                        actionLabel: channel.capabilities.isEmpty ? null : null,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: channel.capabilities.entries
                            .where((entry) => entry.value == true)
                            .map(
                              (entry) => Chip(
                                  label: Text(entry.key.replaceAll('_', ' '))),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 16),
                      const _SectionTitle(title: 'Configuration'),
                      const SizedBox(height: 8),
                      _ContentCard(
                        text: _configurationSummary(channel),
                      ),
                      const SizedBox(height: 16),
                      SessionSummaryCard(
                        title: 'Bound Interactive Session',
                        emptyText:
                            'This channel is not currently pinned to a shared interactive session.',
                        session: _boundSession,
                        fallbackSessionId: channel.boundSessionId,
                        isLoading: _isLoadingBoundSession,
                        errorText: _boundSessionError,
                        onOpenSession: _boundSession == null
                            ? null
                            : () => openChannelBoundSession(
                                  context,
                                  _boundSession!,
                                ),
                      ),
                      const SizedBox(height: 16),
                      _SectionTitle(
                        title: 'Linked Senders',
                        actionLabel: 'Add',
                        onAction: () => _addLink(channel),
                      ),
                      const SizedBox(height: 8),
                      if (links.isEmpty)
                        _ContentCard(
                          text: channel.security['linkRequired'] == true
                              ? 'No linked senders yet. This channel requires links before inbound messages will execute under a profile.'
                              : 'No linked senders yet. Add one if you want profile-specific routing for known users.',
                        )
                      else
                        ...links.map(
                          (link) => _LinkTile(
                            link: link,
                            onDelete: () => _deleteLink(channel, link),
                          ),
                        ),
                      const SizedBox(height: 16),
                      _SectionTitle(
                        title: 'Conversations',
                        actionLabel: 'Refresh',
                        onAction: () => provider.refreshActivity(channel.id),
                      ),
                      const SizedBox(height: 8),
                      if (conversations.isEmpty)
                        const _ContentCard(
                          text:
                              'No channel conversations have been recorded yet.',
                        )
                      else
                        ...conversations.take(6).map((conversation) =>
                            _ConversationTile(conversation: conversation)),
                      const SizedBox(height: 16),
                      _SectionTitle(
                        title: 'Recent Events',
                        actionLabel: 'Refresh',
                        onAction: () => provider.refreshActivity(channel.id),
                      ),
                      const SizedBox(height: 8),
                      if (events.isEmpty)
                        const _ContentCard(
                          text: 'No inbound events recorded yet.',
                        )
                      else
                        ...events
                            .take(6)
                            .map((event) => _EventTile(event: event)),
                      const SizedBox(height: 16),
                      const _SectionTitle(title: 'Recent Deliveries'),
                      const SizedBox(height: 8),
                      if (deliveries.isEmpty)
                        const _ContentCard(
                          text: 'No outbound deliveries recorded yet.',
                        )
                      else
                        ...deliveries.take(6).map(
                            (delivery) => _DeliveryTile(delivery: delivery)),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _configurationSummary(CoquiChannel channel) {
    final settings = channel.settings.entries
        .map((entry) => '${entry.key}: ${entry.value}')
        .join('\n');
    final security = channel.security.entries
        .map((entry) => '${entry.key}: ${entry.value}')
        .join('\n');
    final scopes = channel.allowedScopes.isEmpty
        ? 'Allowed scopes: none'
        : 'Allowed scopes:\n${channel.allowedScopes.join('\n')}';
    return [
      if (channel.defaultProfile?.isNotEmpty ?? false)
        'Default profile: ${channel.defaultProfile}',
      if (channel.boundSessionId?.isNotEmpty ?? false)
        'Bound session: ${_boundSession?.displayTitle ?? channel.boundSessionId}',
      if (settings.isNotEmpty) 'Settings:\n$settings',
      if (security.isNotEmpty) 'Security:\n$security',
      scopes,
    ].join('\n\n');
  }
}

class _InfoGrid extends StatelessWidget {
  final CoquiChannel channel;
  final String? boundSessionTitle;

  const _InfoGrid({
    required this.channel,
    this.boundSessionTitle,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Worker', channel.workerStatus),
      ('Heartbeat', _formatDateTime(channel.lastHeartbeatAt)),
      ('Last receive', _formatDateTime(channel.lastReceiveAt)),
      ('Last send', _formatDateTime(channel.lastSendAt)),
      ('Inbound backlog', channel.inboundBacklog.toString()),
      ('Outbound backlog', channel.outboundBacklog.toString()),
      ('Failures', channel.consecutiveFailures.toString()),
      ('Profile', channel.defaultProfile ?? 'None'),
      ('Bound session', boundSessionTitle ?? 'None'),
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: items
          .map(
            (item) => SizedBox(
              width: 220,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.$1,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.$2,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _HintBlock extends StatelessWidget {
  final CoquiChannel channel;

  const _HintBlock({required this.channel});

  @override
  Widget build(BuildContext context) {
    final body = switch (channel.driver) {
      'signal' =>
        'Test Connection runs a reconcile and health refresh on the Coqui API server. For a real Signal check, verify signal-cli --version, java --version, and a valid attached account, then link a sender profile and send a real Signal message.',
      'telegram' ||
      'discord' =>
        'This driver is currently scaffolded in the backend. You can save configuration and monitor placeholder health, but end-to-end transport testing is not yet available.',
      _ =>
        'Use Test Connection to refresh runtime state and then inspect recent events and deliveries below.',
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(body, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _SectionTitle({
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        const Spacer(),
        if (actionLabel != null && onAction != null)
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ],
    );
  }
}

class _ContentCard extends StatelessWidget {
  final String text;
  final bool isError;

  const _ContentCard({
    required this.text,
    this.isError = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isError
            ? theme.colorScheme.errorContainer
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isError ? theme.colorScheme.error : theme.dividerColor,
        ),
      ),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          color: isError ? theme.colorScheme.onErrorContainer : null,
        ),
      ),
    );
  }
}

class _LinkTile extends StatelessWidget {
  final CoquiChannelLink link;
  final VoidCallback onDelete;

  const _LinkTile({
    required this.link,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        children: [
          const Icon(Icons.person_outline, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(link.remoteUserKey),
                Text(
                  '${link.profile}${link.remoteScopeKey?.isNotEmpty == true ? ' • ${link.remoteScopeKey}' : ''}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Remove link',
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final CoquiChannelConversation conversation;

  const _ConversationTile({required this.conversation});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final metadataSummary = conversation.metadata.isEmpty
        ? null
        : conversation.metadata.entries
            .take(2)
            .map((entry) => '${entry.key}: ${entry.value}')
            .join(' • ');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(conversation.remoteConversationKey),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (conversation.profile?.isNotEmpty ?? false)
              Text('Profile: ${conversation.profile}'),
            if (conversation.sessionId?.isNotEmpty ?? false)
              Text('Session: ${conversation.sessionId}'),
            if (conversation.remoteThreadKey?.isNotEmpty ?? false)
              Text('Thread: ${conversation.remoteThreadKey}'),
            if (conversation.lastMessageAt != null)
              Text('Last message: ${conversation.lastMessageAt!.toLocal()}'),
            if (metadataSummary != null)
              Text(
                metadataSummary,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EventTile extends StatelessWidget {
  final CoquiChannelEvent event;

  const _EventTile({required this.event});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            event.error?.isNotEmpty == true
                ? Icons.error_outline
                : Icons.call_received_outlined,
            size: 18,
            color: event.error?.isNotEmpty == true
                ? Theme.of(context).colorScheme.error
                : CoquiColors.chart3,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.eventType,
                  style: Theme.of(context)
                      .textTheme
                      .labelLarge
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  event.remoteUserKey ?? 'Unknown sender',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  '${event.status} • ${_formatDateTime(event.receivedAt)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                if (event.error?.isNotEmpty == true) ...[
                  const SizedBox(height: 4),
                  Text(
                    event.error!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DeliveryTile extends StatelessWidget {
  final CoquiChannelDelivery delivery;

  const _DeliveryTile({required this.delivery});

  @override
  Widget build(BuildContext context) {
    final failed = delivery.isFailed;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            failed ? Icons.error_outline : Icons.call_made_outlined,
            size: 18,
            color: failed
                ? Theme.of(context).colorScheme.error
                : CoquiColors.chart3,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  delivery.status,
                  style: Theme.of(context)
                      .textTheme
                      .labelLarge
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  'Attempts ${delivery.attemptCount} • ${_formatDateTime(delivery.sentAt ?? delivery.failedAt ?? delivery.queuedAt)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (delivery.lastError?.isNotEmpty == true) ...[
                  const SizedBox(height: 4),
                  Text(
                    delivery.lastError!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _formatDateTime(DateTime? dateTime) {
  if (dateTime == null) return 'Not yet';
  final local = dateTime.toLocal();
  return '${local.year}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')} '
      '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
}
