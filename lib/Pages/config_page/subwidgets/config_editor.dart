import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:coqui_app/Models/coqui_exception.dart';
import 'package:coqui_app/Providers/instance_provider.dart';
import 'platform_code_editor.dart';

/// JSON editor for the server's openclaw.json configuration.
///
/// Fetches the raw config via `GET /api/config`, displays it in a
/// full-featured code editor with JSON syntax highlighting and line numbers,
/// and saves changes via `PUT /api/config`. Real-time validation runs via
/// `POST /api/config/validate` with a 600ms debounce after each edit.
class ConfigEditor extends StatefulWidget {
  const ConfigEditor({super.key});

  @override
  State<ConfigEditor> createState() => _ConfigEditorState();
}

class _ConfigEditorState extends State<ConfigEditor>
    with AutomaticKeepAliveClientMixin {
  late final ConfigEditorController _controller;

  bool _isLoading = true;
  bool _isSaving = false;
  bool _hasUnsavedChanges = false;
  String? _error;
  String? _configPath;

  /// The last-saved text, used to detect unsaved changes.
  String _lastSavedText = '';

  // Validation state
  bool _isValidating = false;
  bool? _isConfigValid; // null = not yet validated
  List<String> _validationErrors = const [];
  Timer? _validationDebounce;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _controller = ConfigEditorController();
    _controller.addListener(_onTextChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadConfig());
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _validationDebounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final changed = _controller.text != _lastSavedText;
    if (changed != _hasUnsavedChanges) {
      setState(() => _hasUnsavedChanges = changed);
    }
    // Clear stale validation state immediately on any keystroke
    if (_isConfigValid != null || _validationErrors.isNotEmpty) {
      setState(() {
        _isConfigValid = null;
        _validationErrors = const [];
      });
    }
    _scheduleValidation();
  }

  void _scheduleValidation() {
    _validationDebounce?.cancel();
    _validationDebounce =
        Timer(const Duration(milliseconds: 600), _validateConfig);
  }

  Future<void> _validateConfig() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    // Fast-fail for broken JSON — skip network call
    try {
      jsonDecode(text);
    } on FormatException catch (e) {
      setState(() {
        _isValidating = false;
        _isConfigValid = false;
        _validationErrors = ['Invalid JSON: ${e.message}'];
      });
      return;
    }

    setState(() {
      _isValidating = true;
      _isConfigValid = null;
      _validationErrors = const [];
    });

    try {
      final api =
          Provider.of<InstanceProvider>(context, listen: false).apiService;
      final result = await api.validateConfig(text);
      if (!mounted) return;
      setState(() {
        _isValidating = false;
        _isConfigValid = result.valid;
        _validationErrors = result.errors;
      });
    } catch (_) {
      // Validation is best-effort; network/auth failures are silently swallowed
      if (!mounted) return;
      setState(() {
        _isValidating = false;
        _isConfigValid = null;
      });
    }
  }

  Future<void> _loadConfig() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final api =
          Provider.of<InstanceProvider>(context, listen: false).apiService;
      final result = await api.getConfig();

      // The API may return either an envelope {path, config, raw} or the
      // config object directly — handle both gracefully.
      String raw;
      if (result.containsKey('raw')) {
        raw = result['raw'] as String? ?? '';
        _configPath = result['path'] as String?;
      } else {
        raw = const JsonEncoder.withIndent('    ').convert(result);
        _configPath = null;
      }

      _controller.text = raw;
      _lastSavedText = raw;
      setState(() {
        _isLoading = false;
        _hasUnsavedChanges = false;
        _isConfigValid = null;
        _validationErrors = const [];
      });
    } on CoquiException catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.message;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = CoquiException.friendly(e).message;
      });
    }
  }

  Future<void> _saveConfig() async {
    // Client-side JSON validation
    final text = _controller.text;
    try {
      jsonDecode(text);
    } on FormatException catch (e) {
      _showSnackBar('Invalid JSON: ${e.message}', isError: true);
      return;
    }

    setState(() => _isSaving = true);

    try {
      final api =
          Provider.of<InstanceProvider>(context, listen: false).apiService;
      await api.updateConfig(text);
      _lastSavedText = text;
      setState(() {
        _isSaving = false;
        _hasUnsavedChanges = false;
      });
      _showSnackBar('Configuration saved');
    } on CoquiException catch (e) {
      setState(() => _isSaving = false);
      _showSnackBar('Save failed: ${e.message}', isError: true);
    } catch (e) {
      setState(() => _isSaving = false);
      _showSnackBar('Save failed: ${CoquiException.friendly(e).message}',
          isError: true);
    }
  }

  Future<void> _refreshConfig() async {
    if (_hasUnsavedChanges) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Discard changes?'),
          content: const Text(
            'You have unsaved changes. Refreshing will discard them.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Discard'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    await _loadConfig();
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? Theme.of(context).colorScheme.error
            : Theme.of(context).colorScheme.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
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
                _error!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _loadConfig,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // Toolbar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              if (_configPath != null)
                Expanded(
                  child: Text(
                    _configPath!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                )
              else
                const Spacer(),
              // Validation status indicator
              if (_isValidating)
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else if (_isConfigValid == true)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Icon(
                    Icons.check_circle_outline,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                )
              else if (_isConfigValid == false)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Icon(
                    Icons.error_outline,
                    size: 16,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              if (_hasUnsavedChanges)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    'Unsaved changes',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh from server',
                onPressed: _refreshConfig,
              ),
              const SizedBox(width: 4),
              FilledButton.icon(
                onPressed:
                    _hasUnsavedChanges && !_isSaving ? _saveConfig : null,
                icon: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: const Text('Save'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // Code editor
        Expanded(
          child: PlatformCodeEditor(controller: _controller),
        ),
        // Validation error panel
        if (_validationErrors.isNotEmpty)
          Container(
            constraints: const BoxConstraints(maxHeight: 140),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .errorContainer
                  .withValues(alpha: 0.15),
              border: Border(
                top: BorderSide(
                  color: Theme.of(context)
                      .colorScheme
                      .error
                      .withValues(alpha: 0.4),
                ),
              ),
            ),
            child: ListView.builder(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              shrinkWrap: true,
              itemCount: _validationErrors.length,
              itemBuilder: (context, i) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.circle,
                      size: 6,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _validationErrors[i],
                        style:
                            Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.error,
                                  fontFamily: 'GeistMono',
                                ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        // Footer hint
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Text(
            'Changes are applied automatically before the next message.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
      ],
    );
  }
}
