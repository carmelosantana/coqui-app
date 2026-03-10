import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher_string.dart';

import 'package:coqui_app/Models/hosted_instance.dart';
import 'package:coqui_app/Providers/hosted_provider.dart';

/// Detail page for a single hosted instance — status, actions, metrics, snapshots.
class HostedDetailPage extends StatefulWidget {
  final int instanceId;
  const HostedDetailPage({super.key, required this.instanceId});

  @override
  State<HostedDetailPage> createState() => _HostedDetailPageState();
}

class _HostedDetailPageState extends State<HostedDetailPage> {
  HostedInstance? _instance;
  List<InstanceMetric> _metrics = [];
  List<InstanceSnapshot> _snapshots = [];
  bool _loading = true;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final hosted = context.read<HostedProvider>();
    final instance = await hosted.getInstance(widget.instanceId);
    if (instance == null || !mounted) return;

    final results = await Future.wait([
      hosted.getMetrics(widget.instanceId),
      hosted.getSnapshots(widget.instanceId),
    ]);

    if (!mounted) return;
    setState(() {
      _instance = instance;
      _metrics = results[0] as List<InstanceMetric>;
      _snapshots = results[1] as List<InstanceSnapshot>;
      _loading = false;
    });

    // Auto-refresh while provisioning.
    if (instance.isProvisioning) {
      _pollTimer?.cancel();
      _pollTimer = Timer.periodic(
        const Duration(seconds: 10),
        (_) => _refresh(),
      );
    }
  }

  Future<void> _refresh() async {
    final hosted = context.read<HostedProvider>();
    final instance = await hosted.getInstance(widget.instanceId);
    if (instance == null || !mounted) return;

    setState(() => _instance = instance);

    // Stop polling once provisioning is done.
    if (!instance.isProvisioning) {
      _pollTimer?.cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_instance?.label ?? 'Instance'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _instance == null
              ? const Center(child: Text('Instance not found.'))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _StatusSection(instance: _instance!),
                    const SizedBox(height: 16),
                    _ConnectionSection(instance: _instance!),
                    const SizedBox(height: 16),
                    _ActionsSection(
                      instance: _instance!,
                      onActionPerformed: _load,
                    ),
                    if (_metrics.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _MetricsSection(metrics: _metrics),
                    ],
                    if (_snapshots.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _SnapshotsSection(
                        instanceId: widget.instanceId,
                        snapshots: _snapshots,
                        onRestore: _load,
                      ),
                    ],
                    const SizedBox(height: 24),
                    _DestroySection(
                      instance: _instance!,
                      onDestroyed: () => Navigator.pop(context),
                    ),
                  ],
                ),
    );
  }
}

// ── Status Section ──────────────────────────────────────────────────────

class _StatusSection extends StatelessWidget {
  final HostedInstance instance;
  const _StatusSection({required this.instance});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _statusColor(instance, colorScheme),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(instance.displayStatus, style: textTheme.titleMedium),
                if (instance.region != null)
                  Text(
                    'Region: ${instance.region}',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(HostedInstance instance, ColorScheme scheme) {
    if (instance.isActive) return Colors.green;
    if (instance.isProvisioning) return Colors.orange;
    if (instance.isError) return scheme.error;
    return scheme.onSurfaceVariant;
  }
}

// ── Connection Section ──────────────────────────────────────────────────

class _ConnectionSection extends StatelessWidget {
  final HostedInstance instance;
  const _ConnectionSection({required this.instance});

  @override
  Widget build(BuildContext context) {
    if (instance.url == null && instance.apiKey == null) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Connection', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 12),
            if (instance.url != null)
              _InfoRow(
                label: 'URL',
                value: instance.url!,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.copy, size: 18),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: instance.url!));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('URL copied')),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.open_in_new, size: 18),
                      onPressed: () => launchUrlString(instance.url!),
                    ),
                  ],
                ),
              ),
            if (instance.apiKey != null) ...[
              const SizedBox(height: 8),
              _InfoRow(
                label: 'API Key',
                value:
                    '••••${instance.apiKey!.substring(instance.apiKey!.length - 4)}',
                trailing: IconButton(
                  icon: const Icon(Icons.copy, size: 18),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: instance.apiKey!));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('API key copied')),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Widget? trailing;
  const _InfoRow({required this.label, required this.value, this.trailing});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(child: Text(value, style: textTheme.bodyMedium)),
        if (trailing != null) trailing!,
      ],
    );
  }
}

// ── Actions Section ──────────────────────────────────────────────────────

class _ActionsSection extends StatelessWidget {
  final HostedInstance instance;
  final VoidCallback onActionPerformed;
  const _ActionsSection({
    required this.instance,
    required this.onActionPerformed,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Actions', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (instance.isStopped)
                  _ActionButton(
                    icon: Icons.play_arrow,
                    label: 'Start',
                    onPressed: () => _perform(context, 'start'),
                  ),
                if (instance.isActive)
                  _ActionButton(
                    icon: Icons.stop,
                    label: 'Stop',
                    onPressed: () => _perform(context, 'stop'),
                  ),
                if (instance.isActive)
                  _ActionButton(
                    icon: Icons.restart_alt,
                    label: 'Reboot',
                    onPressed: () => _perform(context, 'reboot'),
                  ),
                if (instance.isActive)
                  _ActionButton(
                    icon: Icons.backup,
                    label: 'Backup',
                    onPressed: () => _performBackup(context),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _perform(BuildContext context, String action) async {
    final hosted = context.read<HostedProvider>();
    await hosted.performAction(instance.id, action);
    onActionPerformed();
  }

  Future<void> _performBackup(BuildContext context) async {
    final descController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create Backup'),
        content: TextField(
          controller: descController,
          decoration: const InputDecoration(
            labelText: 'Description (optional)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Backup'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;
    final hosted = context.read<HostedProvider>();
    await hosted.performAction(
      instance.id,
      'backup',
      description: descController.text.isNotEmpty ? descController.text : null,
    );
    onActionPerformed();
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}

// ── Metrics Section ──────────────────────────────────────────────────────

class _MetricsSection extends StatelessWidget {
  final List<InstanceMetric> metrics;
  const _MetricsSection({required this.metrics});

  @override
  Widget build(BuildContext context) {
    final latest = metrics.last;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Metrics', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _GaugeCard(
                    label: 'CPU',
                    percent: latest.cpuPercent,
                    colorScheme: colorScheme,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _GaugeCard(
                    label: 'RAM',
                    percent: latest.ramPercent,
                    colorScheme: colorScheme,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _GaugeCard(
                    label: 'Disk',
                    percent: latest.diskPercent,
                    colorScheme: colorScheme,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GaugeCard extends StatelessWidget {
  final String label;
  final double percent;
  final ColorScheme colorScheme;
  const _GaugeCard({
    required this.label,
    required this.percent,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    final color = percent > 80
        ? colorScheme.error
        : percent > 60
            ? Colors.orange
            : Colors.green;

    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 56,
              height: 56,
              child: CircularProgressIndicator(
                value: percent / 100,
                strokeWidth: 6,
                backgroundColor: colorScheme.surfaceContainerHighest,
                color: color,
              ),
            ),
            Text(
              '${percent.round()}%',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}

// ── Snapshots Section ────────────────────────────────────────────────────

class _SnapshotsSection extends StatelessWidget {
  final int instanceId;
  final List<InstanceSnapshot> snapshots;
  final VoidCallback onRestore;
  const _SnapshotsSection({
    required this.instanceId,
    required this.snapshots,
    required this.onRestore,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Backups', style: textTheme.titleSmall),
            const SizedBox(height: 12),
            ...snapshots.map((snap) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.backup),
                  title: Text(
                    snap.description ?? 'Backup #${snap.id}',
                    style: textTheme.bodyMedium,
                  ),
                  subtitle: Text(
                    '${_formatDate(snap.createdAt)}'
                    '${snap.sizeGb != null ? ' · ${snap.sizeGb} GB' : ''}',
                    style: textTheme.bodySmall,
                  ),
                  trailing: snap.vultrSnapshotId != null
                      ? TextButton(
                          onPressed: () => _restore(
                            context,
                            snap.vultrSnapshotId!,
                          ),
                          child: const Text('Restore'),
                        )
                      : null,
                )),
          ],
        ),
      ),
    );
  }

  Future<void> _restore(BuildContext context, String snapshotId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore Backup'),
        content: const Text(
          'This will replace the current instance data with this backup. '
          'Are you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;
    final hosted = context.read<HostedProvider>();
    await hosted.performAction(
      instanceId,
      'restore',
      snapshotId: snapshotId,
    );
    onRestore();
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}

// ── Destroy Section ────────────────────────────────────────────────────

class _DestroySection extends StatelessWidget {
  final HostedInstance instance;
  final VoidCallback onDestroyed;
  const _DestroySection({
    required this.instance,
    required this.onDestroyed,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color:
          Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.3),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Danger Zone',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _confirmDestroy(context),
                icon: const Icon(Icons.delete_forever),
                label: const Text('Destroy Instance'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDestroy(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Destroy Instance'),
        content: Text(
          'This will permanently delete "${instance.label}" and all its data. '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Destroy'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;
    final hosted = context.read<HostedProvider>();
    final ok = await hosted.destroy(instance.id);
    if (ok) onDestroyed();
  }
}
