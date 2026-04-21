import 'package:coqui_app/Models/coqui_command_catalog.dart';
import 'package:coqui_app/Models/coqui_exception.dart';
import 'package:coqui_app/Providers/instance_provider.dart';
import 'package:coqui_app/Services/analytics_service.dart';
import 'package:coqui_app/Services/coqui_api_service.dart';
import 'package:coqui_app/Theme/coqui_colors.dart';
import 'package:coqui_app/Theme/coqui_typography.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class CommandsHelpPage extends StatefulWidget {
  const CommandsHelpPage({super.key});

  @override
  State<CommandsHelpPage> createState() => _CommandsHelpPageState();
}

class _CommandsHelpPageState extends State<CommandsHelpPage> {
  bool _isLoading = true;
  String? _error;
  CoquiCommandCatalog? _catalog;

  @override
  void initState() {
    super.initState();
    AnalyticsService.trackEvent('commands_help_page_opened');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final instanceProvider = context.read<InstanceProvider>();
    if (!instanceProvider.hasActiveInstance) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = null;
        _catalog = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final catalog = await context.read<CoquiApiService>().getCommandCatalog();
      if (!mounted) return;
      setState(() {
        _catalog = catalog;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = CoquiException.friendly(error).message;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final instanceProvider = context.watch<InstanceProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Commands Help'),
      ),
      body: SafeArea(
        child: !instanceProvider.hasActiveInstance
            ? _buildNoInstanceState(context)
            : _isLoading
                ? _buildLoadingState(context)
                : _error != null
                    ? _buildErrorState(context)
                    : _buildContent(context),
      ),
    );
  }

  Widget _buildNoInstanceState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.help_outline,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              'Connect to a server first',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Commands Help is sourced from the active Coqui server runtime.',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Loading commands...',
              style: theme.textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 12),
              Text(
                _error ?? 'Unable to load commands help.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final catalog = _catalog;
    if (catalog == null) {
      return const SizedBox.shrink();
    }

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        _CommandsSectionCard(
          title: 'Overview',
          subtitle: 'Live slash-command help sourced from the server runtime.',
          child: _CommandsKeyValueRow(
            label: 'Commands',
            value: '${catalog.count}',
          ),
        ),
        const SizedBox(height: 16),
        ...catalog.sections.map(
          (section) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _CommandsSectionExpansion(section: section),
          ),
        ),
      ],
    );
  }
}

class _CommandsSectionExpansion extends StatelessWidget {
  final CoquiCommandSection section;

  const _CommandsSectionExpansion({required this.section});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(CoquiColors.radiusLg),
        border: Border.all(color: theme.dividerColor),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            section.name,
            textAlign: TextAlign.left,
          ),
        ),
        children: section.commands
            .map(
              (command) => Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(CoquiColors.radiusMd),
                  border: Border.all(color: theme.dividerColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      command.usage,
                      textAlign: TextAlign.left,
                      style: CoquiTypography.monoStyle(
                        theme.textTheme.bodyMedium,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      command.helpDescription,
                      textAlign: TextAlign.left,
                      style: theme.textTheme.bodySmall,
                    ),
                    if (command.aliases.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _CommandsKeyValueRow(
                        label: 'Aliases',
                        value: command.aliases.join(', '),
                      ),
                    ],
                    if (command.firstArguments.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _CommandsKeyValueRow(
                        label: 'First args',
                        value: command.firstArguments.join(', '),
                      ),
                    ],
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _CommandsSectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _CommandsSectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(CoquiColors.radiusLg),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _CommandsKeyValueRow extends StatelessWidget {
  final String label;
  final String value;

  const _CommandsKeyValueRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 96,
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.left,
            style: theme.textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}