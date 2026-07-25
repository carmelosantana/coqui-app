import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:coqui_app/Models/coqui_instance.dart';
import 'package:coqui_app/Providers/instance_provider.dart';
import 'package:coqui_app/Theme/coqui_tokens.dart';
import 'package:coqui_app/Theme/coqui_typography.dart';

/// A ~300-wide popover card listing the configured [CoquiInstance]s with a
/// footer "Add a server" action. Anchored above the session-rail footer by the
/// caller. Selecting a row switches the active instance and closes the popover.
class ServerSwitcher extends StatelessWidget {
  const ServerSwitcher({super.key, this.onClose});

  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<InstanceProvider>();
    final instances = provider.instances;
    final activeId = provider.activeInstance?.id;

    return Container(
      width: 300,
      decoration: BoxDecoration(
        color: CoquiTokens.surface.card,
        borderRadius: BorderRadius.circular(CoquiTokens.radii.card),
        border: Border.all(color: CoquiTokens.border.normal),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Text(
              'Servers',
              style: CoquiTypography.mono(
                size: 10,
                weight: FontWeight.w600,
                color: CoquiTokens.text.muted,
                letterSpacing: 0.6,
              ),
            ),
          ),
          for (final instance in instances)
            _ServerRow(
              key: ValueKey('server-row-${instance.id}'),
              instance: instance,
              active: instance.id == activeId,
              onTap: () {
                context.read<InstanceProvider>().setActiveInstance(instance.id);
                onClose?.call();
              },
            ),
          Divider(height: 1, thickness: 1, color: CoquiTokens.border.hairline),
          _AddServerSection(onAdded: onClose),
        ],
      ),
    );
  }
}

/// A single instance row: orb (first letter), name, mono baseUrl, status dot.
class _ServerRow extends StatelessWidget {
  const _ServerRow({
    super.key,
    required this.instance,
    required this.active,
    required this.onTap,
  });

  final CoquiInstance instance;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final letter =
        instance.name.trim().isEmpty ? '?' : instance.name.trim()[0].toUpperCase();

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: CoquiTokens.surface.chip,
                borderRadius: BorderRadius.circular(CoquiTokens.radii.sm),
              ),
              child: Text(
                letter,
                style: CoquiTypography.mono(
                  size: 12,
                  weight: FontWeight.w600,
                  color: CoquiTokens.brand.primaryLime,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    instance.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: CoquiTokens.text.high,
                    ),
                  ),
                  Text(
                    instance.baseUrl,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: CoquiTypography.mono(
                      size: 10,
                      color: CoquiTokens.text.muted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: active ? CoquiTokens.status.online : CoquiTokens.status.idle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Footer section: an "Add a server" button that reveals an inline add form.
class _AddServerSection extends StatefulWidget {
  const _AddServerSection({this.onAdded});

  final VoidCallback? onAdded;

  @override
  State<_AddServerSection> createState() => _AddServerSectionState();
}

class _AddServerSectionState extends State<_AddServerSection> {
  bool _expanded = false;
  final _nameController = TextEditingController();
  final _urlController = TextEditingController();
  final _keyController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    _keyController.dispose();
    super.dispose();
  }

  void _confirm() {
    final name = _nameController.text.trim();
    final url = _urlController.text.trim();
    final key = _keyController.text.trim();
    if (name.isEmpty || url.isEmpty) {
      return;
    }
    context.read<InstanceProvider>().addInstance(
          CoquiInstance(
            id: url,
            name: name,
            baseUrl: url,
            apiKey: key,
            apiVersion: 'v1',
            isActive: false,
          ),
        );
    _nameController.clear();
    _urlController.clear();
    _keyController.clear();
    setState(() => _expanded = false);
    widget.onAdded?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (!_expanded) {
      return InkWell(
        key: const ValueKey('server-add'),
        onTap: () => setState(() => _expanded = true),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(Icons.add, size: 16, color: CoquiTokens.brand.primaryLime),
              const SizedBox(width: 8),
              Text(
                'Add a server',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: CoquiTokens.text.body,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _field(const ValueKey('server-add-name'), _nameController, 'Name'),
          const SizedBox(height: 8),
          _field(const ValueKey('server-add-url'), _urlController, 'Base URL'),
          const SizedBox(height: 8),
          _field(const ValueKey('server-add-key'), _keyController, 'API key (optional)'),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              key: const ValueKey('server-add-confirm'),
              onPressed: _confirm,
              style: TextButton.styleFrom(
                foregroundColor: CoquiTokens.brand.onPrimary,
                backgroundColor: CoquiTokens.brand.primaryLime,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
              child: const Text('Add server', style: TextStyle(fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(Key key, TextEditingController controller, String hint) {
    return SizedBox(
      height: 34,
      child: TextField(
        key: key,
        controller: controller,
        style: TextStyle(fontSize: 12, color: CoquiTokens.text.body),
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: CoquiTokens.surface.input,
          hintText: hint,
          hintStyle: TextStyle(fontSize: 12, color: CoquiTokens.text.faint),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(CoquiTokens.radii.md),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}
