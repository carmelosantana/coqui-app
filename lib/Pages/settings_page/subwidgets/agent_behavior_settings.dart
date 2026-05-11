import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:coqui_app/Models/coqui_context_settings.dart';
import 'package:coqui_app/Models/coqui_exception.dart';
import 'package:coqui_app/Providers/instance_provider.dart';
import 'package:coqui_app/Utils/server_restart_prompt.dart';

class AgentBehaviorSettings extends StatefulWidget {
  const AgentBehaviorSettings({super.key});

  @override
  State<AgentBehaviorSettings> createState() => _AgentBehaviorSettingsState();
}

class _AgentBehaviorSettingsState extends State<AgentBehaviorSettings> {
  final _thresholdController = TextEditingController();
  final _turnThresholdController = TextEditingController();
  final _keepRecentController = TextEditingController();

  CoquiContextSettings? _settings;
  bool _loading = false;
  bool _saving = false;
  bool _resetting = false;
  String? _error;
  String? _loadedInstanceId;

  bool _conversationHistoryInSystemPrompt = false;
  String _autoSummarizeMode = 'token';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final instanceId = context.read<InstanceProvider>().activeInstance?.id;
    if (instanceId != _loadedInstanceId) {
      _loadedInstanceId = instanceId;
      _loadSettings();
    }
  }

  @override
  void dispose() {
    _thresholdController.dispose();
    _turnThresholdController.dispose();
    _keepRecentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<InstanceProvider>(
      builder: (context, instanceProvider, _) {
        final activeInstance = instanceProvider.activeInstance;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Agent Behavior',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Adjust how Coqui manages conversation history and summarization for the active server.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            if (activeInstance == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                    'Select an active server to manage agent behavior settings.'),
              )
            else if (_loading && _settings == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_error != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: _loading ? null : _loadSettings,
                    child: const Text('Retry'),
                  ),
                ],
              )
            else if (_settings != null)
              _buildEditor(context),
          ],
        );
      },
    );
  }

  Widget _buildEditor(BuildContext context) {
    final settings = _settings!;
    final theme = Theme.of(context);
    final saveEnabled = !_saving && !_resetting && _hasChanges;
    final resetEnabled = !_saving && !_resetting;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile.adaptive(
          value: _conversationHistoryInSystemPrompt,
          contentPadding: EdgeInsets.zero,
          title: Text(_labelFor('conversationHistoryInSystemPrompt')),
          subtitle: Text(_helperTextFor('conversationHistoryInSystemPrompt')),
          onChanged: _saving || _resetting
              ? null
              : (value) {
                  setState(() {
                    _conversationHistoryInSystemPrompt = value;
                  });
                },
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _autoSummarizeMode,
          decoration: InputDecoration(
            labelText: _labelFor('autoSummarizeMode'),
            helperText: _helperTextFor('autoSummarizeMode'),
            border: const OutlineInputBorder(),
          ),
          items: settings.fields['autoSummarizeMode']!.options
              .map(
                (option) => DropdownMenuItem<String>(
                  value: option,
                  child: Text(option),
                ),
              )
              .toList(growable: false),
          onChanged: _saving || _resetting
              ? null
              : (value) {
                  if (value == null) return;
                  setState(() {
                    _autoSummarizeMode = value;
                  });
                },
        ),
        if (_autoSummarizeMode == 'token') ...[
          const SizedBox(height: 12),
          TextField(
            controller: _thresholdController,
            enabled: !_saving && !_resetting,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: _labelFor('autoSummarizeThreshold'),
              helperText: _helperTextFor('autoSummarizeThreshold'),
              errorText: _thresholdError,
              border: const OutlineInputBorder(),
              suffixText: '%',
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
        if (_autoSummarizeMode == 'turn') ...[
          const SizedBox(height: 12),
          TextField(
            controller: _turnThresholdController,
            enabled: !_saving && !_resetting,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: _labelFor('autoSummarizeTurnThreshold'),
              helperText: _helperTextFor('autoSummarizeTurnThreshold'),
              errorText: _turnThresholdError,
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
        const SizedBox(height: 12),
        TextField(
          controller: _keepRecentController,
          enabled: !_saving && !_resetting,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: _labelFor('autoSummarizeKeepRecent'),
            helperText: _helperTextFor('autoSummarizeKeepRecent'),
            errorText: _keepRecentError,
            border: const OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        if (_settings!.restart.required ||
            context.watch<InstanceProvider>().restartRequired)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              context.watch<InstanceProvider>().restartState.reason ??
                  settings.restart.reason ??
                  'Restart the API server to apply these behavior changes.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          ),
        const SizedBox(height: 12),
        Row(
          children: [
            OutlinedButton(
              onPressed: resetEnabled ? _resetSection : null,
              child: _resetting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Reset Section'),
            ),
            const SizedBox(width: 12),
            FilledButton(
              onPressed: saveEnabled ? _save : null,
              child: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save Changes'),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _loadSettings() async {
    final instanceProvider = context.read<InstanceProvider>();
    if (instanceProvider.activeInstance == null) {
      setState(() {
        _settings = null;
        _error = null;
        _loading = false;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final settings = await instanceProvider.apiService.getContextSettings();
      if (!mounted) return;

      _applySettings(settings);
      setState(() {
        _settings = settings;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = CoquiException.friendly(error).message;
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  void _applySettings(CoquiContextSettings settings) {
    _conversationHistoryInSystemPrompt =
        settings.context.conversationHistoryInSystemPrompt;
    _autoSummarizeMode = settings.context.autoSummarizeMode;
    _thresholdController.text =
        _formatNumber(settings.context.autoSummarizeThreshold);
    _turnThresholdController.text =
        settings.context.autoSummarizeTurnThreshold.toString();
    _keepRecentController.text =
        settings.context.autoSummarizeKeepRecent.toString();
  }

  String _formatNumber(double value) {
    return value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toString();
  }

  String _labelFor(String key) => _settings!.fields[key]?.label ?? key;

  String _helperTextFor(String key) {
    final field = _settings!.fields[key];
    if (field == null) return '';

    final defaultLabel = switch (field.defaultValue) {
      bool value => value ? 'On' : 'Off',
      num value => value == value.roundToDouble()
          ? value.toInt().toString()
          : value.toString(),
      _ => field.defaultValue?.toString() ?? '',
    };

    return '${field.description} Default: $defaultLabel.';
  }

  bool get _hasChanges {
    final settings = _settings;
    if (settings == null) return false;

    final threshold = _parsedThreshold;
    final turnThreshold = _parsedTurnThreshold;
    final keepRecent = _parsedKeepRecent;

    return settings.context.conversationHistoryInSystemPrompt !=
            _conversationHistoryInSystemPrompt ||
        settings.context.autoSummarizeMode != _autoSummarizeMode ||
        (_autoSummarizeMode == 'token' &&
            threshold != null &&
            settings.context.autoSummarizeThreshold != threshold) ||
        (_autoSummarizeMode == 'turn' &&
            turnThreshold != null &&
            settings.context.autoSummarizeTurnThreshold != turnThreshold) ||
        (keepRecent != null &&
            settings.context.autoSummarizeKeepRecent != keepRecent);
  }

  double? get _parsedThreshold =>
      double.tryParse(_thresholdController.text.trim());

  int? get _parsedTurnThreshold =>
      int.tryParse(_turnThresholdController.text.trim());

  int? get _parsedKeepRecent => int.tryParse(_keepRecentController.text.trim());

  String? get _thresholdError {
    if (_autoSummarizeMode != 'token') return null;
    final value = _parsedThreshold;
    if (value == null) return 'Enter a number between 0 and 100.';
    if ((value > 0 && value <= 1) || (value >= 1 && value <= 100)) return null;
    return 'Use 0.0-1.0 or 1-100.';
  }

  String? get _turnThresholdError {
    if (_autoSummarizeMode != 'turn') return null;
    final value = _parsedTurnThreshold;
    if (value == null || value < 1)
      return 'Enter a whole number greater than or equal to 1.';
    return null;
  }

  String? get _keepRecentError {
    final value = _parsedKeepRecent;
    if (value == null || value < 1 || value > 20) {
      return 'Enter a whole number between 1 and 20.';
    }
    return null;
  }

  Future<void> _save() async {
    if (_thresholdError != null ||
        _turnThresholdError != null ||
        _keepRecentError != null) {
      setState(() {});
      return;
    }

    final settings = _settings;
    if (settings == null) return;

    final payload = <String, dynamic>{};
    if (settings.context.conversationHistoryInSystemPrompt !=
        _conversationHistoryInSystemPrompt) {
      payload['conversationHistoryInSystemPrompt'] =
          _conversationHistoryInSystemPrompt;
    }
    if (settings.context.autoSummarizeMode != _autoSummarizeMode) {
      payload['autoSummarizeMode'] = _autoSummarizeMode;
    }

    if (_autoSummarizeMode == 'token' &&
        _parsedThreshold != null &&
        settings.context.autoSummarizeThreshold != _parsedThreshold) {
      payload['autoSummarizeThreshold'] = _parsedThreshold;
    }

    if (_autoSummarizeMode == 'turn' &&
        _parsedTurnThreshold != null &&
        settings.context.autoSummarizeTurnThreshold != _parsedTurnThreshold) {
      payload['autoSummarizeTurnThreshold'] = _parsedTurnThreshold;
    }

    if (_parsedKeepRecent != null &&
        settings.context.autoSummarizeKeepRecent != _parsedKeepRecent) {
      payload['autoSummarizeKeepRecent'] = _parsedKeepRecent;
    }

    if (payload.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No changes to save.')),
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final apiService = context.read<InstanceProvider>().apiService;
      final result = await apiService.updateContextSettings(values: payload);
      await _loadSettings();
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agent behavior settings saved.')),
      );

      if (result.restartRequired) {
        await promptForPendingServerRestart(
          context,
          onRestarted: _loadSettings,
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(CoquiException.friendly(error).message)),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _resetSection() async {
    setState(() {
      _resetting = true;
    });

    try {
      final apiService = context.read<InstanceProvider>().apiService;
      final result = await apiService.updateContextSettings(
        reset: const [
          'conversationHistoryInSystemPrompt',
          'autoSummarizeMode',
          'autoSummarizeThreshold',
          'autoSummarizeTurnThreshold',
          'autoSummarizeKeepRecent',
        ],
      );
      await _loadSettings();
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Agent behavior settings reset to defaults.')),
      );

      if (result.restartRequired) {
        await promptForPendingServerRestart(
          context,
          onRestarted: _loadSettings,
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(CoquiException.friendly(error).message)),
      );
    } finally {
      if (mounted) {
        setState(() {
          _resetting = false;
        });
      }
    }
  }
}
