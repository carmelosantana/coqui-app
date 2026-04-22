import 'package:coqui_app/Extensions/markdown_stylesheet_extension.dart';
import 'package:coqui_app/Models/coqui_backstory_inspection.dart';
import 'package:coqui_app/Models/coqui_configured_model.dart';
import 'package:coqui_app/Models/coqui_exception.dart';
import 'package:coqui_app/Models/coqui_profile.dart';
import 'package:coqui_app/Models/coqui_prompt_inspection.dart';
import 'package:coqui_app/Models/coqui_role.dart';
import 'package:coqui_app/Platform/platform_info.dart';
import 'package:coqui_app/Providers/chat_provider.dart';
import 'package:coqui_app/Providers/instance_provider.dart';
import 'package:coqui_app/Services/analytics_service.dart';
import 'package:coqui_app/Services/coqui_api_service.dart';
import 'package:coqui_app/Services/prompt_file_service.dart';
import 'package:coqui_app/Theme/coqui_colors.dart';
import 'package:coqui_app/Theme/coqui_typography.dart';
import 'package:coqui_app/Widgets/bottom_sheet_header.dart';
import 'package:coqui_app/Widgets/profile_picker_dialog.dart';
import 'package:coqui_app/Widgets/role_list_tile.dart';
import 'package:coqui_app/Widgets/selection_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';

class InfoPage extends StatefulWidget {
  const InfoPage({super.key});

  @override
  State<InfoPage> createState() => _InfoPageState();
}

class _InfoPageState extends State<InfoPage> {
  final PromptFileService _promptFileService = const PromptFileService();

  bool _isLoading = true;
  String? _error;
  String? _selectedProfile;
  String _selectedRole = '';
  List<CoquiProfile> _profiles = const [];
  List<CoquiRole> _roles = const [];
  List<CoquiConfiguredModel> _models = const [];
  CoquiPromptInspection? _promptInspection;
  CoquiBackstoryInspection? _backstoryInspection;

  @override
  void initState() {
    super.initState();
    AnalyticsService.trackEvent('info_page_opened');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final instanceProvider =
        Provider.of<InstanceProvider>(context, listen: false);
    if (!instanceProvider.hasActiveInstance) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = null;
      });
      return;
    }

    final apiService = Provider.of<CoquiApiService>(context, listen: false);
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final session = chatProvider.currentSession;
    final nextProfile = _selectedProfile ?? session?.profile;
    final nextRole = _selectedRole.isNotEmpty
        ? _selectedRole
        : (session?.modelRole ?? 'orchestrator');

    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
        _selectedProfile = nextProfile;
        _selectedRole = nextRole;
      });
    }

    try {
      final results = await Future.wait<dynamic>([
        apiService.getProfiles(),
        apiService.getRoles(),
        apiService.listModels(),
        apiService.inspectPrompt(role: nextRole, profile: nextProfile),
        apiService.inspectBackstory(profile: nextProfile),
      ]);

      if (!mounted) return;
      setState(() {
        _profiles = results[0] as List<CoquiProfile>;
        _roles = results[1] as List<CoquiRole>;
        _models = results[2] as List<CoquiConfiguredModel>;
        _promptInspection = results[3] as CoquiPromptInspection;
        _backstoryInspection = results[4] as CoquiBackstoryInspection;
        _selectedRole = _promptInspection?.role ?? nextRole;
        _selectedProfile = _promptInspection?.profile ?? nextProfile;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = CoquiException.friendly(error).message;
      });
    }
  }

  Future<void> _selectProfile() async {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final selected = await showProfilePickerDialog(
      context: context,
      title: 'Inspect Profile',
      fetchProfiles: () async => _profiles.isNotEmpty
          ? _profiles
          : chatProvider.fetchAvailableProfiles(),
      initialValue: _selectedProfile,
    );

    if (selected == null) return;
    final nextProfile = selected.isEmpty ? null : selected;
    if (nextProfile == _selectedProfile) return;

    setState(() {
      _selectedProfile = nextProfile;
    });
    await _loadData();
  }

  Future<void> _selectRole() async {
    final currentSelection =
        _roles.where((role) => role.name == _selectedRole).firstOrNull;

    final selected = await showSelectionBottomSheet<CoquiRole>(
      context: context,
      header: const BottomSheetHeader(title: 'Inspect Role'),
      fetchItems: () async => _roles,
      currentSelection: currentSelection,
      itemBuilder: (role, selected, onSelected) {
        return RoleListTile(
          role: role,
          selected: selected,
          onSelected: onSelected,
        );
      },
    );

    if (selected == null || selected.name == _selectedRole) {
      return;
    }

    setState(() {
      _selectedRole = selected.name;
    });
    await _loadData();
  }

  Future<void> _savePrompt() async {
    final promptInspection = _promptInspection;
    if (promptInspection == null) return;

    try {
      final path = await _promptFileService.savePrompt(
        prompt: promptInspection.prompt,
        role: promptInspection.role,
        profile: promptInspection.profile,
      );
      if (!mounted) return;
      _showSnackBar('Prompt saved to $path');
    } catch (error) {
      if (!mounted) return;
      _showSnackBar(CoquiException.friendly(error).message, isError: true);
    }
  }

  Future<void> _openPromptInEditor() async {
    final promptInspection = _promptInspection;
    if (promptInspection == null) return;

    try {
      final path = await _promptFileService.savePrompt(
        prompt: promptInspection.prompt,
        role: promptInspection.role,
        profile: promptInspection.profile,
      );
      await _promptFileService.openFile(path);
      if (!mounted) return;
      _showSnackBar('Opened prompt file in the default editor');
    } catch (error) {
      if (!mounted) return;
      _showSnackBar(CoquiException.friendly(error).message, isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final instanceProvider = context.watch<InstanceProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('System Prompts'),
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
              'Building prompt...',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Prompt inspection can take a moment.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
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
              Icons.text_snippet_outlined,
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
              'This page shows live prompt, model, and backstory information from the active Coqui server.',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
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
                _error ?? 'Unable to load system prompt data.',
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
    final promptInspection = _promptInspection;
    final backstoryInspection = _backstoryInspection;
    if (promptInspection == null || backstoryInspection == null) {
      return const SizedBox.shrink();
    }

    final resolvedModel = _findModel(promptInspection.resolvedModel);
    final isTwoColumnLayout = MediaQuery.sizeOf(context).width >= 1080;

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        if (isTwoColumnLayout)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildScopeCard(context),
              ),
              const SizedBox(width: 16),
              Expanded(
                child:
                    _buildModelCard(context, promptInspection, resolvedModel),
              ),
            ],
          )
        else ...[
          _buildScopeCard(context),
          const SizedBox(height: 16),
          _buildModelCard(context, promptInspection, resolvedModel),
        ],
        const SizedBox(height: 16),
        _buildPromptCard(context, promptInspection),
        const SizedBox(height: 16),
        _buildBackstoryCard(context, backstoryInspection),
      ],
    );
  }

  Widget _buildScopeCard(BuildContext context) {
    final instance = context.read<InstanceProvider>().activeInstance;
    return _InfoSectionCard(
      title: 'Scope',
      subtitle: 'Inspect the runtime state for a specific profile and role.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (instance != null) ...[
            _KeyValueRow(label: 'Server', value: instance.name),
            const SizedBox(height: 8),
            _KeyValueRow(
                label: 'Base URL', value: instance.baseUrl, monospace: true),
            const SizedBox(height: 16),
          ],
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              OutlinedButton.icon(
                onPressed: _selectProfile,
                icon: const Icon(Icons.person_outline),
                label: Text(
                    _selectedProfile == null || _selectedProfile!.isEmpty
                        ? 'Profile: none'
                        : 'Profile: $_selectedProfile'),
              ),
              OutlinedButton.icon(
                onPressed: _roles.isEmpty ? null : _selectRole,
                icon: const Icon(Icons.smart_toy_outlined),
                label: Text('Role: $_selectedRole'),
              ),
              IconButton(
                onPressed: _loadData,
                tooltip: 'Refresh',
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModelCard(
    BuildContext context,
    CoquiPromptInspection promptInspection,
    CoquiConfiguredModel? resolvedModel,
  ) {
    final version = resolvedModel?.version ??
        _extractVersion(promptInspection.resolvedModel);

    return _InfoSectionCard(
      title: 'Model',
      subtitle: 'Resolved model information for the selected role and profile.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _KeyValueRow(
            label: 'Resolved model',
            value: promptInspection.resolvedModel ?? 'Unavailable',
            monospace: true,
          ),
          const SizedBox(height: 8),
          _KeyValueRow(label: 'Role', value: promptInspection.role),
          const SizedBox(height: 8),
          _KeyValueRow(
            label: 'Provider',
            value: resolvedModel?.provider ??
                _extractProvider(promptInspection.resolvedModel) ??
                'Unknown',
          ),
          const SizedBox(height: 8),
          _KeyValueRow(label: 'Version', value: version ?? 'Unknown'),
          if (resolvedModel != null) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MetricChip(
                    label: 'Context',
                    value: _formatNumber(resolvedModel.contextWindow)),
                _MetricChip(
                    label: 'Max output',
                    value: _formatNumber(resolvedModel.maxTokens)),
                if (resolvedModel.family?.isNotEmpty == true)
                  _MetricChip(label: 'Family', value: resolvedModel.family!),
                if (resolvedModel.metadataSource?.isNotEmpty == true)
                  _MetricChip(
                      label: 'Metadata', value: resolvedModel.metadataSource!),
                _MetricChip(
                    label: 'Reasoning',
                    value: resolvedModel.reasoning ? 'Yes' : 'No'),
                _MetricChip(
                    label: 'Tool calls',
                    value: resolvedModel.toolCalls ? 'Yes' : 'No'),
                _MetricChip(
                    label: 'Vision',
                    value: resolvedModel.vision ? 'Yes' : 'No'),
                _MetricChip(
                    label: 'Thinking',
                    value: resolvedModel.thinking ? 'Yes' : 'No'),
              ],
            ),
            if (resolvedModel.input.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Inputs: ${resolvedModel.input.join(', ')}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildPromptCard(
    BuildContext context,
    CoquiPromptInspection promptInspection,
  ) {
    final budget = promptInspection.budget;
    final contextWindow =
        (budget['context_window'] as Map?)?.cast<String, dynamic>() ?? const {};
    final promptSections = (budget['prompt_sections'] as List? ?? [])
        .whereType<Map>()
        .map((section) => section.cast<String, dynamic>())
        .toList();

    return _InfoSectionCard(
      title: 'System Prompt',
      subtitle:
          'Rendered markdown prompt with prompt-budget and source details.',
      trailing: Wrap(
        spacing: 4,
        children: [
          IconButton(
            onPressed: _savePrompt,
            tooltip: 'Save Prompt',
            icon: const Icon(Icons.download_outlined),
          ),
          IconButton(
            onPressed: PlatformInfo.isDesktop ? _openPromptInEditor : null,
            tooltip: PlatformInfo.isDesktop
                ? 'Open in Editor'
                : 'Open in editor is desktop only',
            icon: const Icon(Icons.open_in_new_outlined),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetricChip(
                  label: 'Prompt tokens',
                  value: _formatNumber(promptInspection.promptTokens)),
              _MetricChip(
                  label: 'Tool tokens',
                  value: _formatNumber(promptInspection.toolTokens)),
              _MetricChip(
                  label: 'Total',
                  value: _formatNumber(promptInspection.totalTokens)),
              _MetricChip(
                  label: 'Tools', value: '${promptInspection.toolCount}'),
              _MetricChip(
                  label: 'Toolkits', value: '${promptInspection.toolkitCount}'),
              if (contextWindow.isNotEmpty)
                _MetricChip(
                  label: 'Context usage',
                  value:
                      '${(contextWindow['usage_percent'] as num?)?.toStringAsFixed(1) ?? '0'}%',
                ),
              if (contextWindow.isNotEmpty)
                _MetricChip(
                  label: 'Available',
                  value: _formatNumber(
                      contextWindow['available_tokens'] as int? ?? 0),
                ),
              _MetricChip(
                label: 'Backstory in prompt',
                value: _formatNumber(
                    _promptSectionTokens(promptSections, 'backstory')),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _KeyValueRow(
            label: 'File-backed prompt tokens',
            value: _formatNumber(
                promptInspection.promptSources['file_backed_tokens'] as int? ??
                    0),
          ),
          const SizedBox(height: 8),
          _KeyValueRow(
            label: 'Synthetic prompt tokens',
            value: _formatNumber(
                promptInspection.promptSources['synthetic_tokens'] as int? ??
                    0),
          ),
          const SizedBox(height: 8),
          _KeyValueRow(
            label: 'Deferred toolkits',
            value:
                '${(budget['deferred_toolkits'] as List? ?? const []).length}',
          ),
          if (promptSections.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Largest prompt sections',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            ...promptSections.take(5).map(
                  (section) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: _KeyValueRow(
                      label: section['title'] as String? ??
                          section['id'] as String? ??
                          'Section',
                      value: _formatNumber(section['tokens'] as int? ?? 0),
                    ),
                  ),
                ),
          ],
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(CoquiColors.radiusMd),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: MarkdownBody(
              data: promptInspection.prompt,
              selectable: true,
              styleSheet: context.markdownStyleSheet,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackstoryCard(
    BuildContext context,
    CoquiBackstoryInspection inspection,
  ) {
    final promptSections =
        ((_promptInspection?.budget['prompt_sections']) as List? ?? [])
            .whereType<Map>()
            .map((section) => section.cast<String, dynamic>())
            .toList();

    return _InfoSectionCard(
      title: 'Backstory',
      subtitle:
          'Generated backstory content and profile-specific source statistics.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetricChip(
                  label: 'Available',
                  value: inspection.available ? 'Yes' : 'No'),
              _MetricChip(label: 'Files', value: '${inspection.totalFiles}'),
              _MetricChip(
                  label: 'Supported',
                  value: '${inspection.supportedFileCount}'),
              _MetricChip(
                  label: 'Unsupported',
                  value: '${inspection.unsupportedFileCount}'),
              _MetricChip(
                  label: 'Failed', value: '${inspection.failedFileCount}'),
              _MetricChip(
                  label: 'Tokens',
                  value: _formatNumber(inspection.totalTokens)),
              _MetricChip(
                label: 'Prompt impact',
                value: _formatNumber(
                    _promptSectionTokens(promptSections, 'backstory')),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _KeyValueRow(
              label: 'Source folder',
              value: inspection.sourceFolder ?? 'None',
              monospace: true),
          const SizedBox(height: 8),
          _KeyValueRow(
              label: 'Generated file',
              value: inspection.generatedBackstoryPath ?? 'None',
              monospace: true),
          const SizedBox(height: 8),
          _KeyValueRow(
              label: 'Last modified',
              value: _formatIsoDate(inspection.lastModifiedAt) ?? 'Unknown'),
          const SizedBox(height: 8),
          _KeyValueRow(
              label: 'Generated at',
              value: _formatIsoDate(inspection.generatedAt) ?? 'Unknown'),
          const SizedBox(height: 8),
          _KeyValueRow(
              label: 'Size', value: _formatBytes(inspection.totalSizeBytes)),
          if (inspection.content != null &&
              inspection.content!.trim().isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(CoquiColors.radiusMd),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: MarkdownBody(
                data: inspection.content!,
                selectable: true,
                styleSheet: context.markdownStyleSheet,
              ),
            ),
          ] else if (!inspection.available) ...[
            const SizedBox(height: 16),
            Text(
              'No profile is selected, so there is no active backstory to inspect.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ],
      ),
    );
  }

  CoquiConfiguredModel? _findModel(String? id) {
    if (id == null || id.isEmpty) {
      return null;
    }

    for (final model in _models) {
      if (model.id == id) {
        return model;
      }
    }

    return null;
  }

  int _promptSectionTokens(
    List<Map<String, dynamic>> sections,
    String fragment,
  ) {
    for (final section in sections) {
      final id = section['id'] as String? ?? '';
      final title = section['title'] as String? ?? '';
      if (id.contains(fragment) || title.toLowerCase().contains(fragment)) {
        return section['tokens'] as int? ?? 0;
      }
    }
    return 0;
  }

  String _formatNumber(int value) {
    final raw = value.toString();
    final buffer = StringBuffer();
    for (var index = 0; index < raw.length; index++) {
      final reverseIndex = raw.length - index;
      buffer.write(raw[index]);
      if (reverseIndex > 1 && reverseIndex % 3 == 1) {
        buffer.write(',');
      }
    }
    return buffer.toString();
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    }
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String? _formatIsoDate(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }

    final parsed = DateTime.tryParse(value);
    if (parsed == null) {
      return value;
    }

    final local = parsed.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.year}-$month-$day $hour:$minute';
  }

  String? _extractProvider(String? resolvedModel) {
    if (resolvedModel == null || !resolvedModel.contains('/')) {
      return null;
    }
    return resolvedModel.split('/').first;
  }

  String? _extractVersion(String? resolvedModel) {
    if (resolvedModel == null || !resolvedModel.contains(':')) {
      return null;
    }
    return resolvedModel.split(':').last;
  }
}

class _InfoSectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;

  const _InfoSectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
    this.trailing,
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
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
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  final String label;
  final String value;

  const _MetricChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondary,
        borderRadius: BorderRadius.circular(CoquiColors.radiusMd),
        border: Border.all(color: theme.dividerColor),
      ),
      child: RichText(
        text: TextSpan(
          style: theme.textTheme.bodySmall,
          children: [
            TextSpan(
              text: '$label: ',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            TextSpan(
              text: value,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KeyValueRow extends StatelessWidget {
  final String label;
  final String value;
  final bool monospace;

  const _KeyValueRow({
    required this.label,
    required this.value,
    this.monospace = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 130,
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
            style: monospace
                ? CoquiTypography.monoStyle(theme.textTheme.bodyMedium)
                : theme.textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}

extension _FirstWhereOrNullExtension<T> on Iterable<T> {
  T? get firstOrNull {
    for (final value in this) {
      return value;
    }
    return null;
  }
}
