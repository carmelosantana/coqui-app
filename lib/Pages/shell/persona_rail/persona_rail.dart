import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:coqui_app/Models/coqui_profile.dart';
import 'package:coqui_app/Pages/shell/persona_rail/persona_orb.dart';
import 'package:coqui_app/Pages/shell/shell_controller.dart';
import 'package:coqui_app/Providers/profile_provider.dart';
import 'package:coqui_app/Theme/coqui_tokens.dart';

/// The leftmost 74px Discord-style rail.
///
/// Top to bottom: a server-switcher orb placeholder (Task 13), a divider, the
/// pinned orchestrator home orb (the `isDefault` profile), a divider, the
/// remaining persona orbs (scrollable), and a dashed add-persona button
/// (Task 12). Orb selection is driven through [ShellController.selectPersona]
/// and the active orb reflects [ShellController.activePersona].
///
/// Profiles come from [ProfileProvider]; the rail kicks off a one-time
/// [ProfileProvider.fetchProfiles] when the list is empty and no fetch is
/// already in flight.
class PersonaRail extends StatelessWidget {
  const PersonaRail({super.key});

  @override
  Widget build(BuildContext context) {
    final profileProvider = context.watch<ProfileProvider>();
    final profiles = profileProvider.profiles;

    if (profiles.isEmpty && !profileProvider.isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final provider = context.read<ProfileProvider>();
        // Guard against overlapping fetches: only fire when idle and empty.
        if (provider.profiles.isEmpty && !provider.isLoading) {
          provider.fetchProfiles();
        }
      });
    }

    final orchestrator = _firstOrchestrator(profiles);
    final personas =
        profiles.where((p) => !identical(p, orchestrator)).toList(growable: false);
    final activePersona = context.watch<ShellController>().activePersona;

    return Container(
      width: CoquiTokens.personaRailWidth,
      color: CoquiTokens.surface.personaRail,
      child: Column(
        children: [
          const SizedBox(height: 12),
          _ServerOrb(key: const ValueKey('server-orb')),
          const _RailDivider(),
          if (orchestrator != null) ...[
            PersonaOrb(
              profile: orchestrator,
              active: activePersona == orchestrator.name,
              onTap: () => context
                  .read<ShellController>()
                  .selectPersona(orchestrator.name),
            ),
            const _RailDivider(),
          ],
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  for (final profile in personas)
                    PersonaOrb(
                      profile: profile,
                      active: activePersona == profile.name,
                      onTap: () => context
                          .read<ShellController>()
                          .selectPersona(profile.name),
                    ),
                ],
              ),
            ),
          ),
          const _AddPersonaButton(key: ValueKey('add-persona')),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  CoquiProfile? _firstOrchestrator(List<CoquiProfile> profiles) {
    for (final profile in profiles) {
      if (profile.isDefault) {
        return profile;
      }
    }
    return null;
  }
}

/// Placeholder server-switcher orb. Task 13 wires it to `InstanceProvider`.
class _ServerOrb extends StatelessWidget {
  const _ServerOrb({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: CoquiTokens.personaRailWidth,
      height: 48,
      child: Center(
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: CoquiTokens.brand.limeGradient,
            borderRadius: BorderRadius.circular(CoquiTokens.radii.railOrb),
          ),
          alignment: Alignment.center,
          child: Icon(
            Icons.hub_outlined,
            size: 22,
            color: CoquiTokens.brand.onPrimary,
          ),
        ),
      ),
    );
  }
}

/// Dashed-circle add-persona button. Task 12 wires it to the persona editor.
class _AddPersonaButton extends StatelessWidget {
  const _AddPersonaButton({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: CoquiTokens.personaRailWidth,
      height: 56,
      child: Center(
        child: InkResponse(
          onTap: () {},
          radius: 28,
          child: CustomPaint(
            painter: _DashedCirclePainter(color: CoquiTokens.border.control),
            child: SizedBox(
              width: 48,
              height: 48,
              child: Center(
                child: Icon(
                  Icons.add,
                  size: 22,
                  color: CoquiTokens.brand.primaryLime,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Paints a dashed circular stroke sized to fill its bounds.
class _DashedCirclePainter extends CustomPainter {
  const _DashedCirclePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final radius = (size.shortestSide - paint.strokeWidth) / 2;
    final center = Offset(size.width / 2, size.height / 2);
    const dashCount = 24;
    const sweep = 3.141592653589793 * 2 / dashCount;
    const gapRatio = 0.45;
    for (var i = 0; i < dashCount; i++) {
      final start = sweep * i;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep * (1 - gapRatio),
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DashedCirclePainter oldDelegate) =>
      oldDelegate.color != color;
}

/// A short horizontal hairline separating rail sections.
class _RailDivider extends StatelessWidget {
  const _RailDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: CoquiTokens.border.normal,
        borderRadius: BorderRadius.circular(1),
      ),
    );
  }
}
