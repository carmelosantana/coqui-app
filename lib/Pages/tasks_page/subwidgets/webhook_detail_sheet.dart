import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:coqui_app/Models/coqui_webhook.dart';
import 'package:coqui_app/Models/coqui_webhook_delivery.dart';
import 'package:coqui_app/Providers/webhook_provider.dart';
import 'package:coqui_app/Services/coqui_api_service.dart';

import 'webhook_editor_sheet.dart';
import 'webhook_status_badge.dart';

class WebhookDetailSheet extends StatefulWidget {
  final CoquiWebhook webhook;

  const WebhookDetailSheet({super.key, required this.webhook});

  @override
  State<WebhookDetailSheet> createState() => _WebhookDetailSheetState();
}

class _WebhookDetailSheetState extends State<WebhookDetailSheet> {
  late CoquiWebhook _webhook;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _webhook = widget.webhook;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _refresh();
    });
  }

  Future<void> _refresh() async {
    setState(() => _isRefreshing = true);
    final provider = context.read<WebhookProvider>();
    final updated = await provider.loadWebhookDetail(_webhook.id, force: true);
    await provider.refreshDeliveries(_webhook.id);
    if (mounted && updated != null) {
      setState(() => _webhook = updated);
    }
    if (mounted) {
      setState(() => _isRefreshing = false);
    }
  }

  Future<void> _openEditor() async {
    final updated = await showModalBottomSheet<CoquiWebhook>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<WebhookProvider>(),
        child: WebhookEditorSheet(webhook: _webhook),
      ),
    );
    if (!mounted || updated == null) return;
    setState(() => _webhook = updated);
  }

  Future<void> _rotateSecret() async {
    final provider = context.read<WebhookProvider>();
    final secret = await provider.rotateSecret(_webhook.id);
    if (!mounted || secret == null || secret.isEmpty) return;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('New signing secret'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Store this new secret now. Future responses will only show a masked value.',
              ),
              const SizedBox(height: 12),
              SelectableText(secret),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: secret));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Secret copied to clipboard')),
                  );
                }
              },
              child: const Text('Copy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        );
      },
    );
    if (!mounted) return;
    await _refresh();
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete webhook?'),
          content: Text('Delete ${_webhook.name} and its management record?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;

    final deleted =
        await context.read<WebhookProvider>().deleteWebhook(_webhook.id);
    if (!mounted) return;
    if (deleted) {
      Navigator.pop(context, true);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.read<WebhookProvider>().error ?? 'Unable to delete webhook.',
        ),
      ),
    );
  }

  Future<void> _copyIncomingUrl() async {
    final api = context.read<CoquiApiService>();
    final url = api.getWebhookIncomingUrl(_webhook.name).toString();
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Webhook URL copied to clipboard')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.45,
      maxChildSize: 0.94,
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
                  color:
                      theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _webhook.name,
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        WebhookStatusBadge(webhook: _webhook),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _isRefreshing ? null : _refresh,
                    icon: _isRefreshing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh),
                  ),
                  IconButton(
                    onPressed: _openEditor,
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  IconButton(
                    onPressed: _rotateSecret,
                    tooltip: 'Rotate secret',
                    icon: const Icon(Icons.key_outlined),
                  ),
                  IconButton(
                    onPressed: _delete,
                    tooltip: 'Delete',
                    color: theme.colorScheme.error,
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Consumer<WebhookProvider>(
                builder: (context, provider, _) {
                  final deliveries = provider.deliveriesForWebhook(_webhook.id);
                  return ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(20),
                    children: [
                      _InfoRow(label: 'Source', value: _webhook.sourceLabel),
                      _InfoRow(label: 'Role', value: _webhook.role),
                      if (_webhook.hasProfile)
                        _InfoRow(label: 'Profile', value: _webhook.profile!),
                      _InfoRow(
                        label: 'Max iterations',
                        value: '${_webhook.maxIterations}',
                      ),
                      _InfoRow(
                        label: 'Deliveries accepted',
                        value: '${_webhook.triggerCount}',
                      ),
                      if (_webhook.lastTriggeredAt != null)
                        _InfoRow(
                          label: 'Last triggered',
                          value: _formatDateTime(_webhook.lastTriggeredAt!),
                        ),
                      const SizedBox(height: 16),
                      _SectionLabel(label: 'Incoming URL'),
                      _LinkCard(
                        value: context
                            .read<CoquiApiService>()
                            .getWebhookIncomingUrl(_webhook.name)
                            .toString(),
                        onCopy: _copyIncomingUrl,
                      ),
                      if (_webhook.hasDescription) ...[
                        const SizedBox(height: 16),
                        _SectionLabel(label: 'Description'),
                        _ContentCard(text: _webhook.description!),
                      ],
                      if (_webhook.hasEventFilter) ...[
                        const SizedBox(height: 16),
                        _SectionLabel(label: 'Event Filter'),
                        _ContentCard(text: _webhook.eventFilter!),
                      ],
                      const SizedBox(height: 16),
                      _SectionLabel(label: 'Prompt Template'),
                      _ContentCard(text: _webhook.promptTemplate),
                      const SizedBox(height: 16),
                      _SectionLabel(label: 'Signing Secret'),
                      _ContentCard(
                        text: _webhook.secretLabel,
                        subtitle: _webhook.isSecretMasked
                            ? 'This masked value is for reference only. Rotate the secret to receive the full value again.'
                            : 'This is the current full secret value.',
                      ),
                      const SizedBox(height: 16),
                      _SectionLabel(label: 'Recent Deliveries'),
                      if (deliveries.isEmpty)
                        const _EmptyDeliveries()
                      else
                        ...deliveries.map(
                          (delivery) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _DeliveryCard(delivery: delivery),
                          ),
                        ),
                      const SizedBox(height: 32),
                    ],
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  String _formatDateTime(DateTime dt) {
    final local = dt.toLocal();
    return '${local.year}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;

  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context)
          .textTheme
          .titleSmall
          ?.copyWith(fontWeight: FontWeight.w600),
    );
  }
}

class _ContentCard extends StatelessWidget {
  final String text;
  final String? subtitle;

  const _ContentCard({required this.text, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText(text),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle!,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _LinkCard extends StatelessWidget {
  final String value;
  final VoidCallback onCopy;

  const _LinkCard({required this.value, required this.onCopy});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        children: [
          Expanded(child: SelectableText(value)),
          IconButton(
            onPressed: onCopy,
            icon: const Icon(Icons.copy_outlined),
          ),
        ],
      ),
    );
  }
}

class _EmptyDeliveries extends StatelessWidget {
  const _EmptyDeliveries();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Text(
        'No deliveries recorded yet. Use the copied incoming URL from a sender to start exercising this webhook.',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}

class _DeliveryCard extends StatelessWidget {
  final CoquiWebhookDelivery delivery;

  const _DeliveryCard({required this.delivery});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
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
                  delivery.eventType?.isNotEmpty == true
                      ? delivery.eventType!
                      : 'Delivery',
                  style: theme.textTheme.labelLarge
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                delivery.statusLabel,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          if (delivery.payloadSummary?.isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Text(
              delivery.payloadSummary!,
              style: theme.textTheme.bodySmall,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (delivery.taskId?.isNotEmpty == true)
                _DeliveryChip(
                  icon: Icons.task_alt_outlined,
                  label: delivery.taskId!,
                ),
              if (delivery.sourceIp?.isNotEmpty == true)
                _DeliveryChip(
                  icon: Icons.lan_outlined,
                  label: delivery.sourceIp!,
                ),
              if (delivery.createdAt != null)
                _DeliveryChip(
                  icon: Icons.schedule_outlined,
                  label: _formatDateTime(delivery.createdAt!),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    final local = dt.toLocal();
    return '${local.month.toString().padLeft(2, '0')}/'
        '${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }
}

class _DeliveryChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _DeliveryChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}
