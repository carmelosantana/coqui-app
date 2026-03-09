import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:coqui_app/Models/coqui_exception.dart';
import 'package:coqui_app/Providers/instance_provider.dart';

/// JSON editor for the server's openclaw.json configuration.
///
/// Fetches the raw config via `GET /api/config`, displays it in a
/// monospace text field, and saves changes via `PUT /api/config`.
class ConfigEditor extends StatefulWidget {
  const ConfigEditor({super.key});

  @override
  State<ConfigEditor> createState() => _ConfigEditorState();
}

class _ConfigEditorState extends State<ConfigEditor>
    with AutomaticKeepAliveClientMixin {
  final _controller = TextEditingController();
  bool _isLoading = true;
  bool _isSaving = false;
  bool _hasUnsavedChanges = false;
  String? _error;
  String? _configPath;

  /// The last-saved text, used to detect unsaved changes.
  String _lastSavedText = '';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadConfig());
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final changed = _controller.text != _lastSavedText;
    if (changed != _hasUnsavedChanges) {
      setState(() => _hasUnsavedChanges = changed);
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
      });
    } on CoquiException catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.message;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Failed to load configuration: $e';
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
      _showSnackBar('Save failed: $e', isError: true);
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
        // Editor
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              controller: _controller,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                height: 1.5,
              ),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(12),
                isCollapsed: true,
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
