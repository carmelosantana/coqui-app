import 'package:flutter/material.dart';
import 'package:coqui_app/Models/coqui_task.dart';
import 'package:coqui_app/Providers/instance_provider.dart';
import 'package:coqui_app/Providers/task_provider.dart';
import 'package:coqui_app/Theme/coqui_colors.dart';
import 'package:provider/provider.dart';

import 'subwidgets/subwidgets.dart';

class TasksPage extends StatefulWidget {
  const TasksPage({super.key});

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> {
  String? _statusFilter; // null = all

  static const _statusFilters = [
    (label: 'All', value: null),
    (label: 'Active', value: 'running'),
    (label: 'Pending', value: 'pending'),
    (label: 'Completed', value: 'completed'),
    (label: 'Failed', value: 'failed'),
    (label: 'Cancelled', value: 'cancelled'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TaskProvider>().fetchTasks();
    });
  }

  void _openDetail(CoquiTask task) {
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

  void _openCreate() async {
    final hasInstance =
        context.read<InstanceProvider>().hasActiveInstance;
    if (!hasInstance) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Connect to a server first'),
        ),
      );
      return;
    }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Background Tasks'),
        actions: [
          Consumer<TaskProvider>(
            builder: (context, provider, _) {
              return IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh',
                onPressed: provider.isLoading
                    ? null
                    : () => provider.fetchTasks(statusFilter: _statusFilter),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        icon: const Icon(Icons.add),
        label: const Text('New Task'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _FilterChips(
              selected: _statusFilter,
              filters: _statusFilters,
              onSelected: (value) {
                setState(() => _statusFilter = value);
                context
                    .read<TaskProvider>()
                    .fetchTasks(statusFilter: value);
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
                      error: provider.error!,
                      onRetry: () => provider.fetchTasks(
                          statusFilter: _statusFilter),
                    );
                  }

                  if (provider.tasks.isEmpty) {
                    return _EmptyView(
                      statusFilter: _statusFilter,
                      onCreateTap: _openCreate,
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () =>
                        provider.fetchTasks(statusFilter: _statusFilter),
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(0, 8, 0, 100),
                      itemCount: provider.tasks.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, indent: 72),
                      itemBuilder: (context, index) {
                        final task = provider.tasks[index];
                        return _TaskListTile(
                          task: task,
                          onTap: () => _openDetail(task),
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
        ),
      ),
    );
  }
}

// ── Filter chips ──────────────────────────────────────────────────────────────

class _FilterChips extends StatelessWidget {
  final String? selected;
  final List<({String label, String? value})> filters;
  final ValueChanged<String?> onSelected;

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

// ── Task list tile ────────────────────────────────────────────────────────────

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
            backgroundColor:
                theme.colorScheme.surfaceContainerHighest,
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
        'pending' => Colors.orange,
        'cancelling' => Colors.orange,
        _ => Theme.of(context).colorScheme.onSurfaceVariant,
      };

  IconData get _roleIcon => switch (task.role) {
        'coder' => Icons.code,
        'reviewer' => Icons.rate_review_outlined,
        'vision' => Icons.image_outlined,
        _ => Icons.smart_toy_outlined,
      };
}

// ── Empty / Error states ──────────────────────────────────────────────────────

class _EmptyView extends StatelessWidget {
  final String? statusFilter;
  final VoidCallback onCreateTap;

  const _EmptyView({required this.statusFilter, required this.onCreateTap});

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
              isFiltered
                  ? 'No $statusFilter tasks'
                  : 'No background tasks yet',
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

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorView({required this.error, required this.onRetry});

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
            Text('Could not load tasks',
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              error,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
              maxLines: 3,
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
