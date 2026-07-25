import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:coqui_app/Pages/shell/persona_rail/persona_orb.dart';
import 'package:coqui_app/Pages/shell/popovers/persona_editor.dart';
import 'package:coqui_app/Pages/shell/shell_controller.dart';
import 'package:coqui_app/Providers/profile_provider.dart';
import 'package:coqui_app/Theme/coqui_tokens.dart';

/// The horizontal analog of [PersonaRail] used on the mobile layout.
///
/// A ~64px tall horizontally-scrolling strip of persona orbs sourced from
/// [ProfileProvider.profiles], followed by an add-persona button. Orb selection
/// is driven through [ShellController.selectPersona] and the active orb reflects
/// [ShellController.activePersona], exactly like the desktop rail.
///
/// Unlike [PersonaRail], this strip does NOT trigger a profiles fetch: the
/// drawer's [SessionRail] (and the desktop rail) already own fetching. It simply
/// renders whatever is currently in the provider.
class PersonaStrip extends StatelessWidget {
  const PersonaStrip({super.key});

  static const double height = 64;

  @override
  Widget build(BuildContext context) {
    final profiles = context.watch<ProfileProvider>().profiles;
    final activePersona = context.watch<ShellController>().activePersona;

    return Container(
      height: height,
      color: CoquiTokens.surface.personaRail,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            for (final profile in profiles)
              PersonaOrb(
                profile: profile,
                active: activePersona == profile.name,
                onTap: () => context
                    .read<ShellController>()
                    .selectPersona(profile.name),
              ),
            const _AddPersonaButton(key: ValueKey('add-persona')),
          ],
        ),
      ),
    );
  }
}

/// Dashed-circle add-persona button opening the [PersonaEditor].
class _AddPersonaButton extends StatelessWidget {
  const _AddPersonaButton({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: CoquiTokens.personaRailWidth,
      height: 56,
      child: Center(
        child: InkResponse(
          onTap: () => showDialog<void>(
            context: context,
            builder: (_) => const PersonaEditor(),
          ),
          radius: 28,
          child: Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: CoquiTokens.border.control),
            ),
            child: Icon(
              Icons.add,
              size: 22,
              color: CoquiTokens.brand.primaryLime,
            ),
          ),
        ),
      ),
    );
  }
}
