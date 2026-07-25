import 'package:flutter/material.dart';

import 'package:coqui_app/Models/coqui_profile.dart';
import 'package:coqui_app/Theme/coqui_tokens.dart';

/// A single Discord-style avatar in the [PersonaRail].
///
/// Renders a 48px tinted avatar showing the profile's initials. Personas are
/// circular; the orchestrator (a profile with `isDefault == true`) is a
/// rounded-square ([CoquiTokens.radii.railOrb]) home button.
///
/// Active affordances differ by kind: an active persona gains a 2px lime ring,
/// while the active orchestrator shows a 4px lime bar on its left edge. A small
/// status dot ([CoquiTokens.status.online]) is a placeholder until real
/// presence lands in a later task.
class PersonaOrb extends StatelessWidget {
  const PersonaOrb({
    super.key,
    required this.profile,
    required this.active,
    required this.onTap,
  });

  final CoquiProfile profile;
  final bool active;
  final VoidCallback onTap;

  static const double _avatarSize = 48;
  static const double _slotHeight = 56;

  bool get _isOrchestrator => profile.isDefault;

  String get _initials {
    final source =
        profile.displayName.isNotEmpty ? profile.displayName : profile.name;
    final trimmed = source.trim();
    if (trimmed.isEmpty) {
      return '?';
    }
    final words =
        trimmed.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.length >= 2) {
      return (words[0][0] + words[1][0]).toUpperCase();
    }
    final word = words.first;
    return word.substring(0, word.length >= 2 ? 2 : 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final tint = CoquiTokens.personaTint[profile.name.toLowerCase()];
    final bg = tint?.bg ?? CoquiTokens.surface.card;
    final fg = tint?.fg ?? CoquiTokens.text.muted;

    final showRing = active && !_isOrchestrator;

    final avatar = Container(
      width: _avatarSize,
      height: _avatarSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        shape: _isOrchestrator ? BoxShape.rectangle : BoxShape.circle,
        borderRadius: _isOrchestrator
            ? BorderRadius.circular(CoquiTokens.radii.railOrb)
            : null,
        border: showRing
            ? Border.all(color: CoquiTokens.brand.primaryLime, width: 2)
            : null,
      ),
      child: Text(
        _initials,
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),
    );

    return Semantics(
      button: true,
      selected: active,
      label: profile.label,
      child: InkResponse(
        onTap: onTap,
        radius: _avatarSize / 2 + 4,
        child: SizedBox(
          width: CoquiTokens.personaRailWidth,
          height: _slotHeight,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (active && _isOrchestrator)
                Positioned(
                  left: 0,
                  child: Container(
                    width: 4,
                    height: 32,
                    decoration: BoxDecoration(
                      color: CoquiTokens.brand.primaryLime,
                      borderRadius: const BorderRadius.horizontal(
                        right: Radius.circular(4),
                      ),
                    ),
                  ),
                ),
              avatar,
              Positioned(
                right: 11,
                bottom: 6,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: CoquiTokens.status.online,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: CoquiTokens.surface.personaRail,
                      width: 2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
