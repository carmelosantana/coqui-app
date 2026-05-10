import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

import 'package:coqui_app/Models/coqui_role.dart';
import 'package:coqui_app/Providers/chat_provider.dart';
import 'package:coqui_app/Providers/instance_provider.dart';

const _navigationModeKey = 'navigation_mode';

enum _NavigationMode { human, machine }

_NavigationMode _readNavigationMode(Box<dynamic> settingsBox) {
  final rawValue = settingsBox.get(_navigationModeKey, defaultValue: 'human');

  return rawValue == 'machine'
      ? _NavigationMode.machine
      : _NavigationMode.human;
}

class GeneralSettings extends StatefulWidget {
  const GeneralSettings({super.key});

  @override
  State<GeneralSettings> createState() => _GeneralSettingsState();
}

class _GeneralSettingsState extends State<GeneralSettings> {
  final _settingsBox = Hive.box('settings');

  List<CoquiRole>? _roles;
  bool _loadingRoles = false;

  @override
  void initState() {
    super.initState();
    _loadRoles();
  }

  Future<void> _loadRoles() async {
    final instanceProvider =
        Provider.of<InstanceProvider>(context, listen: false);
    if (instanceProvider.activeInstance == null) return;

    setState(() => _loadingRoles = true);

    try {
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      _roles = await chatProvider.fetchAvailableRoles();
    } catch (_) {
      _roles = null;
    }

    if (mounted) setState(() => _loadingRoles = false);
  }

  @override
  Widget build(BuildContext context) {
    final defaultRole = _settingsBox.get('default_role',
        defaultValue: 'orchestrator') as String;
    final navigationMode = _readNavigationMode(_settingsBox);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'General',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        ListTile(
          leading: const Icon(Icons.dashboard_customize_outlined),
          title: const Text('Navigation Mode'),
          subtitle: Text(
            navigationMode == _NavigationMode.machine
                ? 'Machine mode shows work, automation, channels, MCP, and operator tools.'
                : 'Human mode keeps Coqui focused on chat, sessions, setup, and support.',
          ),
          onTap: () => _showNavigationModePicker(navigationMode),
          trailing: const Icon(Icons.chevron_right),
        ),
        ListTile(
          leading: const Icon(Icons.smart_toy_outlined),
          title: const Text('Default Role'),
          subtitle: Text(defaultRole),
          trailing: _loadingRoles
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.chevron_right),
          onTap: _roles != null ? () => _showRolePicker(defaultRole) : null,
        ),
      ],
    );
  }

  Future<void> _showNavigationModePicker(_NavigationMode currentMode) async {
    final selected = await showModalBottomSheet<_NavigationMode>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(
                  currentMode == _NavigationMode.human
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                ),
                title: const Text('Human'),
                subtitle: const Text(
                  'Keep the app focused on conversations, setup, and support.',
                ),
                onTap: () => Navigator.pop(context, _NavigationMode.human),
              ),
              ListTile(
                leading: Icon(
                  currentMode == _NavigationMode.machine
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                ),
                title: const Text('Machine'),
                subtitle: const Text(
                  'Expose workspaces, automation, channels, MCP, and operator tools.',
                ),
                onTap: () => Navigator.pop(context, _NavigationMode.machine),
              ),
            ],
          ),
        );
      },
    );

    if (selected == null || !mounted) {
      return;
    }

    await _settingsBox.put(
      _navigationModeKey,
      selected == _NavigationMode.machine ? 'machine' : 'human',
    );
    setState(() {});
  }

  Future<void> _showRolePicker(String currentRole) async {
    if (_roles == null || _roles!.isEmpty) return;

    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        final maxHeight = MediaQuery.sizeOf(context).height * 0.75;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeight),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Default Role',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  const Divider(),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _roles!.length,
                      itemBuilder: (context, index) {
                        final role = _roles![index];
                        final isSelected = role.name == currentRole;
                        return ListTile(
                          leading: Icon(
                            isSelected
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : null,
                          ),
                          title: Text(role.label),
                          subtitle: role.description.isNotEmpty
                              ? Text(
                                  role.description,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                )
                              : null,
                          onTap: () => Navigator.pop(context, role.name),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (selected != null && mounted) {
      _settingsBox.put('default_role', selected);
      setState(() {});
    }
  }
}
