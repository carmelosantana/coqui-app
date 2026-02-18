import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:coqui_app/Models/coqui_instance.dart';
import 'package:coqui_app/Models/request_state.dart';
import 'package:coqui_app/Providers/instance_provider.dart';
import 'package:coqui_app/Services/coqui_api_service.dart';

class InstanceSettings extends StatefulWidget {
  const InstanceSettings({super.key});

  @override
  State<InstanceSettings> createState() => _InstanceSettingsState();
}

class _InstanceSettingsState extends State<InstanceSettings> {
  @override
  Widget build(BuildContext context) {
    return Consumer<InstanceProvider>(
      builder: (context, instanceProvider, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Servers',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => _showInstanceDialog(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (instanceProvider.instances.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16.0),
                child: Center(
                  child: Text('No servers configured. Tap + to add one.'),
                ),
              )
            else
              ...instanceProvider.instances.map((instance) {
                return _InstanceTile(
                  instance: instance,
                  onEdit: () =>
                      _showInstanceDialog(context, existing: instance),
                  onDelete: () => _confirmDelete(context, instance),
                  onSetActive: () {
                    instanceProvider.setActiveInstance(instance.id);
                  },
                );
              }),
          ],
        );
      },
    );
  }

  Future<void> _showInstanceDialog(
    BuildContext context, {
    CoquiInstance? existing,
  }) async {
    final result = await showDialog<CoquiInstance>(
      context: context,
      builder: (context) => _InstanceFormDialog(existing: existing),
    );

    if (result == null) return;
    if (!mounted) return;

    final instanceProvider =
        Provider.of<InstanceProvider>(context, listen: false);

    if (existing != null) {
      await instanceProvider.updateInstance(result);
    } else {
      await instanceProvider.addInstance(result);
    }
  }

  Future<void> _confirmDelete(
      BuildContext context, CoquiInstance instance) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Server?'),
        content: Text('Remove "${instance.name}"? This cannot be undone.'),
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

    final instanceProvider =
        Provider.of<InstanceProvider>(context, listen: false);
    await instanceProvider.removeInstance(instance.id);
  }
}

class _InstanceTile extends StatelessWidget {
  final CoquiInstance instance;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onSetActive;

  const _InstanceTile({
    required this.instance,
    required this.onEdit,
    required this.onDelete,
    required this.onSetActive,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        instance.isActive ? Icons.cloud_done : Icons.cloud_outlined,
        color: instance.isActive ? Theme.of(context).colorScheme.primary : null,
      ),
      title: Text(instance.name),
      subtitle: Text(instance.baseUrl),
      trailing: PopupMenuButton<String>(
        onSelected: (value) {
          switch (value) {
            case 'activate':
              onSetActive();
            case 'edit':
              onEdit();
            case 'delete':
              onDelete();
          }
        },
        itemBuilder: (context) => [
          if (!instance.isActive)
            const PopupMenuItem(
              value: 'activate',
              child: Text('Set Active'),
            ),
          const PopupMenuItem(
            value: 'edit',
            child: Text('Edit'),
          ),
          const PopupMenuItem(
            value: 'delete',
            child: Text('Delete'),
          ),
        ],
      ),
      onTap: instance.isActive ? null : onSetActive,
    );
  }
}

class _InstanceFormDialog extends StatefulWidget {
  final CoquiInstance? existing;

  const _InstanceFormDialog({this.existing});

  @override
  State<_InstanceFormDialog> createState() => _InstanceFormDialogState();
}

class _InstanceFormDialogState extends State<_InstanceFormDialog> {
  final _nameController = TextEditingController();
  final _urlController = TextEditingController();
  final _apiKeyController = TextEditingController();

  RequestState _connectionState = RequestState.uninitialized;
  String? _connectionError;
  String? _apiKeyError;

  @override
  void initState() {
    super.initState();

    if (widget.existing != null) {
      _nameController.text = widget.existing!.name;
      _urlController.text = widget.existing!.baseUrl;
      _apiKeyController.text = widget.existing!.apiKey;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;

    return AlertDialog(
      title: Text(isEditing ? 'Edit Server' : 'Add Server'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'My Coqui Server',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _urlController,
              keyboardType: TextInputType.url,
              onChanged: (_) => setState(() {
                _connectionState = RequestState.uninitialized;
                _connectionError = null;
              }),
              decoration: InputDecoration(
                labelText: 'Server URL',
                hintText: 'http://localhost:8080',
                border: const OutlineInputBorder(),
                errorText: _connectionError,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _apiKeyController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'API Key',
                border: const OutlineInputBorder(),
                errorText: _apiKeyError,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _connectionState == RequestState.loading
                    ? null
                    : _testConnection,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Test Connection'),
                    const SizedBox(width: 10),
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _connectionStatusColor,
                      ),
                    ),
                  ],
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
        TextButton(
          onPressed: _handleSave,
          child: Text(isEditing ? 'Update' : 'Add'),
        ),
      ],
    );
  }

  Color get _connectionStatusColor {
    return switch (_connectionState) {
      RequestState.error => Colors.red,
      RequestState.loading => Colors.orange,
      RequestState.success => Colors.green,
      RequestState.uninitialized => Colors.grey,
    };
  }

  Future<void> _testConnection() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      setState(() {
        _connectionError = 'Please enter a server URL.';
        _connectionState = RequestState.error;
      });
      return;
    }

    final apiKey = _apiKeyController.text.trim();
    if (apiKey.isEmpty) {
      setState(() {
        _apiKeyError = 'API key is required.';
        _connectionState = RequestState.error;
      });
      return;
    }

    setState(() {
      _connectionState = RequestState.loading;
      _connectionError = null;
      _apiKeyError = null;
    });

    try {
      final testService = CoquiApiService(baseUrl: url, apiKey: apiKey);
      await testService.healthCheck();
      _connectionState = RequestState.success;
    } on SocketException catch (_) {
      _connectionState = RequestState.error;
      _connectionError = 'Could not connect to server.';
    } catch (e) {
      _connectionState = RequestState.error;
      _connectionError = 'Connection failed: $e';
    }

    if (mounted) setState(() {});
  }

  void _handleSave() {
    final name = _nameController.text.trim();
    final url = _urlController.text.trim();
    final apiKey = _apiKeyController.text.trim();

    if (name.isEmpty || url.isEmpty) return;

    if (apiKey.isEmpty) {
      setState(() {
        _apiKeyError = 'API key is required.';
      });
      return;
    }

    final instance = CoquiInstance(
      id: widget.existing?.id ?? const Uuid().v4(),
      name: name,
      baseUrl: url,
      apiKey: apiKey.isEmpty ? '' : apiKey,
      isActive: widget.existing?.isActive ?? false,
    );

    Navigator.pop(context, instance);
  }
}
