import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:coqui_app/Models/coqui_exception.dart';
import 'package:coqui_app/Providers/instance_provider.dart';

/// Well-known credential keys with descriptions, derived from the
/// supported providers in the Coqui ecosystem.
const _knownCredentials = <String, String>{
  'OPENAI_API_KEY': 'OpenAI API key — https://platform.openai.com/api-keys',
  'ANTHROPIC_API_KEY': 'Anthropic API key — https://console.anthropic.com/',
  'GEMINI_API_KEY': 'Google Gemini API key — https://aistudio.google.com/',
  'XAI_API_KEY': 'xAI (Grok) API key — https://console.x.ai/',
  'OPENROUTER_API_KEY': 'OpenRouter API key — https://openrouter.ai/keys',
  'MISTRAL_API_KEY': 'Mistral API key — https://console.mistral.ai/',
  'MINIMAX_API_KEY': 'MiniMax API key — https://www.minimaxi.com/',
};

/// Credential management UI for the active Coqui server instance.
///
/// Lists stored credential keys (values are never exposed), and provides
/// add / edit / delete operations via the server's credential API.
class CredentialsEditor extends StatefulWidget {
  const CredentialsEditor({super.key});

  @override
  State<CredentialsEditor> createState() => _CredentialsEditorState();
}

class _CredentialsEditorState extends State<CredentialsEditor>
    with AutomaticKeepAliveClientMixin {
  List<Map<String, dynamic>> _credentials = [];
  bool _isLoading = true;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCredentials());
  }

  Future<void> _loadCredentials() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final api =
          Provider.of<InstanceProvider>(context, listen: false).apiService;
      _credentials = await api.listCredentials();
      setState(() => _isLoading = false);
    } on CoquiException catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.message;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Failed to load credentials: $e';
      });
    }
  }

  Future<void> _setCredential(String key, String value) async {
    try {
      final api =
          Provider.of<InstanceProvider>(context, listen: false).apiService;
      await api.setCredential(key, value);
      _showSnackBar('Credential "$key" saved');
      await _loadCredentials();
    } on CoquiException catch (e) {
      _showSnackBar('Failed to save: ${e.message}', isError: true);
    } catch (e) {
      _showSnackBar('Failed to save: $e', isError: true);
    }
  }

  Future<void> _deleteCredential(String key) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete "$key"?'),
        content: const Text('This credential will be removed from the server.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;

    try {
      final api =
          Provider.of<InstanceProvider>(context, listen: false).apiService;
      await api.deleteCredential(key);
      _showSnackBar('Credential "$key" deleted');
      await _loadCredentials();
    } on CoquiException catch (e) {
      _showSnackBar('Failed to delete: ${e.message}', isError: true);
    } catch (e) {
      _showSnackBar('Failed to delete: $e', isError: true);
    }
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

  void _showAddCredentialDialog() {
    // Find keys that aren't already set
    final existingKeys = _credentials.map((c) => c['key'] as String).toSet();
    final suggestions =
        _knownCredentials.keys.where((k) => !existingKeys.contains(k)).toList();

    final keyController = TextEditingController();
    final valueController = TextEditingController();
    bool obscureValue = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Credential'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (suggestions.isNotEmpty) ...[
                  Text(
                    'Common keys:',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: suggestions.map((key) {
                      return ActionChip(
                        label: Text(key, style: const TextStyle(fontSize: 11)),
                        onPressed: () {
                          keyController.text = key;
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: keyController,
                  decoration: const InputDecoration(
                    labelText: 'Key name',
                    hintText: 'e.g. OPENAI_API_KEY',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.characters,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: valueController,
                  obscureText: obscureValue,
                  decoration: InputDecoration(
                    labelText: 'Value',
                    hintText: 'e.g. sk-...',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscureValue ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () {
                        setDialogState(() => obscureValue = !obscureValue);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final key = keyController.text.trim();
                final value = valueController.text;
                if (key.isEmpty || value.isEmpty) return;
                Navigator.pop(context);
                _setCredential(key, value);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditCredentialDialog(String key) {
    final valueController = TextEditingController();
    bool obscureValue = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Update "$key"'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_knownCredentials.containsKey(key))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      _knownCredentials[key]!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                TextField(
                  controller: valueController,
                  obscureText: obscureValue,
                  decoration: InputDecoration(
                    labelText: 'New value',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscureValue ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () {
                        setDialogState(() => obscureValue = !obscureValue);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final value = valueController.text;
                if (value.isEmpty) return;
                Navigator.pop(context);
                _setCredential(key, value);
              },
              child: const Text('Save'),
            ),
          ],
        ),
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
                onPressed: _loadCredentials,
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
              Expanded(
                child: Text(
                  '${_credentials.length} credential${_credentials.length == 1 ? '' : 's'} stored',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh',
                onPressed: _loadCredentials,
              ),
              const SizedBox(width: 4),
              FilledButton.icon(
                onPressed: _showAddCredentialDialog,
                icon: const Icon(Icons.add),
                label: const Text('Add'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // Credential list
        Expanded(
          child: _credentials.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.key_off,
                        size: 48,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No credentials configured',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Add API keys for your providers to get started.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _credentials.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final cred = _credentials[index];
                    final key = cred['key'] as String;
                    final isSet = cred['is_set'] as bool? ?? false;
                    final description = _knownCredentials[key];

                    return ListTile(
                      leading: Icon(
                        isSet ? Icons.check_circle : Icons.cancel,
                        color: isSet
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.error,
                      ),
                      title: Text(
                        key,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: description != null ? Text(description) : null,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit),
                            tooltip: 'Update value',
                            onPressed: () => _showEditCredentialDialog(key),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            tooltip: 'Delete',
                            onPressed: () => _deleteCredential(key),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        // Footer hint
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Text(
            'Credentials are stored in the server workspace .env file. '
            'Values are never sent back to the app.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
      ],
    );
  }
}
