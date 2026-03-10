import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:coqui_app/Models/hosted_instance.dart';
import 'package:coqui_app/Providers/auth_provider.dart';
import 'package:coqui_app/Providers/hosted_provider.dart';

/// Page listing the user's hosted Coqui instances.
class HostedInstancesPage extends StatefulWidget {
  const HostedInstancesPage({super.key});

  @override
  State<HostedInstancesPage> createState() => _HostedInstancesPageState();
}

class _HostedInstancesPageState extends State<HostedInstancesPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HostedProvider>().loadAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hosted Instances'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<HostedProvider>().refreshInstances(),
          ),
        ],
      ),
      floatingActionButton: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          if (!auth.isLoggedIn) return const SizedBox.shrink();
          return FloatingActionButton.extended(
            onPressed: () => _showDeployDialog(context),
            icon: const Icon(Icons.add),
            label: const Text('Deploy'),
          );
        },
      ),
      body: Consumer2<AuthProvider, HostedProvider>(
        builder: (context, auth, hosted, _) {
          if (!auth.isLoggedIn) {
            return const Center(
              child: Text('Please sign in to manage hosted instances.'),
            );
          }

          if (hosted.isLoading && hosted.instances.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          return Column(
            children: [
              // Error banner
              if (hosted.error != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  color: colorScheme.errorContainer,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          hosted.error!,
                          style: TextStyle(color: colorScheme.onErrorContainer),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => hosted.clearError(),
                      ),
                    ],
                  ),
                ),

              // Instance list
              Expanded(
                child: hosted.instances.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.cloud_outlined,
                              size: 64,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No hosted instances yet',
                              style: textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Deploy your first Coqui instance to get started.',
                              style: textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: hosted.refreshInstances,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: hosted.instances.length,
                          itemBuilder: (context, index) {
                            return _InstanceCard(
                              instance: hosted.instances[index],
                            );
                          },
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showDeployDialog(BuildContext context) {
    final labelController = TextEditingController();
    String? selectedRegion;
    final hosted = context.read<HostedProvider>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Deploy New Instance'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: labelController,
                decoration: const InputDecoration(
                  labelText: 'Instance Label',
                  hintText: 'e.g. my-coqui',
                ),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              if (hosted.regions.isNotEmpty)
                DropdownButtonFormField<String>(
                  initialValue: selectedRegion,
                  decoration: const InputDecoration(labelText: 'Region'),
                  items: hosted.regions
                      .map((r) => DropdownMenuItem(
                            value: r.id,
                            child: Text(r.displayLabel),
                          ))
                      .toList(),
                  onChanged: (v) => setDialogState(() => selectedRegion = v),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final label = labelController.text.trim();
                if (label.isEmpty) return;
                Navigator.pop(ctx);
                final instance = await hosted.deploy(
                  label: label,
                  region: selectedRegion,
                );
                if (instance != null && context.mounted) {
                  Navigator.pushNamed(
                    context,
                    '/hosted/detail',
                    arguments: instance.id,
                  );
                }
              },
              child: const Text('Deploy'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Instance Card ────────────────────────────────────────────────────────

class _InstanceCard extends StatelessWidget {
  final HostedInstance instance;
  const _InstanceCard({required this.instance});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.pushNamed(
          context,
          '/hosted/detail',
          arguments: instance.id,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Status indicator
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _statusColor(colorScheme),
                ),
              ),
              const SizedBox(width: 16),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      instance.label,
                      style: textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      instance.displayStatus,
                      style: textTheme.bodySmall?.copyWith(
                        color: _statusColor(colorScheme),
                      ),
                    ),
                    if (instance.url != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        instance.url!,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Region badge
              if (instance.region != null)
                Chip(
                  label: Text(
                    instance.region!,
                    style: textTheme.labelSmall,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  Color _statusColor(ColorScheme colorScheme) {
    if (instance.isActive) return Colors.green;
    if (instance.isProvisioning) return Colors.orange;
    if (instance.isError) return colorScheme.error;
    return colorScheme.onSurfaceVariant;
  }
}
