import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:coqui_app/Models/coqui_loop.dart';
import 'package:coqui_app/Models/coqui_schedule.dart';
import 'package:coqui_app/Models/coqui_task.dart';
import 'package:coqui_app/Models/coqui_webhook.dart';
import 'package:coqui_app/Providers/instance_provider.dart';
import 'package:coqui_app/Providers/loop_provider.dart';
import 'package:coqui_app/Providers/schedule_provider.dart';
import 'package:coqui_app/Providers/task_provider.dart';
import 'package:coqui_app/Providers/webhook_provider.dart';
import 'package:coqui_app/Theme/coqui_colors.dart';

import 'subwidgets/subwidgets.dart';

enum _AutomationTab { tasks, webhooks, schedules, loops }

class TasksPage extends StatefulWidget {
  const TasksPage({super.key});

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  String? _taskStatusFilter;
  bool? _webhookEnabledFilter;
  bool? _scheduleEnabledFilter;
  String? _loopStatusFilter;

  static const _taskStatusFilters = [
    (label: 'All', value: null),
    (label: 'Active', value: 'running'),
    (label: 'Pending', value: 'pending'),
    (label: 'Completed', value: 'completed'),
    (label: 'Failed', value: 'failed'),
    (label: 'Cancelled', value: 'cancelled'),
  ];

  static const _booleanFilters = [
    (label: 'All', value: null),
    (label: 'Enabled', value: true),
    (label: 'Disabled', value: false),
  ];

  static const _loopFilters = [
    (label: 'All', value: null),
    (label: 'Running', value: 'running'),
    (label: 'Paused', value: 'paused'),
    (label: 'Completed', value: 'completed'),
    (label: 'Failed', value: 'failed'),
    (label: 'Cancelled', value: 'cancelled'),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this)
      ..addListener(() {
        if (!_tabController.indexIsChanging) {
          setState(() {});
        }
      });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TaskProvider>().fetchTasks();
      context.read<WebhookProvider>().fetchWebhooks();
      context.read<ScheduleProvider>().fetchSchedules();
      context.read<LoopProvider>().fetchLoops();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  _AutomationTab get _activeTab => _AutomationTab.values[_tabController.index];

  Future<void> _openCreate() async {
    switch (_activeTab) {
      case _AutomationTab.tasks:
        await _openCreateTask();
      case _AutomationTab.webhooks:
        await _openCreateWebhook();
      case _AutomationTab.schedules:
        await _openCreateSchedule();
      case _AutomationTab.loops:
        await _openCreateLoop();
    }
  }

  Future<void> _refreshCurrentTab() async {
    switch (_activeTab) {
      case _AutomationTab.tasks:
        await context.read<TaskProvider>().fetchTasks(
              statusFilter: _taskStatusFilter,
            );
      case _AutomationTab.webhooks:
        await context.read<WebhookProvider>().fetchWebhooks(
              enabled: _webhookEnabledFilter,
            );
      case _AutomationTab.schedules:
        await context.read<ScheduleProvider>().fetchSchedules(
              enabled: _scheduleEnabledFilter,
            );
      case _AutomationTab.loops:
        await context.read<LoopProvider>().fetchLoops(
              status: _loopStatusFilter,
            );
    }
  }

  Future<void> _openCreateTask() async {
    if (!_ensureInstance()) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<TaskProvider>(),
        child: const CreateTaskSheet(),
      ),
    );
  }

  Future<void> _openCreateWebhook() async {
    if (!_ensureInstance()) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<WebhookProvider>(),
        child: const WebhookEditorSheet(),
      ),
    );
  }

  Future<void> _openCreateSchedule() async {
    if (!_ensureInstance()) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<ScheduleProvider>(),
        child: const ScheduleEditorSheet(),
      ),
    );
  }

  Future<void> _openCreateLoop() async {
    if (!_ensureInstance()) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<LoopProvider>(),
        child: const LoopEditorSheet(),
      ),
    );
  }

  void _openTaskDetail(CoquiTask task) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<TaskProvider>(),
        child: TaskDetailSheet(task: task),
      ),
    );
  }

  void _openWebhookDetail(CoquiWebhook webhook) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<WebhookProvider>(),
        child: WebhookDetailSheet(webhook: webhook),
      ),
    );
  }

  void _openScheduleDetail(CoquiSchedule schedule) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<ScheduleProvider>(),
        child: ScheduleDetailSheet(schedule: schedule),
      ),
    );
  }

  void _openLoopDetail(CoquiLoop loop) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<LoopProvider>(),
        child: LoopDetailSheet(loop: loop),
      ),
    );
  }

  bool _ensureInstance() {
    final hasInstance = context.read<InstanceProvider>().hasActiveInstance;
    if (!hasInstance) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connect to a server first')),
      );
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Automation'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Tasks', icon: Icon(Icons.task_outlined)),
            Tab(text: 'Webhooks', icon: Icon(Icons.webhook_outlined)),
            Tab(text: 'Schedules', icon: Icon(Icons.schedule_outlined)),
            Tab(text: 'Loops', icon: Icon(Icons.account_tree_outlined)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _refreshCurrentTab,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        icon: Icon(_fabIcon),
        label: Text(_fabLabel),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildTasksTab(),
            _buildWebhooksTab(),
            _buildSchedulesTab(),
            _buildLoopsTab(),
          ],
        ),
      ),
    );
  }

  String get _fabLabel => switch (_activeTab) {
        _AutomationTab.tasks => 'New Task',
        _AutomationTab.webhooks => 'New Webhook',
        _AutomationTab.schedules => 'New Schedule',
        _AutomationTab.loops => 'Start Loop',
      };

  IconData get _fabIcon => switch (_activeTab) {
        _AutomationTab.tasks => Icons.add,
        _AutomationTab.webhooks => Icons.webhook_outlined,
        _AutomationTab.schedules => Icons.schedule_outlined,
        _AutomationTab.loops => Icons.account_tree_outlined,
      };

  Widget _buildTasksTab() {
    return Column(
      children: [
        _FilterChips(
          selected: _taskStatusFilter,
          filters: _taskStatusFilters,
          onSelected: (value) {
            final statusFilter = value as String?;
            setState(() => _taskStatusFilter = statusFilter);
            context.read<TaskProvider>().fetchTasks(statusFilter: statusFilter);
          },
        ),
        Expanded(
          child: Consumer<TaskProvider>(
            builder: (context, provider, _) {
              if (provider.isLoading && provider.tasks.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }

              if (provider.error != null && provider.tasks.isEmpty) {
                return _ErrorView(
                  title: 'Could not load tasks',
                  error: provider.error!,
                  onRetry: () =>
                      provider.fetchTasks(statusFilter: _taskStatusFilter),
                );
              }

              if (provider.tasks.isEmpty) {
                return _EmptyTaskView(
                  statusFilter: _taskStatusFilter,
                  onCreateTap: _openCreateTask,
                );
              }

              return RefreshIndicator(
                onRefresh: () =>
                    provider.fetchTasks(statusFilter: _taskStatusFilter),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(0, 8, 0, 100),
                  itemCount: provider.tasks.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, indent: 72),
                  itemBuilder: (context, index) {
                    final task = provider.tasks[index];
                    return _TaskListTile(
                      task: task,
                      onTap: () => _openTaskDetail(task),
                      onCancel: task.isActive
                          ? () => provider.cancelTask(task.id)
                          : null,
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildWebhooksTab() {
    return Column(
      children: [
        _FilterChips(
          selected: _webhookEnabledFilter,
          filters: _booleanFilters,
          onSelected: (value) {
            final enabledFilter = value as bool?;
            setState(() => _webhookEnabledFilter = enabledFilter);
            context
                .read<WebhookProvider>()
                .fetchWebhooks(enabled: enabledFilter);
          },
        ),
        Expanded(
          child: Consumer2<InstanceProvider, WebhookProvider>(
            builder: (context, instanceProvider, provider, _) {
              if (!instanceProvider.hasActiveInstance) {
                return const _NoAutomationInstanceView(
                  icon: Icons.webhook_outlined,
                  label: 'Connect to a server to manage webhooks.',
                );
              }

              if (provider.isLoading && provider.webhooks.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }

              if (provider.error != null && provider.webhooks.isEmpty) {
                return _ErrorView(
                  title: 'Could not load webhooks',
                  error: provider.error!,
                  onRetry: () => provider.fetchWebhooks(
                    enabled: _webhookEnabledFilter,
                  ),
                );
              }

              if (provider.webhooks.isEmpty) {
                return _EmptyAutomationView(
                  icon: Icons.webhook_outlined,
                  title: 'No webhooks configured',
                  message:
                      'Create a webhook to turn inbound events into background Coqui tasks without manually copying IDs or prompts.',
                  buttonLabel: 'Create Webhook',
                  onCreateTap: _openCreateWebhook,
                );
              }

              return RefreshIndicator(
                onRefresh: () => provider.fetchWebhooks(
                  enabled: _webhookEnabledFilter,
                ),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  children: [
                    _WebhookStatsRow(provider: provider),
                    const SizedBox(height: 16),
                    const _HintCard(
                      icon: Icons.key_outlined,
                      message:
                          'Webhook secrets are only fully shown when created or rotated. The detail sheet lets you copy the incoming URL and inspect deliveries without handling raw IDs.',
                    ),
                    const SizedBox(height: 16),
                    ...provider.webhooks.map(
                      (webhook) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _WebhookCard(
                          webhook: webhook,
                          onTap: () => _openWebhookDetail(webhook),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSchedulesTab() {
    return Column(
      children: [
        _FilterChips(
          selected: _scheduleEnabledFilter,
          filters: _booleanFilters,
          onSelected: (value) {
            final enabledFilter = value as bool?;
            setState(() => _scheduleEnabledFilter = enabledFilter);
            context
                .read<ScheduleProvider>()
                .fetchSchedules(enabled: enabledFilter);
          },
        ),
        Expanded(
          child: Consumer2<InstanceProvider, ScheduleProvider>(
            builder: (context, instanceProvider, provider, _) {
              if (!instanceProvider.hasActiveInstance) {
                return const _NoAutomationInstanceView(
                  icon: Icons.schedule_outlined,
                  label: 'Connect to a server to manage schedules.',
                );
              }

              if (provider.isLoading && provider.schedules.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }

              if (provider.error != null && provider.schedules.isEmpty) {
                return _ErrorView(
                  title: 'Could not load schedules',
                  error: provider.error!,
                  onRetry: () => provider.fetchSchedules(
                    enabled: _scheduleEnabledFilter,
                  ),
                );
              }

              if (provider.schedules.isEmpty) {
                return _EmptyAutomationView(
                  icon: Icons.schedule_outlined,
                  title: 'No schedules configured',
                  message:
                      'Create a recurring or one-shot schedule to run long-lived automation without reopening the app.',
                  buttonLabel: 'Create Schedule',
                  onCreateTap: _openCreateSchedule,
                );
              }

              return RefreshIndicator(
                onRefresh: () => provider.fetchSchedules(
                  enabled: _scheduleEnabledFilter,
                ),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  children: [
                    _ScheduleStatsRow(provider: provider),
                    const SizedBox(height: 16),
                    const _HintCard(
                      icon: Icons.folder_outlined,
                      message:
                          'Schedules synced from workspace JSON files are visible here but stay read-only in the app. API-managed schedules can be edited, toggled, triggered, and deleted here.',
                    ),
                    const SizedBox(height: 16),
                    ...provider.schedules.map(
                      (schedule) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _ScheduleCard(
                          schedule: schedule,
                          onTap: () => _openScheduleDetail(schedule),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLoopsTab() {
    return Column(
      children: [
        _FilterChips(
          selected: _loopStatusFilter,
          filters: _loopFilters,
          onSelected: (value) {
            final statusFilter = value as String?;
            setState(() => _loopStatusFilter = statusFilter);
            context.read<LoopProvider>().fetchLoops(status: statusFilter);
          },
        ),
        Expanded(
          child: Consumer2<InstanceProvider, LoopProvider>(
            builder: (context, instanceProvider, provider, _) {
              if (!instanceProvider.hasActiveInstance) {
                return const _NoAutomationInstanceView(
                  icon: Icons.account_tree_outlined,
                  label: 'Connect to a server to inspect and control loops.',
                );
              }

              if (provider.isLoading && provider.loops.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }

              if (provider.error != null && provider.loops.isEmpty) {
                return _ErrorView(
                  title: 'Could not load loops',
                  error: provider.error!,
                  onRetry: () => provider.fetchLoops(status: _loopStatusFilter),
                );
              }

              if (provider.loops.isEmpty) {
                return _EmptyAutomationView(
                  icon: Icons.account_tree_outlined,
                  title: 'No loops running yet',
                  message:
                      'Start a loop from a discovered definition, then use pause, resume, and stop controls instead of editing the loop after it begins.',
                  buttonLabel: 'Start Loop',
                  onCreateTap: _openCreateLoop,
                );
              }

              return RefreshIndicator(
                onRefresh: () => provider.fetchLoops(status: _loopStatusFilter),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  children: [
                    _LoopStatsRow(provider: provider),
                    const SizedBox(height: 16),
                    const _HintCard(
                      icon: Icons.rule_folder_outlined,
                      message:
                          'Loops snapshot their definition at creation time. Use the detail sheet for stage inspection and control actions instead of expecting inline loop edits.',
                    ),
                    const SizedBox(height: 16),
                    ...provider.loops.map(
                      (loop) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _LoopCard(
                          loop: loop,
                          onTap: () => _openLoopDetail(loop),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _FilterChips extends StatelessWidget {
  final Object? selected;
  final List<({String label, Object? value})> filters;
  final ValueChanged<Object?> onSelected;

  const _FilterChips({
    required this.selected,
    required this.filters,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: filters
            .map(
              (f) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(f.label),
                  selected: selected == f.value,
                  onSelected: (_) => onSelected(f.value),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _TaskListTile extends StatelessWidget {
  final CoquiTask task;
  final VoidCallback onTap;
  final VoidCallback? onCancel;

  const _TaskListTile({
    required this.task,
    required this.onTap,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dotColor = _dotColor(context);

    return ListTile(
      onTap: onTap,
      leading: Stack(
        clipBehavior: Clip.none,
        children: [
          CircleAvatar(
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            child: Icon(
              _roleIcon,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (task.isActive)
            Positioned(
              top: -2,
              right: -2,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: theme.colorScheme.surface,
                    width: 1.5,
                  ),
                ),
              ),
            ),
        ],
      ),
      title: Text(
        task.displayTitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Row(
        children: [
          TaskStatusBadge(task: task),
          const SizedBox(width: 8),
          Text(
            '· ${task.role}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (task.isActive) ...[
            const SizedBox(width: 4),
            Text(
              '· ${task.ageFormatted}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
      trailing: onCancel != null
          ? IconButton(
              icon: const Icon(Icons.stop_circle_outlined),
              tooltip: 'Cancel',
              color: theme.colorScheme.error,
              onPressed: onCancel,
            )
          : const Icon(Icons.chevron_right),
    );
  }

  Color _dotColor(BuildContext context) => switch (task.status) {
        'running' => CoquiColors.chart2,
        'pending' => CoquiColors.warning,
        'cancelling' => CoquiColors.warning,
        _ => Theme.of(context).colorScheme.onSurfaceVariant,
      };

  IconData get _roleIcon => switch (task.role) {
        'coder' => Icons.code,
        'reviewer' => Icons.rate_review_outlined,
        'vision' => Icons.image_outlined,
        _ => Icons.smart_toy_outlined,
      };
}

class _WebhookStatsRow extends StatelessWidget {
  final WebhookProvider provider;

  const _WebhookStatsRow({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'Enabled',
            value: '${provider.stats.enabled}',
            icon: Icons.cloud_done_outlined,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: 'Disabled',
            value: '${provider.stats.disabled}',
            icon: Icons.cloud_off_outlined,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: 'Accepted',
            value: '${provider.stats.totalTriggers}',
            icon: Icons.move_down_outlined,
          ),
        ),
      ],
    );
  }
}

class _ScheduleStatsRow extends StatelessWidget {
  final ScheduleProvider provider;

  const _ScheduleStatsRow({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'Enabled',
            value: '${provider.stats.enabled}',
            icon: Icons.schedule_send_outlined,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: 'Disabled',
            value: '${provider.stats.disabled}',
            icon: Icons.schedule_outlined,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: 'Runs',
            value: '${provider.stats.totalRuns}',
            icon: Icons.history_toggle_off_outlined,
          ),
        ),
      ],
    );
  }
}

class _LoopStatsRow extends StatelessWidget {
  final LoopProvider provider;

  const _LoopStatsRow({required this.provider});

  @override
  Widget build(BuildContext context) {
    final paused =
        provider.loops.where((loop) => loop.status == 'paused').length;
    final finished = provider.loops.where((loop) => loop.isFinished).length;

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'Active',
            value: '${provider.activeCount}',
            icon: Icons.play_circle_outline,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: 'Paused',
            value: '$paused',
            icon: Icons.pause_circle_outline,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: 'Finished',
            value: '$finished',
            icon: Icons.check_circle_outline,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18),
          const SizedBox(height: 10),
          Text(
            value,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _HintCard extends StatelessWidget {
  final IconData icon;
  final String message;

  const _HintCard({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

class _WebhookCard extends StatelessWidget {
  final CoquiWebhook webhook;
  final VoidCallback onTap;

  const _WebhookCard({required this.webhook, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  child: Icon(
                    switch (webhook.source) {
                      'github' => Icons.code_outlined,
                      'slack' => Icons.forum_outlined,
                      _ => Icons.webhook_outlined,
                    },
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        webhook.name,
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        webhook.hasDescription
                            ? webhook.description!
                            : 'Listens for ${webhook.sourceLabel.toLowerCase()} events and starts background work.',
                        style: theme.textTheme.bodySmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                WebhookStatusBadge(webhook: webhook),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _TagChip(label: webhook.sourceLabel),
                _TagChip(label: webhook.role),
                if (webhook.hasProfile) _TagChip(label: webhook.profile!),
                _TagChip(label: '${webhook.triggerCount} deliveries'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  final CoquiSchedule schedule;
  final VoidCallback onTap;

  const _ScheduleCard({required this.schedule, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  child: Icon(
                    schedule.isFilesystemSource
                        ? Icons.folder_outlined
                        : Icons.schedule_outlined,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        schedule.name,
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        schedule.hasDescription
                            ? schedule.description!
                            : schedule.prompt,
                        style: theme.textTheme.bodySmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                ScheduleStatusBadge(schedule: schedule),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _TagChip(label: schedule.scheduleExpression),
                _TagChip(label: schedule.role),
                _TagChip(label: schedule.timezone),
                _TagChip(label: schedule.sourceLabel),
                _TagChip(label: '${schedule.runCount} runs'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LoopCard extends StatelessWidget {
  final CoquiLoop loop;
  final VoidCallback onTap;

  const _LoopCard({required this.loop, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  child: Icon(
                    Icons.account_tree_outlined,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        loop.definitionName,
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        loop.goal,
                        style: theme.textTheme.bodySmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                LoopStatusBadge(loop: loop),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _TagChip(label: 'Iteration ${loop.currentIteration}'),
                _TagChip(label: 'Stage ${loop.currentStage}'),
                if (loop.projectId?.isNotEmpty == true)
                  _TagChip(label: loop.projectId!),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final String label;

  const _TagChip({required this.label});

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

class _EmptyTaskView extends StatelessWidget {
  final String? statusFilter;
  final VoidCallback onCreateTap;

  const _EmptyTaskView({required this.statusFilter, required this.onCreateTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isFiltered = statusFilter != null;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.task_outlined,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              isFiltered ? 'No $statusFilter tasks' : 'No background tasks yet',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              isFiltered
                  ? 'Try a different filter'
                  : 'Start a task to run long-running agent work in the background.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (!isFiltered) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onCreateTap,
                icon: const Icon(Icons.add),
                label: const Text('New Task'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyAutomationView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String buttonLabel;
  final VoidCallback onCreateTap;

  const _EmptyAutomationView({
    required this.icon,
    required this.title,
    required this.message,
    required this.buttonLabel,
    required this.onCreateTap,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 36),
            const SizedBox(height: 12),
            Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onCreateTap,
              icon: const Icon(Icons.add),
              label: Text(buttonLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoAutomationInstanceView extends StatelessWidget {
  final IconData icon;
  final String label;

  const _NoAutomationInstanceView({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 36),
            const SizedBox(height: 12),
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String title;
  final String error;
  final VoidCallback onRetry;

  const _ErrorView({
    required this.title,
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined,
                size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              error,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
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
