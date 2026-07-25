import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:coqui_app/Pages/shell/persona_rail/persona_orb.dart';
import 'package:coqui_app/Pages/shell/popovers/persona_editor.dart';
import 'package:coqui_app/Pages/shell/shell_controller.dart';
import 'package:coqui_app/Providers/profile_provider.dart';
import 'package:coqui_app/Theme/coqui_tokens.dart';

/// The horizontal analog of `PersonaRail` used on the mobile layout.
///
/// A ~64px tall horizontally-scrolling strip of persona orbs sourced from
/// [ProfileProvider.profiles], followed by a dashed add-persona button. Orb
/// selection is driven through [ShellController.selectPersona] and the active
/// orb reflects [ShellController.activePersona], exactly like the desktop rail.
///
/// Because the desktop `PersonaRail` (which owns the profiles fetch) never
/// mounts on mobile, this strip is the fetch owner there: it kicks off a
/// one-time [ProfileProvider.fetchProfiles] from `initState` when the list is
/// empty — mirroring `PersonaRail`'s proven pattern.
class PersonaStrip extends StatefulWidget {
  const PersonaStrip({super.key});

  static const double height = 64;

  @override
  State<PersonaStrip> createState() => _PersonaStripState();
}

class _PersonaStripState extends State<PersonaStrip> {
  @override
  void initState() {
    super.initState();
    // Fetch personas exactly once for the life of this State. Because this is
    // tied to initState (not build), an empty/error result cannot re-trigger it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final provider = context.read<ProfileProvider>();
      if (provider.profiles.isEmpty) {
        provider.fetchProfiles();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final profiles = context.watch<ProfileProvider>().profiles;
    final activePersona = context.watch<ShellController>().activePersona;

    return Container(
      height: PersonaStrip.height,
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

/// Dashed-circle add-persona button opening the [PersonaEditor], matching the
/// desktop rail's add button.
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
