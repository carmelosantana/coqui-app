import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:coqui_app/Models/coqui_role.dart';
import 'package:coqui_app/Providers/chat_provider.dart';
import 'package:coqui_app/Providers/instance_provider.dart';
import 'package:coqui_app/Services/coqui_api_service.dart';
import 'package:coqui_app/Widgets/bottom_sheet_header.dart';
import 'package:coqui_app/Widgets/role_list_tile.dart';
import 'package:coqui_app/Widgets/selection_bottom_sheet.dart';
import 'package:provider/provider.dart';
import 'package:responsive_framework/responsive_framework.dart';

class ChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  const ChatAppBar({super.key});

  @override
  Widget build(BuildContext context) {
    final chatProvider = Provider.of<ChatProvider>(context);
    final instanceProvider = Provider.of<InstanceProvider>(context);

    return AppBar(
      title: Column(
        children: [
          // Server selector dropdown
          _ServerDropdown(instanceProvider: instanceProvider),
          if (chatProvider.currentSession != null)
            InkWell(
              onTap: () {
                _handleRoleSelectionButton(context);
              },
              customBorder: const StadiumBorder(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                  chatProvider.currentSession!.modelRole,
                  style: GoogleFonts.kodeMono(
                    textStyle: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
              ),
            ),
        ],
      ),
      actions: [
        if (chatProvider.currentSession != null)
          IconButton(
            icon: const Icon(Icons.tune),
            onPressed: () {
              _handleConfigureButton(context);
            },
          ),
      ],
      forceMaterialTransparency: !ResponsiveBreakpoints.of(context).isMobile,
    );
  }

  Future<void> _handleRoleSelectionButton(BuildContext context) async {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);

    await showSelectionBottomSheet<CoquiRole>(
      context: context,
      header: const BottomSheetHeader(title: "Available Roles"),
      fetchItems: () async {
        return await chatProvider.fetchAvailableRoles();
      },
      currentSelection: null,
      itemBuilder: (role, selected, onSelected) {
        return RoleListTile(
          role: role,
          selected: selected,
          onSelected: onSelected,
        );
      },
    );
  }

  Future<void> _handleConfigureButton(BuildContext context) async {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);

    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          minimum: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const BottomSheetHeader(title: 'Session Options'),
              const Divider(),
              if (chatProvider.lastTurnSummary != null)
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('Last Turn'),
                  subtitle: Text(chatProvider.lastTurnSummary!),
                ),
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Rename Session'),
                onTap: () => Navigator.pop(context, 'rename'),
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Delete Session'),
                textColor: Theme.of(context).colorScheme.error,
                iconColor: Theme.of(context).colorScheme.error,
                onTap: () => Navigator.pop(context, 'delete'),
              ),
            ],
          ),
        );
      },
    );

    if (action == 'delete') {
      await chatProvider.deleteCurrentSession();
    } else if (action == 'rename') {
      if (context.mounted) {
        await _showRenameDialog(context, chatProvider);
      }
    }
  }

  Future<void> _showRenameDialog(
    BuildContext context,
    ChatProvider chatProvider,
  ) async {
    final session = chatProvider.currentSession;
    if (session == null) return;

    final controller = TextEditingController(text: session.title ?? '');
    final newTitle = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Session'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Session title',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (value) => Navigator.pop(context, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newTitle != null && newTitle.isNotEmpty) {
      await chatProvider.renameSession(session.id, newTitle);
    }
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

/// Dropdown for quick server switching directly in the app bar.
class _ServerDropdown extends StatefulWidget {
  final InstanceProvider instanceProvider;

  const _ServerDropdown({required this.instanceProvider});

  @override
  State<_ServerDropdown> createState() => _ServerDropdownState();
}

class _ServerDropdownState extends State<_ServerDropdown> {
  /// null = unknown/checking, true = reachable, false = unreachable
  bool? _isHealthy;
  String? _lastCheckedInstanceId;

  @override
  void initState() {
    super.initState();
    _checkHealth();
  }

  @override
  void didUpdateWidget(covariant _ServerDropdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    final activeId = widget.instanceProvider.activeInstance?.id;
    if (activeId != _lastCheckedInstanceId) {
      _checkHealth();
    }
  }

  Future<void> _checkHealth() async {
    final active = widget.instanceProvider.activeInstance;
    if (active == null) {
      setState(() {
        _isHealthy = null;
        _lastCheckedInstanceId = null;
      });
      return;
    }

    _lastCheckedInstanceId = active.id;
    setState(() => _isHealthy = null); // checking

    final testService = CoquiApiService(
      baseUrl: active.baseUrl,
      apiKey: active.apiKey,
    );

    try {
      await testService.healthCheck();
      if (mounted && _lastCheckedInstanceId == active.id) {
        setState(() => _isHealthy = true);
      }
    } catch (_) {
      if (mounted && _lastCheckedInstanceId == active.id) {
        setState(() => _isHealthy = false);
      }
    }
  }

  Color _statusColor(BuildContext context) {
    return switch (_isHealthy) {
      true => Colors.green,
      false => Theme.of(context).colorScheme.error,
      null => Theme.of(context).colorScheme.onSurfaceVariant,
    };
  }

  @override
  Widget build(BuildContext context) {
    final instances = widget.instanceProvider.instances;
    final active = widget.instanceProvider.activeInstance;

    if (instances.isEmpty) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.dns_outlined,
            size: 16,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 4),
          Text(
            'No Server',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      );
    }

    Widget statusDot = Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _statusColor(context),
      ),
    );

    if (instances.length == 1) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          statusDot,
          const SizedBox(width: 6),
          Icon(
            Icons.dns,
            size: 16,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 4),
          Text(
            active?.name ?? instances.first.name,
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ],
      );
    }

    return PopupMenuButton<String>(
      tooltip: 'Switch server',
      offset: const Offset(0, 40),
      onSelected: (id) {
        widget.instanceProvider.setActiveInstance(id);
      },
      itemBuilder: (context) => instances.map((instance) {
        final isActive = instance.id == active?.id;
        return PopupMenuItem<String>(
          value: instance.id,
          child: Row(
            children: [
              Icon(
                isActive ? Icons.dns : Icons.dns_outlined,
                size: 18,
                color: isActive ? Theme.of(context).colorScheme.primary : null,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  instance.name,
                  style: isActive
                      ? TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        )
                      : null,
                ),
              ),
              if (isActive)
                Icon(
                  Icons.check,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
            ],
          ),
        );
      }).toList(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          statusDot,
          const SizedBox(width: 6),
          Icon(
            Icons.dns,
            size: 16,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 4),
          Text(
            active?.name ?? 'Select Server',
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const Icon(Icons.arrow_drop_down, size: 18),
        ],
      ),
    );
  }
}
