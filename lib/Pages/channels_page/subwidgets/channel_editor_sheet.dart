import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:coqui_app/Models/coqui_channel.dart';
import 'package:coqui_app/Providers/channel_provider.dart';
import 'package:coqui_app/Services/coqui_api_service.dart';
import 'package:coqui_app/Widgets/profile_picker_dialog.dart';

class ChannelEditorSheet extends StatefulWidget {
  final CoquiChannel? channel;

  const ChannelEditorSheet({
    super.key,
    this.channel,
  });

  @override
  State<ChannelEditorSheet> createState() => _ChannelEditorSheetState();
}

class _ChannelEditorSheetState extends State<ChannelEditorSheet> {
  final _nameController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _accountController = TextEditingController();
  final _binaryController = TextEditingController();
  final _allowedScopesController = TextEditingController();
  final _settingsJsonController = TextEditingController();
  final _securityJsonController = TextEditingController();

  String _selectedDriver = 'signal';
  String? _selectedProfile;
  bool _enabled = true;
  bool _ignoreAttachments = true;
  bool _sendReadReceipts = false;
  bool _linkRequired = true;

  bool get _isEditing => widget.channel != null;

  @override
  void initState() {
    super.initState();
    final channel = widget.channel;
    if (channel != null) {
      _selectedDriver = channel.driver;
      _enabled = channel.enabled;
      _selectedProfile = channel.defaultProfile;
      _nameController.text = channel.name;
      _displayNameController.text = channel.displayName;
      _allowedScopesController.text = channel.allowedScopes.join('\n');
      _accountController.text = (channel.settings['account'] as String?) ?? '';
      _binaryController.text = (channel.settings['binary'] as String?) ?? 'signal-cli';
      _ignoreAttachments = channel.settings['ignoreAttachments'] as bool? ?? true;
      _sendReadReceipts = channel.settings['sendReadReceipts'] as bool? ?? false;
      _linkRequired = channel.security['linkRequired'] as bool? ?? true;
      _settingsJsonController.text = const JsonEncoder.withIndent('  ')
          .convert(channel.settings);
      _securityJsonController.text = const JsonEncoder.withIndent('  ')
          .convert(channel.security);
    } else {
      _binaryController.text = 'signal-cli';
      _settingsJsonController.text = '{\n  \n}';
      _securityJsonController.text = '{\n  \n}';
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChannelProvider>().fetchDrivers();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _displayNameController.dispose();
    _accountController.dispose();
    _binaryController.dispose();
    _allowedScopesController.dispose();
    _settingsJsonController.dispose();
    _securityJsonController.dispose();
    super.dispose();
  }

  Future<void> _pickProfile() async {
    final selected = await showProfilePickerDialog(
      context: context,
      title: 'Default Profile',
      fetchProfiles: () => context.read<CoquiApiService>().getProfiles(),
      initialValue: _selectedProfile,
    );
    if (!mounted || selected == null) return;
    setState(() {
      _selectedProfile = selected.isEmpty ? null : selected;
    });
  }

  Future<void> _save() async {
    final provider = context.read<ChannelProvider>();
    final name = _nameController.text.trim();
    final displayName = _displayNameController.text.trim();
    final allowedScopes = _allowedScopesController.text
        .split(RegExp(r'[\n,]'))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();

    if (name.isEmpty) {
      _showSnack('Please enter a channel name');
      return;
    }

    Map<String, dynamic> settings;
    Map<String, dynamic> security;

    if (_selectedDriver == 'signal') {
      final account = _accountController.text.trim();
      if (account.isEmpty) {
        _showSnack('Signal channels require an attached account number');
        return;
      }
      settings = {
        'account': account,
        'binary': _binaryController.text.trim().isEmpty
            ? 'signal-cli'
            : _binaryController.text.trim(),
        'ignoreAttachments': _ignoreAttachments,
        'sendReadReceipts': _sendReadReceipts,
        'receiveMode': 'on-start',
      };
      security = {'linkRequired': _linkRequired};
    } else {
      try {
        settings = _decodeJsonObject(_settingsJsonController.text);
        security = _decodeJsonObject(_securityJsonController.text);
      } catch (e) {
        _showSnack(e.toString());
        return;
      }
    }

    final result = _isEditing
        ? await provider.updateChannel(
            widget.channel!.id,
            enabled: _enabled,
            displayName: displayName.isEmpty ? null : displayName,
            defaultProfile: _selectedProfile,
            settings: settings,
            allowedScopes: allowedScopes,
            security: security,
          )
        : await provider.createChannel(
            name: name,
            driver: _selectedDriver,
            enabled: _enabled,
            displayName: displayName.isEmpty ? null : displayName,
            defaultProfile: _selectedProfile,
            settings: settings,
            allowedScopes: allowedScopes,
            security: security,
          );

    if (!mounted) return;
    if (result != null) {
      Navigator.pop(context, result);
    } else {
      _showSnack(provider.error ?? 'Unable to save channel');
      provider.clearError();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.78,
        minChildSize: 0.55,
        maxChildSize: 0.94,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurfaceVariant
                        .withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Row(
                  children: [
                    Text(
                      _isEditing ? 'Edit Channel' : 'New Channel',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    Consumer<ChannelProvider>(
                      builder: (context, provider, _) {
                        final busy = _isEditing
                            ? provider.isMutating(widget.channel!.id)
                            : provider.isLoading;
                        return FilledButton(
                          onPressed: busy ? null : _save,
                          child: busy
                              ? SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: theme.colorScheme.onPrimary,
                                  ),
                                )
                              : Text(_isEditing ? 'Save' : 'Create'),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  children: [
                    _SectionLabel(label: 'Basics'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _nameController,
                      enabled: !_isEditing,
                      decoration: const InputDecoration(
                        labelText: 'Internal name',
                        hintText: 'signal-primary',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _displayNameController,
                      decoration: const InputDecoration(
                        labelText: 'Display name',
                        hintText: 'Signal Primary',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Consumer<ChannelProvider>(
                      builder: (context, provider, _) {
                        final drivers = provider.drivers;
                        final selected = drivers.any(
                          (driver) => driver.name == _selectedDriver,
                        )
                            ? _selectedDriver
                            : (drivers.isNotEmpty ? drivers.first.name : _selectedDriver);
                        return InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Driver',
                          ),
                          child: DropdownButton<String>(
                            value: selected,
                            isExpanded: true,
                            underline: const SizedBox.shrink(),
                            items: drivers
                                .map(
                                  (driver) => DropdownMenuItem<String>(
                                    value: driver.name,
                                    child: Text(driver.displayName),
                                  ),
                                )
                                .toList(),
                            onChanged: _isEditing
                                ? null
                                : (value) {
                                    if (value != null) {
                                      setState(() => _selectedDriver = value);
                                    }
                                  },
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: _enabled,
                      onChanged: (value) => setState(() => _enabled = value),
                      title: const Text('Enabled'),
                      subtitle: const Text('Start and reconcile this channel in the API runtime'),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Default Profile'),
                      subtitle: Text(_selectedProfile ?? 'No profile selected'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _pickProfile,
                    ),
                    const SizedBox(height: 16),
                    _DriverSpecificForm(
                      selectedDriver: _selectedDriver,
                      accountController: _accountController,
                      binaryController: _binaryController,
                      allowedScopesController: _allowedScopesController,
                      settingsJsonController: _settingsJsonController,
                      securityJsonController: _securityJsonController,
                      ignoreAttachments: _ignoreAttachments,
                      sendReadReceipts: _sendReadReceipts,
                      linkRequired: _linkRequired,
                      onIgnoreAttachmentsChanged: (value) =>
                          setState(() => _ignoreAttachments = value),
                      onSendReadReceiptsChanged: (value) =>
                          setState(() => _sendReadReceipts = value),
                      onLinkRequiredChanged: (value) =>
                          setState(() => _linkRequired = value),
                    ),
                    const SizedBox(height: 36),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Map<String, dynamic> _decodeJsonObject(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return {};
    final decoded = jsonDecode(trimmed);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) {
      return decoded.map((key, value) => MapEntry(key.toString(), value));
    }
    throw Exception('Advanced settings must be a JSON object');
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _DriverSpecificForm extends StatelessWidget {
  final String selectedDriver;
  final TextEditingController accountController;
  final TextEditingController binaryController;
  final TextEditingController allowedScopesController;
  final TextEditingController settingsJsonController;
  final TextEditingController securityJsonController;
  final bool ignoreAttachments;
  final bool sendReadReceipts;
  final bool linkRequired;
  final ValueChanged<bool> onIgnoreAttachmentsChanged;
  final ValueChanged<bool> onSendReadReceiptsChanged;
  final ValueChanged<bool> onLinkRequiredChanged;

  const _DriverSpecificForm({
    required this.selectedDriver,
    required this.accountController,
    required this.binaryController,
    required this.allowedScopesController,
    required this.settingsJsonController,
    required this.securityJsonController,
    required this.ignoreAttachments,
    required this.sendReadReceipts,
    required this.linkRequired,
    required this.onIgnoreAttachmentsChanged,
    required this.onSendReadReceiptsChanged,
    required this.onLinkRequiredChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (selectedDriver == 'signal') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel(label: 'Signal Setup'),
          const SizedBox(height: 8),
          _HintCard(
            title: 'Recommended Signal path',
            body:
                'Signal is the first fully integrated channel runtime. Coqui runs it only under the API server or launcher, not REPL-only mode. Install signal-cli and Java 25+ on the same machine as the Coqui API server before testing.',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: accountController,
            decoration: const InputDecoration(
              labelText: 'Attached account',
              hintText: '+15551234567',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: binaryController,
            decoration: const InputDecoration(
              labelText: 'signal-cli binary',
              hintText: 'signal-cli',
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            enabled: false,
            initialValue: 'on-start',
            decoration: const InputDecoration(
              labelText: 'Receive mode',
              hintText: 'on-start',
            ),
          ),
          const SizedBox(height: 12),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: ignoreAttachments,
            onChanged: onIgnoreAttachmentsChanged,
            title: const Text('Ignore attachments'),
            subtitle: const Text('Recommended for the current Signal first pass'),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: sendReadReceipts,
            onChanged: onSendReadReceiptsChanged,
            title: const Text('Send read receipts'),
            subtitle: const Text('Off by default for a quieter operator setup'),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: linkRequired,
            onChanged: onLinkRequiredChanged,
            title: const Text('Require linked senders'),
            subtitle: const Text('Recommended so unknown senders do not automatically open sessions'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: allowedScopesController,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Allowed scopes (advanced)',
              hintText: 'One group ID per line',
            ),
          ),
        ],
      );
    }

    final scaffolded = selectedDriver == 'telegram' || selectedDriver == 'discord';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(label: '${_titleForDriver(selectedDriver)} Setup'),
        const SizedBox(height: 8),
        _HintCard(
          title: scaffolded ? 'Advanced configuration' : 'Generic configuration',
          body: scaffolded
              ? '${_titleForDriver(selectedDriver)} is registered in Coqui today, but its runtime is still scaffolded. You can save configuration and monitor placeholder health, but this does not yet provide end-to-end transport behavior.'
              : 'This driver uses the generic advanced editor. Enter the settings and security objects exactly as the backend expects.',
        ),
        const SizedBox(height: 12),
        TextField(
          controller: settingsJsonController,
          minLines: 6,
          maxLines: 10,
          decoration: const InputDecoration(
            labelText: 'Settings JSON',
            hintText: '{\n  \n}',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: securityJsonController,
          minLines: 4,
          maxLines: 8,
          decoration: const InputDecoration(
            labelText: 'Security JSON',
            hintText: '{\n  \n}',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: allowedScopesController,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Allowed scopes',
            hintText: 'Comma or newline separated values',
          ),
        ),
      ],
    );
  }

  String _titleForDriver(String driver) {
    return switch (driver) {
      'telegram' => 'Telegram',
      'discord' => 'Discord',
      _ => driver,
    };
  }
}

class _HintCard extends StatelessWidget {
  final String title;
  final String body;

  const _HintCard({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(body, style: Theme.of(context).textTheme.bodySmall),
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
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
    );
  }
}