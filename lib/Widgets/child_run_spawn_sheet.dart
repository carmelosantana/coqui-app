import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:coqui_app/Models/coqui_role.dart';
import 'package:coqui_app/Providers/role_provider.dart';
import 'package:coqui_app/Services/coqui_api_service.dart';
import 'package:coqui_app/Widgets/selection_bottom_sheet.dart';

/// A small form for spawning a child agent run under a session.
///
/// The CAP `POST /sessions/{id}/child-runs` contract takes a **role** (the
/// persona is inherited server-side) plus a prompt. The role is chosen with the
/// shared [showSelectionBottomSheet] + [RoleProvider] picker; on submit the
/// form calls [CoquiApiService.spawnChildRun] and invokes [onSpawned] so the
/// caller can refresh its listing.
class ChildRunSpawnSheet extends StatefulWidget {
  final String sessionId;
  final VoidCallback? onSpawned;

  const ChildRunSpawnSheet({
    super.key,
    required this.sessionId,
    this.onSpawned,
  });

  @override
  State<ChildRunSpawnSheet> createState() => _ChildRunSpawnSheetState();
}

class _ChildRunSpawnSheetState extends State<ChildRunSpawnSheet> {
  final TextEditingController _promptController = TextEditingController();

  CoquiRole? _selectedRole;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final roleProvider = context.read<RoleProvider>();
      if (roleProvider.roles.isEmpty && !roleProvider.isLoading) {
        roleProvider.fetchRoles();
      }
    });
  }

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  Future<void> _pickRole() async {
    final roleProvider = context.read<RoleProvider>();

    final selectedRole = await showSelectionBottomSheet<CoquiRole>(
      context: context,
      header: const Text('Child Run Role'),
      fetchItems: () async {
        if (roleProvider.roles.isEmpty) {
          await roleProvider.fetchRoles();
        }
        return roleProvider.roles;
      },
      currentSelection: _selectedRole,
      itemBuilder: (role, selected, onSelected) {
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            selected
                ? Icons.radio_button_checked
                : Icons.radio_button_unchecked,
          ),
          onTap: () => onSelected(role),
          title: Text(role.label),
          subtitle: role.description.isNotEmpty ? Text(role.description) : null,
        );
      },
    );

    if (!mounted || selectedRole == null) return;
    setState(() => _selectedRole = selectedRole);
  }

  Future<void> _submit() async {
    final role = _selectedRole;
    final prompt = _promptController.text.trim();

    if (role == null) {
      setState(() => _error = 'Choose a role for the child run.');
      return;
    }
    if (prompt.isEmpty) {
      setState(() => _error = 'A prompt is required.');
      return;
    }

    final api = context.read<CoquiApiService>();
    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await api.spawnChildRun(
        widget.sessionId,
        role: role.name,
        prompt: prompt,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e.toString();
      });
      return;
    }

    if (!mounted) return;
    widget.onSpawned?.call();
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      minimum: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Spawn Child Run', style: theme.textTheme.titleMedium),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            key: const ValueKey('spawn-role-picker'),
            onPressed: _submitting ? null : _pickRole,
            icon: const Icon(Icons.badge_outlined),
            label: Align(
              alignment: Alignment.centerLeft,
              child: Text(_selectedRole?.label ?? 'Select role'),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('spawn-prompt-field'),
            controller: _promptController,
            enabled: !_submitting,
            minLines: 3,
            maxLines: 6,
            decoration: const InputDecoration(
              labelText: 'Prompt',
              hintText: 'What should the child run do?',
              border: OutlineInputBorder(),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            key: const ValueKey('spawn-submit'),
            onPressed: _submitting ? null : _submit,
            icon: _submitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.play_arrow),
            label: const Text('Spawn'),
          ),
        ],
      ),
    );
  }
}
