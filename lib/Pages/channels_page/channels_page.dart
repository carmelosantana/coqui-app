import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:coqui_app/Models/coqui_channel.dart';
import 'package:coqui_app/Models/coqui_channel_driver.dart';
import 'package:coqui_app/Providers/channel_provider.dart';
import 'package:coqui_app/Providers/instance_provider.dart';
import 'package:coqui_app/Theme/coqui_colors.dart';

import 'subwidgets/subwidgets.dart';

enum _ChannelStatusFilter { all, healthy, issues, disabled }

class ChannelsPage extends StatefulWidget {
  const ChannelsPage({super.key});

  @override
  State<ChannelsPage> createState() => _ChannelsPageState();
}

class _ChannelsPageState extends State<ChannelsPage> {
  _ChannelStatusFilter _statusFilter = _ChannelStatusFilter.all;
  String? _driverFilter;
  ChannelProvider? _channelProvider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = context.read<ChannelProvider>();
      _channelProvider = provider;
      await provider.refreshDashboard();
      if (mounted) {
        provider.startPolling();
      }
    });
  }

  @override
  void dispose() {
    _channelProvider?.stopPolling();
    super.dispose();
  }

  Future<void> _refresh() async {
    await context.read<ChannelProvider>().refreshDashboard();
  }

  Future<void> _openCreate() async {
    final hasInstance = context.read<InstanceProvider>().hasActiveInstance;
    if (!hasInstance) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connect to a server first')),
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<ChannelProvider>(),
        child: const ChannelEditorSheet(),
      ),
    );
  }

  void _openDetail(CoquiChannel channel) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<ChannelProvider>(),
        child: ChannelDetailSheet(channel: channel),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasInstance = context.watch<InstanceProvider>().hasActiveInstance;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Channels'),
        actions: [
          Consumer<ChannelProvider>(
            builder: (context, provider, _) {
              return IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh',
                onPressed: provider.isLoading ? null : _refresh,
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: hasInstance ? _openCreate : null,
        icon: const Icon(Icons.add),
        label: const Text('New Channel'),
      ),
      body: SafeArea(
        child: hasInstance
            ? Consumer<ChannelProvider>(
                builder: (context, provider, _) {
                  final filteredChannels = _applyFilters(provider.channels);

                  if (provider.isLoading && provider.channels.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (provider.error != null && provider.channels.isEmpty) {
                    return _ChannelsErrorView(
                      error: provider.error!,
                      onRetry: _refresh,
                    );
                  }

                  if (provider.channels.isEmpty) {
                    return _ChannelsEmptyView(onCreateTap: _openCreate);
                  }

                  return RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                      children: [
                        _StatusFilterRow(
                          selected: _statusFilter,
                          onSelected: (value) {
                            setState(() => _statusFilter = value);
                          },
                        ),
                        const SizedBox(height: 8),
                        _DriverFilterRow(
                          drivers: provider.drivers,
                          selectedDriver: _driverFilter,
                          onSelected: (driver) async {
                            setState(() => _driverFilter = driver);
                            await provider.fetchChannels(driver: driver);
                          },
                        ),
                        const SizedBox(height: 16),
                        _ChannelStatsGrid(provider: provider),
                        const SizedBox(height: 16),
                        _TestingHintCard(channels: filteredChannels),
                        const SizedBox(height: 16),
                        _RecentActivityCard(channels: filteredChannels),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Text(
                              'Configured Channels',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const Spacer(),
                            Text(
                              '${filteredChannels.length} shown',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (filteredChannels.isEmpty)
                          _FilteredEmptyView(
                            onClear: () => setState(() {
                              _statusFilter = _ChannelStatusFilter.all;
                              _driverFilter = null;
                            }),
                          )
                        else
                          ...filteredChannels.map(
                            (channel) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _ChannelCard(
                                channel: channel,
                                onTap: () => _openDetail(channel),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              )
            : const _NoInstanceView(),
      ),
    );
  }

  List<CoquiChannel> _applyFilters(List<CoquiChannel> channels) {
    return channels.where((channel) {
      return switch (_statusFilter) {
        _ChannelStatusFilter.all => true,
        _ChannelStatusFilter.healthy => channel.isHealthy,
        _ChannelStatusFilter.issues =>
          channel.hasIssues ||
              channel.consecutiveFailures > 0 ||
              (channel.lastError?.isNotEmpty ?? false),
        _ChannelStatusFilter.disabled => channel.isDisabled,
      };
    }).toList()
      ..sort((left, right) {
        final leftTime = _latestActivity(left);
        final rightTime = _latestActivity(right);
        if (leftTime == null && rightTime == null) return 0;
        if (leftTime == null) return 1;
        if (rightTime == null) return -1;
        return rightTime.compareTo(leftTime);
      });
  }

  DateTime? _latestActivity(CoquiChannel channel) {
    final values = [
      channel.lastReceiveAt,
      channel.lastSendAt,
      channel.lastHeartbeatAt,
    ].whereType<DateTime>().toList();
    if (values.isEmpty) return null;
    values.sort((left, right) => right.compareTo(left));
    return values.first;
  }
}

class _StatusFilterRow extends StatelessWidget {
  final _ChannelStatusFilter selected;
  final ValueChanged<_ChannelStatusFilter> onSelected;

  const _StatusFilterRow({
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    const filters = [
      (label: 'All', value: _ChannelStatusFilter.all),
      (label: 'Healthy', value: _ChannelStatusFilter.healthy),
      (label: 'Needs Attention', value: _ChannelStatusFilter.issues),
      (label: 'Disabled', value: _ChannelStatusFilter.disabled),
    ];

    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: filters
            .map(
              (filter) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(filter.label),
                  selected: selected == filter.value,
                  onSelected: (_) => onSelected(filter.value),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _DriverFilterRow extends StatelessWidget {
  final List<CoquiChannelDriver> drivers;
  final String? selectedDriver;
  final ValueChanged<String?> onSelected;

  const _DriverFilterRow({
    required this.drivers,
    required this.selectedDriver,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (drivers.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: const Text('All Drivers'),
              selected: selectedDriver == null,
              onSelected: (_) => onSelected(null),
            ),
          ),
          ...drivers.map(
            (driver) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(driver.displayName),
                selected: selectedDriver == driver.name,
                onSelected: (_) => onSelected(driver.name),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChannelStatsGrid extends StatelessWidget {
  final ChannelProvider provider;

  const _ChannelStatsGrid({required this.provider});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cards = [
      (
        title: 'Active',
        value: provider.stats.ready.toString(),
        subtitle: 'Healthy runtimes',
        color: CoquiColors.chart3,
        icon: Icons.check_circle_outline,
      ),
      (
        title: 'Attention',
        value: provider.stats.errors.toString(),
        subtitle: 'Channels with issues',
        color: theme.colorScheme.error,
        icon: Icons.error_outline,
      ),
      (
        title: 'Enabled',
        value: provider.stats.enabled.toString(),
        subtitle: 'Configured to run',
        color: CoquiColors.warning,
        icon: Icons.toggle_on_outlined,
      ),
      (
        title: 'Drivers',
        value: provider.managerStats.registeredDrivers.toString(),
        subtitle: 'Available channel types',
        color: theme.colorScheme.primary,
        icon: Icons.hub_outlined,
      ),
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: cards
          .map(
            (card) => SizedBox(
              width: 260,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(card.icon, size: 18, color: card.color),
                          const SizedBox(width: 8),
                          Text(
                            card.title,
                            style: theme.textTheme.labelLarge,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        card.value,
                        style: theme.textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        card.subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _TestingHintCard extends StatelessWidget {
  final List<CoquiChannel> channels;

  const _TestingHintCard({required this.channels});

  @override
  Widget build(BuildContext context) {
    final hasSignal = channels.any((channel) => channel.driver == 'signal');
    final hasScaffolded =
        channels.any((channel) => channel.driver == 'telegram' || channel.driver == 'discord');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.tips_and_updates_outlined, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Testing & Setup',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              hasSignal
                  ? 'Use Test Connection to force a channel reconcile and refresh health. For a real Signal end-to-end check, make sure signal-cli and Java 25+ are installed on the same machine as the Coqui API server, then send a real Signal message from a linked sender.'
                  : 'Channel health updates here reflect the Coqui API runtime. Create a Signal channel for the fully guided production path.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (hasScaffolded) ...[
              const SizedBox(height: 10),
              Text(
                'Telegram and Discord are currently scaffolded runtimes. The app lets you configure them, but the backend reports them as placeholder channels until their transport runtimes ship.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RecentActivityCard extends StatelessWidget {
  final List<CoquiChannel> channels;

  const _RecentActivityCard({required this.channels});

  @override
  Widget build(BuildContext context) {
    final sorted = [...channels]
      ..sort((left, right) {
        final leftTime = _latest(left);
        final rightTime = _latest(right);
        if (leftTime == null && rightTime == null) return 0;
        if (leftTime == null) return 1;
        if (rightTime == null) return -1;
        return rightTime.compareTo(leftTime);
      });

    final items = sorted.where((channel) => _latest(channel) != null).take(3).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent Activity',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            if (items.isEmpty)
              Text(
                'No channel activity has been recorded yet. Once messages start flowing, recent receive and send timestamps will appear here.',
                style: Theme.of(context).textTheme.bodySmall,
              )
            else
              ...items.map(
                (channel) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Icon(_driverIcon(channel.driver), size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          channel.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        _formatRelative(_latest(channel)!),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  DateTime? _latest(CoquiChannel channel) {
    final values = [
      channel.lastReceiveAt,
      channel.lastSendAt,
      channel.lastHeartbeatAt,
    ].whereType<DateTime>().toList();
    if (values.isEmpty) return null;
    values.sort((left, right) => right.compareTo(left));
    return values.first;
  }
}

class _ChannelCard extends StatelessWidget {
  final CoquiChannel channel;
  final VoidCallback onTap;

  const _ChannelCard({
    required this.channel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(CoquiColors.radiusLg),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    child: Icon(
                      _driverIcon(channel.driver),
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          channel.displayName,
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${channel.driverLabel} • ${channel.name}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ChannelStatusBadge(channel: channel),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                channel.summary.isNotEmpty
                    ? channel.summary
                    : 'No runtime summary yet.',
                style: theme.textTheme.bodySmall,
              ),
              if (channel.lastError?.isNotEmpty ?? false) ...[
                const SizedBox(height: 10),
                Text(
                  channel.lastError!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _MetaPill(
                    icon: Icons.download_outlined,
                    label: 'Inbound ${channel.inboundBacklog}',
                  ),
                  _MetaPill(
                    icon: Icons.upload_outlined,
                    label: 'Outbound ${channel.outboundBacklog}',
                  ),
                  _MetaPill(
                    icon: Icons.favorite_border,
                    label: channel.lastHeartbeatAt != null
                        ? 'Heartbeat ${_formatRelative(channel.lastHeartbeatAt!)}'
                        : 'No heartbeat',
                  ),
                  if (channel.lastReceiveAt != null)
                    _MetaPill(
                      icon: Icons.call_received_outlined,
                      label: 'Receive ${_formatRelative(channel.lastReceiveAt!)}',
                    ),
                  if (channel.lastSendAt != null)
                    _MetaPill(
                      icon: Icons.call_made_outlined,
                      label: 'Send ${_formatRelative(channel.lastSendAt!)}',
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

class _MetaPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(CoquiColors.radiusSm),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(label, style: theme.textTheme.labelSmall),
        ],
      ),
    );
  }
}

class _NoInstanceView extends StatelessWidget {
  const _NoInstanceView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.satellite_alt_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'Connect to a Coqui server first',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Channels are managed on the active Coqui API server. Once you connect an instance, you can create channels, test them, and watch their health from here.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _ChannelsErrorView extends StatelessWidget {
  final String error;
  final Future<void> Function() onRetry;

  const _ChannelsErrorView({
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              error,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChannelsEmptyView extends StatelessWidget {
  final Future<void> Function() onCreateTap;

  const _ChannelsEmptyView({required this.onCreateTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.satellite_alt_outlined, size: 48),
            const SizedBox(height: 16),
            Text(
              'No channels configured yet',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Create a Signal channel for the full end-to-end path, or add another driver in advanced mode and monitor it from this dashboard.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onCreateTap,
              icon: const Icon(Icons.add),
              label: const Text('Create Channel'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilteredEmptyView extends StatelessWidget {
  final VoidCallback onClear;

  const _FilteredEmptyView({required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.filter_alt_off_outlined),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('No channels match the current filters.'),
            ),
            TextButton(
              onPressed: onClear,
              child: const Text('Clear'),
            ),
          ],
        ),
      ),
    );
  }
}

IconData _driverIcon(String driver) {
  return switch (driver) {
    'signal' => Icons.sms_outlined,
    'telegram' => Icons.send_outlined,
    'discord' => Icons.forum_outlined,
    _ => Icons.satellite_alt_outlined,
  };
}

String _formatRelative(DateTime dateTime) {
  final delta = DateTime.now().difference(dateTime.toLocal());
  if (delta.inSeconds < 60) return '${delta.inSeconds}s ago';
  if (delta.inMinutes < 60) return '${delta.inMinutes}m ago';
  if (delta.inHours < 24) return '${delta.inHours}h ago';
  return '${delta.inDays}d ago';
}