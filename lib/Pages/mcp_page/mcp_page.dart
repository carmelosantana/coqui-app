import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:coqui_app/Models/coqui_mcp_server.dart';
import 'package:coqui_app/Models/coqui_mcp_tool.dart';
import 'package:coqui_app/Providers/instance_provider.dart';
import 'package:coqui_app/Providers/mcp_provider.dart';
import 'package:coqui_app/Theme/coqui_colors.dart';
import 'package:coqui_app/Utils/server_restart_prompt.dart';

enum _McpStatusFilter { all, connected, disconnected, disabled, issues }

class McpPage extends StatefulWidget {
  const McpPage({super.key});

  @override
  State<McpPage> createState() => _McpPageState();
}

class _McpPageState extends State<McpPage> {
  _McpStatusFilter _statusFilter = _McpStatusFilter.all;
  McpProvider? _mcpProvider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = context.read<McpProvider>();
      _mcpProvider = provider;
      await provider.refreshDashboard();
      if (mounted) {
        provider.startPolling();
      }
    });
  }

  @override
  void dispose() {
    _mcpProvider?.stopPolling();
    super.dispose();
  }

  Future<void> _refresh() async {
    await context.read<McpProvider>().refreshDashboard();
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
        value: context.read<McpProvider>(),
        child: const _McpEditorSheet(),
      ),
    );
  }

  void _openDetail(CoquiMcpServer server) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<McpProvider>(),
        child: _McpDetailSheet(server: server),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasInstance = context.watch<InstanceProvider>().hasActiveInstance;

    return Scaffold(
      appBar: AppBar(
        title: const Text('MCP'),
        actions: [
          Consumer<McpProvider>(
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
        label: const Text('New Server'),
      ),
      body: SafeArea(
        child: hasInstance
            ? Consumer<McpProvider>(
                builder: (context, provider, _) {
                  final filteredServers = _applyFilters(provider.servers);

                  if (provider.isLoading && provider.servers.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (provider.error != null && provider.servers.isEmpty) {
                    return _McpErrorView(
                      error: provider.error!,
                      onRetry: _refresh,
                    );
                  }

                  if (provider.servers.isEmpty) {
                    return _McpEmptyView(onCreateTap: _openCreate);
                  }

                  return RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                      children: [
                        _McpStatusFilterRow(
                          selected: _statusFilter,
                          onSelected: (value) {
                            setState(() => _statusFilter = value);
                          },
                        ),
                        const SizedBox(height: 16),
                        _McpStatsGrid(servers: provider.servers),
                        const SizedBox(height: 16),
                        Text(
                          'Configured Servers',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${filteredServers.length} shown',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 12),
                        if (filteredServers.isEmpty)
                          _FilteredMcpEmptyView(
                            onClear: () => setState(
                                () => _statusFilter = _McpStatusFilter.all),
                          )
                        else
                          ...filteredServers.map(
                            (server) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _McpServerCard(
                                server: server,
                                onTap: () => _openDetail(server),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              )
            : const _McpNoInstanceView(),
      ),
    );
  }

  List<CoquiMcpServer> _applyFilters(List<CoquiMcpServer> servers) {
    return servers.where((server) {
      return switch (_statusFilter) {
        _McpStatusFilter.all => true,
        _McpStatusFilter.connected => server.connected && !server.disabled,
        _McpStatusFilter.disconnected => !server.connected && !server.disabled,
        _McpStatusFilter.disabled => server.disabled,
        _McpStatusFilter.issues => server.hasError,
      };
    }).toList()
      ..sort((left, right) {
        if (left.connected != right.connected) {
          return right.connected ? 1 : -1;
        }
        return left.name.compareTo(right.name);
      });
  }
}

class _McpStatusFilterRow extends StatelessWidget {
  final _McpStatusFilter selected;
  final ValueChanged<_McpStatusFilter> onSelected;

  const _McpStatusFilterRow({
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    const filters = [
      (label: 'All', value: _McpStatusFilter.all),
      (label: 'Connected', value: _McpStatusFilter.connected),
      (label: 'Disconnected', value: _McpStatusFilter.disconnected),
      (label: 'Disabled', value: _McpStatusFilter.disabled),
      (label: 'Issues', value: _McpStatusFilter.issues),
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

class _McpStatsGrid extends StatelessWidget {
  final List<CoquiMcpServer> servers;

  const _McpStatsGrid({required this.servers});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final connectedCount = servers.where((server) => server.connected).length;
    final disabledCount = servers.where((server) => server.disabled).length;
    final issueCount = servers.where((server) => server.hasError).length;
    final toolCount =
        servers.fold<int>(0, (sum, server) => sum + server.toolCount);

    final cards = [
      (
        title: 'Configured',
        value: servers.length.toString(),
        subtitle: 'Servers in workspace',
        color: theme.colorScheme.primary,
        icon: Icons.hub_outlined,
      ),
      (
        title: 'Connected',
        value: connectedCount.toString(),
        subtitle: 'Live MCP runtimes',
        color: CoquiColors.chart2,
        icon: Icons.link_outlined,
      ),
      (
        title: 'Issues',
        value: issueCount.toString(),
        subtitle: 'Servers with errors',
        color: theme.colorScheme.error,
        icon: Icons.error_outline,
      ),
      (
        title: 'Tools',
        value: toolCount.toString(),
        subtitle: 'Discovered capabilities',
        color: CoquiColors.warning,
        icon: Icons.extension_outlined,
      ),
      (
        title: 'Disabled',
        value: disabledCount.toString(),
        subtitle: 'Not available to turns',
        color: theme.colorScheme.onSurfaceVariant,
        icon: Icons.toggle_off_outlined,
      ),
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: cards
          .map(
            (card) => SizedBox(
              width: 220,
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
                          Text(card.title, style: theme.textTheme.labelLarge),
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

class _McpServerCard extends StatelessWidget {
  final CoquiMcpServer server;
  final VoidCallback onTap;

  const _McpServerCard({
    required this.server,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          server.name,
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          server.hasDescription
                              ? server.description!
                              : server.commandLabel,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Icon(Icons.chevron_right),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _McpStatusBadge(server: server),
                  _InfoPill(label: 'Mode ${server.loadingMode}'),
                  _InfoPill(label: '${server.toolCount} tools'),
                  if (server.serverVersion != null &&
                      server.serverVersion!.isNotEmpty)
                    _InfoPill(label: server.serverVersion!),
                ],
              ),
              if (server.hasError) ...[
                const SizedBox(height: 12),
                Text(
                  server.error!,
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

class _McpDetailSheet extends StatefulWidget {
  final CoquiMcpServer server;

  const _McpDetailSheet({required this.server});

  @override
  State<_McpDetailSheet> createState() => _McpDetailSheetState();
}

class _McpDetailSheetState extends State<_McpDetailSheet> {
  Timer? _refreshTimer;
  bool _isRefreshing = false;
  late String _serverName;

  @override
  void initState() {
    super.initState();
    _serverName = widget.server.name;
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
    final server = await context
        .read<McpProvider>()
        .loadServerDetail(_serverName, force: force);
    if (server != null && mounted) {
      setState(() => _serverName = server.name);
    }
    if (mounted) {
      setState(() => _isRefreshing = false);
    }
  }

  Future<void> _edit(CoquiMcpServer server) async {
    final updated = await showModalBottomSheet<CoquiMcpServer>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<McpProvider>(),
        child: _McpEditorSheet(server: server),
      ),
    );
    if (!mounted || updated == null) return;
    setState(() => _serverName = updated.name);
    await _refresh(force: true);
  }

  Future<void> _toggleEnabled(CoquiMcpServer server) async {
    final provider = context.read<McpProvider>();
    final updated =
        await provider.toggleServerEnabled(server.name, !server.enabled);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          updated != null
              ? (updated.enabled
                  ? 'MCP server enabled.'
                  : 'MCP server disabled.')
              : provider.error ?? 'Unable to update server',
        ),
      ),
    );
  }

  Future<void> _setLoadingMode(CoquiMcpServer server, String mode) async {
    final provider = context.read<McpProvider>();
    final updated = await provider.setLoadingMode(server.name, mode);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          updated != null
              ? 'Loading mode updated to ${updated.loadingMode}.'
              : provider.error ?? 'Unable to update loading mode',
        ),
      ),
    );
  }

  Future<void> _connect(CoquiMcpServer server) async {
    final provider = context.read<McpProvider>();
    final updated = await provider.connectServer(server.name);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          updated != null
              ? 'MCP server connected.'
              : provider.error ?? 'Unable to connect server',
        ),
      ),
    );
  }

  Future<void> _disconnect(CoquiMcpServer server) async {
    final provider = context.read<McpProvider>();
    final updated = await provider.disconnectServer(server.name);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          updated != null
              ? 'MCP server disconnected.'
              : provider.error ?? 'Unable to disconnect server',
        ),
      ),
    );
  }

  Future<void> _refreshRuntime(CoquiMcpServer server) async {
    final provider = context.read<McpProvider>();
    final updated = await provider.refreshServer(server.name);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          updated != null
              ? 'MCP server refreshed.'
              : provider.error ?? 'Unable to refresh server',
        ),
      ),
    );
  }

  Future<void> _test(CoquiMcpServer server) async {
    final provider = context.read<McpProvider>();
    final updated = await provider.testServer(server.name);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          updated != null
              ? 'Connectivity test succeeded.'
              : provider.error ?? 'Unable to test server',
        ),
      ),
    );
  }

  Future<void> _delete(CoquiMcpServer server) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${server.name}?'),
        content: const Text(
          'The MCP server configuration will be removed from the Coqui workspace.',
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

    final provider = context.read<McpProvider>();
    final success = await provider.deleteServer(server.name);
    if (!mounted) return;
    if (success) {
      Navigator.pop(context);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(provider.error ?? 'Unable to delete server')),
    );
  }

  Future<void> _setToolVisibility(
    CoquiMcpServer server,
    CoquiMcpTool tool,
    String visibility,
  ) async {
    final provider = context.read<McpProvider>();
    final updated = await provider.setToolVisibility(
      server.name,
      tool.namespacedName,
      visibility,
    );
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          updated != null
              ? 'Tool visibility set to ${updated.effectiveVisibility}.'
              : provider.error ?? 'Unable to update tool visibility',
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

  @override
  Widget build(BuildContext context) {
    return Consumer<McpProvider>(
      builder: (context, provider, _) {
        final server = provider.serverByName(_serverName) ?? widget.server;
        final tools = provider.toolsForServer(server.name);
        final isBusy = provider.isServerMutating(server.name) ||
            provider.isRuntimeBusy(server.name);

        return DraggableScrollableSheet(
          initialChildSize: 0.78,
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
                              server.name,
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
                                _McpStatusBadge(server: server),
                                _InfoPill(label: 'Mode ${server.loadingMode}'),
                                _InfoPill(label: '${server.toolCount} tools'),
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
                        onPressed:
                            _isRefreshing ? null : () => _refresh(force: true),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: isBusy ? null : () => _edit(server),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: isBusy ? null : () => _delete(server),
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
                      _SectionHeader(title: 'Runtime Actions'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.tonalIcon(
                            onPressed: server.connected || isBusy
                                ? null
                                : () => _connect(server),
                            icon: const Icon(Icons.link_outlined),
                            label: const Text('Connect'),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: !server.connected || isBusy
                                ? null
                                : () => _disconnect(server),
                            icon: const Icon(Icons.link_off_outlined),
                            label: const Text('Disconnect'),
                          ),
                          FilledButton.tonalIcon(
                            onPressed:
                                isBusy ? null : () => _refreshRuntime(server),
                            icon: const Icon(Icons.sync_outlined),
                            label: const Text('Refresh'),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: isBusy ? null : () => _test(server),
                            icon: const Icon(Icons.science_outlined),
                            label: const Text('Test'),
                          ),
                          FilledButton.tonalIcon(
                            onPressed:
                                isBusy ? null : () => _toggleEnabled(server),
                            icon: Icon(
                              server.enabled
                                  ? Icons.toggle_off_outlined
                                  : Icons.toggle_on_outlined,
                            ),
                            label: Text(server.enabled ? 'Disable' : 'Enable'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _SectionHeader(title: 'Loading Mode'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('Auto'),
                            selected: server.loadingMode == 'auto',
                            onSelected: isBusy
                                ? null
                                : (_) => _setLoadingMode(server, 'auto'),
                          ),
                          ChoiceChip(
                            label: const Text('Eager'),
                            selected: server.loadingMode == 'eager',
                            onSelected: isBusy
                                ? null
                                : (_) => _setLoadingMode(server, 'eager'),
                          ),
                          ChoiceChip(
                            label: const Text('Deferred'),
                            selected: server.loadingMode == 'deferred',
                            onSelected: isBusy
                                ? null
                                : (_) => _setLoadingMode(server, 'deferred'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _SectionHeader(title: 'Configuration'),
                      const SizedBox(height: 8),
                      _LabeledValueCard(
                        title: 'Command',
                        value: server.commandLabel,
                      ),
                      if (server.hasDescription) ...[
                        const SizedBox(height: 12),
                        _LabeledValueCard(
                          title: 'Description',
                          value: server.description!,
                        ),
                      ],
                      if (server.hasInstructions) ...[
                        const SizedBox(height: 12),
                        _LabeledValueCard(
                          title: 'Instructions',
                          value: server.instructions!,
                        ),
                      ],
                      if (server.hasError) ...[
                        const SizedBox(height: 12),
                        _LabeledValueCard(
                          title: 'Last Error',
                          value: server.error!,
                          accentColor: Theme.of(context).colorScheme.error,
                        ),
                      ],
                      const SizedBox(height: 20),
                      _SectionHeader(title: 'Audit'),
                      const SizedBox(height: 8),
                      _AuditSummary(server: server),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          _SectionHeader(title: 'Tools'),
                          const Spacer(),
                          Text(
                            '${tools.length} loaded',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (provider.isDetailLoading(server.name) &&
                          tools.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (tools.isEmpty)
                        const _ToolsEmptyView()
                      else
                        ...tools.map(
                          (tool) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _McpToolCard(
                              tool: tool,
                              isBusy:
                                  provider.isToolMutating(tool.namespacedName),
                              onVisibilitySelected: (visibility) =>
                                  _setToolVisibility(server, tool, visibility),
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
      },
    );
  }
}

class _McpEditorSheet extends StatefulWidget {
  final CoquiMcpServer? server;

  const _McpEditorSheet({this.server});

  @override
  State<_McpEditorSheet> createState() => _McpEditorSheetState();
}

class _McpEditorSheetState extends State<_McpEditorSheet> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _commandController = TextEditingController();
  final _argsController = TextEditingController();

  bool get _isEditing => widget.server != null;

  @override
  void initState() {
    super.initState();
    final server = widget.server;
    if (server != null) {
      _nameController.text = server.name;
      _descriptionController.text = server.description ?? '';
      _commandController.text = server.command ?? '';
      _argsController.text = server.args.join('\n');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _commandController.dispose();
    _argsController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final provider = context.read<McpProvider>();
    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim();
    final command = _commandController.text.trim();
    final args = _argsController.text
        .split('\n')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);

    if (name.isEmpty) {
      _showSnack('Please enter a server name');
      return;
    }

    if (command.isEmpty) {
      _showSnack('Please enter the command to launch the MCP server');
      return;
    }

    final result = _isEditing
        ? await provider.updateServer(
            widget.server!.name,
            name: name,
            command: command,
            args: args,
            description: description.isEmpty ? null : description,
            clearDescription: description.isEmpty,
          )
        : await provider.createServer(
            name: name,
            command: command,
            args: args,
            description: description.isEmpty ? null : description,
          );

    if (!mounted) return;
    if (result != null) {
      Navigator.pop(context, result);
      return;
    }

    _showSnack(provider.error ?? 'Unable to save MCP server');
    provider.clearError();
  }

  void _showSnack(String message) {
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
        initialChildSize: 0.72,
        minChildSize: 0.45,
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
                    Text(
                      _isEditing ? 'Edit MCP Server' : 'New MCP Server',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    Consumer<McpProvider>(
                      builder: (context, provider, _) {
                        final busy = _isEditing
                            ? provider.isServerMutating(widget.server!.name)
                            : provider.isLoading;
                        return FilledButton(
                          onPressed: busy ? null : _save,
                          child: busy
                              ? SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: theme.colorScheme.onPrimary,
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
                    const _SectionHeader(title: 'Transport'),
                    const SizedBox(height: 8),
                    const _LabeledValueCard(
                      title: 'Mode',
                      value:
                          'Stdio transport is available in the current backend. Remote URL transport is planned but not yet exposed in the app.',
                    ),
                    const SizedBox(height: 20),
                    const _SectionHeader(title: 'Basics'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Server name',
                        hintText: 'github',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _descriptionController,
                      minLines: 2,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        hintText: 'GitHub MCP bridge for repository automation',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _commandController,
                      decoration: const InputDecoration(
                        labelText: 'Command',
                        hintText: 'npx',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _argsController,
                      minLines: 3,
                      maxLines: 6,
                      decoration: const InputDecoration(
                        labelText: 'Arguments',
                        hintText:
                            '@modelcontextprotocol/server-github\n--stdio',
                        helperText: 'Enter one argument per line.',
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Enable, disable, loading mode, connection lifecycle, and per-tool controls are available after save in the detail sheet.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
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
  }
}

class _McpToolCard extends StatelessWidget {
  final CoquiMcpTool tool;
  final bool isBusy;
  final ValueChanged<String> onVisibilitySelected;

  const _McpToolCard({
    required this.tool,
    required this.isBusy,
    required this.onVisibilitySelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visibility = tool.effectiveVisibility;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tool.name,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tool.namespacedName,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (tool.hasDescription) ...[
                    const SizedBox(height: 8),
                    Text(
                      tool.description,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _VisibilityPill(visibility: visibility),
                      if (tool.protection != null)
                        _InfoPill(label: tool.protection!.replaceAll('_', ' ')),
                      if (tool.requiredParameters.isNotEmpty)
                        _InfoPill(
                          label:
                              '${tool.requiredParameters.length} required args',
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            PopupMenuButton<String>(
              enabled: !isBusy,
              tooltip: 'Change visibility',
              onSelected: onVisibilitySelected,
              itemBuilder: (context) => [
                PopupMenuItem<String>(
                  value: 'enabled',
                  child: const Text('Enable'),
                ),
                PopupMenuItem<String>(
                  value: 'stub',
                  enabled: !tool.isAlwaysEnabled,
                  child: const Text('Stub'),
                ),
                PopupMenuItem<String>(
                  value: 'disabled',
                  enabled: !tool.isAlwaysEnabled && !tool.cannotDisable,
                  child: const Text('Disable'),
                ),
              ],
              child: isBusy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _visibilityLabel(visibility),
                          style: theme.textTheme.labelLarge,
                        ),
                        const Icon(Icons.arrow_drop_down),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _McpStatusBadge extends StatelessWidget {
  final CoquiMcpServer server;

  const _McpStatusBadge({required this.server});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = switch (server.statusLabel) {
      'Connected' => CoquiColors.chart2,
      'Disabled' => theme.colorScheme.onSurfaceVariant,
      _ => CoquiColors.warning,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            server.statusLabel,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _VisibilityPill extends StatelessWidget {
  final String visibility;

  const _VisibilityPill({required this.visibility});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = switch (visibility) {
      'stub' => CoquiColors.warning,
      'disabled' => theme.colorScheme.error,
      _ => CoquiColors.chart2,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _visibilityLabel(visibility),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final String label;

  const _InfoPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium,
      ),
    );
  }
}

class _LabeledValueCard extends StatelessWidget {
  final String title;
  final String value;
  final Color? accentColor;

  const _LabeledValueCard({
    required this.title,
    required this.value,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: accentColor,
                  ),
            ),
            const SizedBox(height: 8),
            SelectableText(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _AuditSummary extends StatelessWidget {
  final CoquiMcpServer server;

  const _AuditSummary({required this.server});

  @override
  Widget build(BuildContext context) {
    final rows = <({String label, String value})>[
      (
        label: 'Last connected',
        value: _dateLabel(server.audit.lastConnectedAt),
      ),
      (
        label: 'Last disconnected',
        value: _dateLabel(server.audit.lastDisconnectedAt),
      ),
      (
        label: 'Last tested',
        value: _dateLabel(server.audit.lastTestedAt),
      ),
      (
        label: 'Last discovery',
        value: server.audit.lastToolDiscoveryCount?.toString() ?? 'Unknown',
      ),
      (
        label: 'Connect duration',
        value: server.audit.lastConnectionDurationMs != null
            ? '${server.audit.lastConnectionDurationMs} ms'
            : 'Unknown',
      ),
      (
        label: 'Test duration',
        value: server.audit.lastTestDurationMs != null
            ? '${server.audit.lastTestDurationMs} ms'
            : 'Unknown',
      ),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ...rows.map(
              (row) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        row.label,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        row.value,
                        textAlign: TextAlign.right,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (server.audit.lastConnectionError != null &&
                server.audit.lastConnectionError!.isNotEmpty)
              _LabeledValueCard(
                title: 'Last connection error',
                value: server.audit.lastConnectionError!,
                accentColor: Theme.of(context).colorScheme.error,
              ),
            if (server.audit.lastTestError != null &&
                server.audit.lastTestError!.isNotEmpty) ...[
              const SizedBox(height: 12),
              _LabeledValueCard(
                title: 'Last test error',
                value: server.audit.lastTestError!,
                accentColor: Theme.of(context).colorScheme.error,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context)
          .textTheme
          .titleSmall
          ?.copyWith(fontWeight: FontWeight.w700),
    );
  }
}

class _ToolsEmptyView extends StatelessWidget {
  const _ToolsEmptyView();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          'No discovered tools yet. Connect or refresh the server to inspect its MCP capabilities.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}

class _McpErrorView extends StatelessWidget {
  final String error;
  final Future<void> Function() onRetry;

  const _McpErrorView({
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
              size: 40,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 12),
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

class _McpEmptyView extends StatelessWidget {
  final Future<void> Function() onCreateTap;

  const _McpEmptyView({required this.onCreateTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.hub_outlined, size: 48),
            const SizedBox(height: 12),
            Text(
              'No MCP servers configured',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Add a stdio-backed MCP server to inspect tools, manage visibility, and control runtime state from the app.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onCreateTap,
              icon: const Icon(Icons.add),
              label: const Text('Add MCP Server'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilteredMcpEmptyView extends StatelessWidget {
  final VoidCallback onClear;

  const _FilteredMcpEmptyView({required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              'No MCP servers match the current filter.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: onClear,
              child: const Text('Clear filter'),
            ),
          ],
        ),
      ),
    );
  }
}

class _McpNoInstanceView extends StatelessWidget {
  const _McpNoInstanceView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 48),
            const SizedBox(height: 12),
            Text(
              'Connect to a Coqui server first',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'The MCP management view needs an active API instance before it can load configured servers or tool visibility.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

String _visibilityLabel(String visibility) {
  return switch (visibility) {
    'stub' => 'Stub',
    'disabled' => 'Disabled',
    _ => 'Enabled',
  };
}

String _dateLabel(DateTime? value) {
  if (value == null) return 'Never';

  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.year}-$month-$day $hour:$minute';
}
