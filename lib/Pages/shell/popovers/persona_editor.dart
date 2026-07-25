import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:coqui_app/Models/coqui_profile.dart';
import 'package:coqui_app/Providers/profile_provider.dart';
import 'package:coqui_app/Providers/role_provider.dart';
import 'package:coqui_app/Theme/coqui_tokens.dart';
import 'package:coqui_app/Theme/coqui_typography.dart';

/// Dialog-style persona editor surfaced by the persona rail's `add-persona`
/// button (create) or a persona's edit affordance (edit).
///
/// Collects an avatar tint, name, model, allowed roles, and the persona's
/// `soul.md` text. On save it calls [ProfileProvider.createProfile] (when
/// [existing] is null) or [ProfileProvider.updateProfile].
///
/// NOTE (known limitation): the profile client API persists only
/// name/description/soul/backstory/preferences — it does NOT accept `model` or
/// `allowed_roles` as top-level fields. So model, the allowed-role selection,
/// and the avatar tint are threaded through the `preferences` map. Whether they
/// round-trip depends on backend preference handling; no client API change is
/// made here.
class PersonaEditor extends StatefulWidget {
  const PersonaEditor({super.key, this.existing});

  /// The profile being edited, or null when creating a new persona.
  final CoquiProfile? existing;

  @override
  State<PersonaEditor> createState() => _PersonaEditorState();
}

class _PersonaEditorState extends State<PersonaEditor> {
  late final TextEditingController _nameController;
  late final TextEditingController _modelController;
  late final TextEditingController _soulController;

  /// Selected avatar-tint key (a key of [CoquiTokens.personaTint]).
  late String _tint;

  /// Currently-selected allowed role names.
  final Set<String> _roles = <String>{};

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;

    _nameController = TextEditingController(
      text: existing == null
          ? ''
          : (existing.displayName.isNotEmpty
              ? existing.displayName
              : existing.name),
    );
    _modelController = TextEditingController(text: existing?.model ?? '');
    _soulController = TextEditingController(text: existing?.soul ?? '');

    // Rebuild the save button + preview avatar as the name changes.
    _nameController.addListener(_onNameChanged);

    _roles.addAll(existing?.allowedRoles ?? const <String>[]);

    // Default the tint to any persisted preference, else the first swatch.
    final tintKeys = CoquiTokens.personaTint.keys.toList(growable: false);
    final storedTint = existing?.preferences?['avatar_tint'];
    _tint = (storedTint is String && CoquiTokens.personaTint.containsKey(storedTint))
        ? storedTint
        : tintKeys.first;

    // Fetch roles exactly once, tied to initState so an empty result cannot
    // re-trigger the fetch on rebuild (mirrors the Task 5 persona-rail pattern).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final provider = context.read<RoleProvider>();
      if (provider.roles.isEmpty) {
        provider.fetchRoles();
      }
    });
  }

  @override
  void dispose() {
    _nameController.removeListener(_onNameChanged);
    _nameController.dispose();
    _modelController.dispose();
    _soulController.dispose();
    super.dispose();
  }

  void _onNameChanged() => setState(() {});

  String get _name => _nameController.text.trim();
  String get _model => _modelController.text.trim();
  String get _soul => _soulController.text;

  bool get _canSave => _name.isNotEmpty;

  /// A filesystem-friendly slug for the soul path caption.
  String get _slug {
    final source = _isEditing ? widget.existing!.name : _name;
    final slug = source
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return slug.isEmpty ? 'persona' : slug;
  }

  String get _initials {
    final trimmed = _name;
    if (trimmed.isEmpty) {
      return '?';
    }
    final parts = trimmed.split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    final letters = parts.take(2).map((p) => p[0].toUpperCase()).join();
    return letters.isEmpty ? '?' : letters;
  }

  void _toggleRole(String name) {
    setState(() {
      if (!_roles.add(name)) {
        _roles.remove(name);
      }
    });
  }

  void _save() {
    if (!_canSave) {
      return;
    }

    // model / allowed_roles / avatar_tint are threaded through preferences —
    // see the class-level known-limitation note.
    final preferences = <String, dynamic>{
      'model': _model,
      'allowed_roles': _roles.toList(),
      'avatar_tint': _tint,
    };

    final provider = context.read<ProfileProvider>();
    if (_isEditing) {
      provider.updateProfile(
        widget.existing!.name,
        soul: _soul,
        preferences: preferences,
      );
    } else {
      provider.createProfile(
        name: _name,
        description: '',
        soul: _soul,
        preferences: preferences,
      );
    }

    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final roles = context.watch<RoleProvider>().roles;
    final tint = CoquiTokens.personaTint[_tint]!;

    return Center(
      child: Material(
        type: MaterialType.transparency,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440, maxHeight: 640),
          child: Container(
            decoration: BoxDecoration(
              color: CoquiTokens.surface.card,
              border: Border.all(color: CoquiTokens.border.normal),
              borderRadius: BorderRadius.circular(CoquiTokens.radii.card),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _header(),
                const SizedBox(height: 16),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _label('AVATAR TINT'),
                        const SizedBox(height: 8),
                        _tintRow(tint),
                        const SizedBox(height: 16),
                        _label('NAME'),
                        const SizedBox(height: 8),
                        _textField(
                          key: const ValueKey('persona-name'),
                          controller: _nameController,
                          hint: 'Persona name',
                        ),
                        const SizedBox(height: 16),
                        _label('MODEL'),
                        const SizedBox(height: 8),
                        _textField(
                          key: const ValueKey('persona-model'),
                          controller: _modelController,
                          hint: 'e.g. gpt-5',
                        ),
                        const SizedBox(height: 16),
                        _label('ALLOWED ROLES'),
                        const SizedBox(height: 8),
                        _rolesWrap(roles),
                        const SizedBox(height: 16),
                        _label('SOUL'),
                        const SizedBox(height: 8),
                        _textField(
                          key: const ValueKey('persona-soul'),
                          controller: _soulController,
                          hint: 'Who is this persona?',
                          minLines: 6,
                          maxLines: 12,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'soul · prompts/$_slug/soul.md',
                          style: CoquiTypography.mono(
                            color: CoquiTokens.text.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _actions(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Row(
      children: [
        Expanded(
          child: Text(
            _isEditing ? 'Edit persona' : 'New persona',
            style: TextStyle(
              color: CoquiTokens.text.high,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        IconButton(
          key: const ValueKey('persona-editor-close'),
          onPressed: () => Navigator.of(context).maybePop(),
          icon: Icon(Icons.close, size: 18, color: CoquiTokens.text.muted),
          splashRadius: 18,
          tooltip: 'Close',
        ),
      ],
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: CoquiTypography.mono(
        color: CoquiTokens.text.faint,
        letterSpacing: 0.6,
      ),
    );
  }

  Widget _tintRow(({Color bg, Color fg}) selectedTint) {
    return Row(
      children: [
        // Live preview avatar in the selected tint.
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: selectedTint.bg,
            borderRadius: BorderRadius.circular(CoquiTokens.radii.railOrb),
          ),
          alignment: Alignment.center,
          child: Text(
            _initials,
            style: TextStyle(
              color: selectedTint.fg,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final entry in CoquiTokens.personaTint.entries)
                _TintSwatch(
                  key: ValueKey('tint-${entry.key}'),
                  tint: entry.value,
                  selected: entry.key == _tint,
                  onTap: () => setState(() => _tint = entry.key),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _rolesWrap(List roles) {
    if (roles.isEmpty) {
      return Text(
        'No roles available.',
        style: TextStyle(color: CoquiTokens.text.muted, fontSize: 12),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final role in roles)
          _RoleChip(
            key: ValueKey('role-${role.name}'),
            label: role.displayName.isNotEmpty ? role.displayName : role.name,
            selected: _roles.contains(role.name),
            onTap: () => _toggleRole(role.name),
          ),
      ],
    );
  }

  Widget _textField({
    required Key key,
    required TextEditingController controller,
    required String hint,
    int minLines = 1,
    int maxLines = 1,
  }) {
    return TextField(
      key: key,
      controller: controller,
      minLines: minLines,
      maxLines: maxLines,
      style: TextStyle(color: CoquiTokens.text.high, fontSize: 13),
      cursorColor: CoquiTokens.brand.primaryLime,
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: CoquiTokens.surface.input,
        hintText: hint,
        hintStyle: TextStyle(color: CoquiTokens.text.muted, fontSize: 13),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(CoquiTokens.radii.input),
          borderSide: BorderSide(color: CoquiTokens.border.normal),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(CoquiTokens.radii.input),
          borderSide: BorderSide(color: CoquiTokens.border.normal),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(CoquiTokens.radii.input),
          borderSide: BorderSide(color: CoquiTokens.brand.primaryLime),
        ),
      ),
    );
  }

  Widget _actions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          key: const ValueKey('persona-editor-cancel'),
          onPressed: () => Navigator.of(context).maybePop(),
          child: Text(
            'Cancel',
            style: TextStyle(color: CoquiTokens.text.muted, fontSize: 13),
          ),
        ),
        const SizedBox(width: 8),
        _SaveButton(
          key: const ValueKey('persona-editor-save'),
          label: _isEditing ? 'Save' : 'Create',
          enabled: _canSave,
          onTap: _save,
        ),
      ],
    );
  }
}

/// A single avatar-tint swatch. The selected swatch shows a lime ring.
class _TintSwatch extends StatelessWidget {
  const _TintSwatch({
    super.key,
    required this.tint,
    required this.selected,
    required this.onTap,
  });

  final ({Color bg, Color fg}) tint;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 22,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: tint.bg,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected
                ? CoquiTokens.brand.primaryLime
                : CoquiTokens.border.control,
            width: selected ? 2 : 1,
          ),
        ),
      ),
    );
  }
}

/// A toggleable allowed-role chip. Selected chips are lime-filled.
class _RoleChip extends StatelessWidget {
  const _RoleChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(CoquiTokens.radii.pill),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? CoquiTokens.brand.primaryLime
              : CoquiTokens.surface.chip,
          borderRadius: BorderRadius.circular(CoquiTokens.radii.pill),
          border: Border.all(
            color: selected
                ? CoquiTokens.brand.primaryLime
                : CoquiTokens.border.control,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color:
                selected ? CoquiTokens.brand.onPrimary : CoquiTokens.text.body,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

/// The Create/Save button. Fills with lime when [enabled]; otherwise dimmed.
class _SaveButton extends StatelessWidget {
  const _SaveButton({
    super.key,
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(CoquiTokens.radii.input),
        child: Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: enabled
                ? CoquiTokens.brand.primaryLime
                : CoquiTokens.surface.sendResting,
            borderRadius: BorderRadius.circular(CoquiTokens.radii.input),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: enabled
                  ? CoquiTokens.brand.onPrimary
                  : CoquiTokens.text.muted,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
