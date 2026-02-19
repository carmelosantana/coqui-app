import 'package:flutter/material.dart';
import 'package:coqui_app/Models/coqui_role.dart';

/// A rich list tile for displaying a [CoquiRole] in selection sheets
/// and role management views.
///
/// Shows the role's display name, description, access level badge,
/// and a built-in indicator.
class RoleListTile extends StatelessWidget {
  final CoquiRole role;
  final bool selected;
  final ValueChanged<CoquiRole?>? onSelected;

  /// When true, displays as a selectable radio tile.
  /// When false, displays as a plain list tile (for management views).
  final bool selectable;

  /// Optional trailing widget (e.g. delete button for management).
  final Widget? trailing;

  const RoleListTile({
    super.key,
    required this.role,
    this.selected = false,
    this.onSelected,
    this.selectable = true,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final subtitle = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (role.description.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 6),
            child: Text(
              role.description,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        Wrap(
          spacing: 6,
          children: [
            _AccessLevelChip(accessLevel: role.accessLevel),
            if (role.isSystem)
              Chip(
                label: Text(
                  'System',
                  style: theme.textTheme.labelSmall,
                ),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                backgroundColor: colorScheme.tertiaryContainer,
              )
            else if (role.isBuiltin)
              Chip(
                label: Text(
                  'Built-in',
                  style: theme.textTheme.labelSmall,
                ),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                labelPadding: const EdgeInsets.symmetric(horizontal: 6),
              ),
          ],
        ),
      ],
    );

    if (selectable) {
      return RadioListTile<CoquiRole>(
        title: Text(role.label),
        subtitle: subtitle,
        value: role,
        isThreeLine: role.description.isNotEmpty,
      );
    }

    return ListTile(
      title: Text(role.label),
      subtitle: subtitle,
      trailing: trailing,
      isThreeLine: role.description.isNotEmpty,
      onTap: onSelected != null ? () => onSelected!(role) : null,
    );
  }
}

class _AccessLevelChip extends StatelessWidget {
  final String accessLevel;

  const _AccessLevelChip({required this.accessLevel});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (accessLevel) {
      'full' => ('Full Access', Colors.orange),
      'readonly' => ('Read Only', Colors.blue),
      'minimal' => ('Minimal', Colors.grey),
      _ => (accessLevel, Colors.grey),
    };

    return Chip(
      avatar: Icon(
        _iconFor(accessLevel),
        size: 14,
        color: color,
      ),
      label: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall,
      ),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      labelPadding: const EdgeInsets.only(right: 6),
    );
  }

  IconData _iconFor(String level) {
    return switch (level) {
      'full' => Icons.security,
      'readonly' => Icons.visibility_outlined,
      'minimal' => Icons.block_outlined,
      _ => Icons.help_outline,
    };
  }
}
