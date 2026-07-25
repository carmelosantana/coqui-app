import 'package:flutter/material.dart';

import 'package:coqui_app/Theme/coqui_tokens.dart';
import 'package:coqui_app/Theme/coqui_typography.dart';

/// A labelled group of session tiles.
///
/// Renders a mono, uppercase section [label] followed by [children]. When
/// [children] is empty the whole section renders nothing (a
/// [SizedBox.shrink]) — this is how the PINNED section stays hidden until a
/// backend pin field exists.
class SessionSection extends StatelessWidget {
  const SessionSection({
    super.key,
    required this.label,
    required this.children,
  });

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: Text(
            label.toUpperCase(),
            style: CoquiTypography.mono(
              size: 10,
              weight: FontWeight.w600,
              color: CoquiTokens.text.faint,
              letterSpacing: 0.8,
            ),
          ),
        ),
        ...children,
      ],
    );
  }
}
