import 'package:flutter/material.dart';

import 'package:coqui_app/Models/coqui_session.dart';
import 'package:coqui_app/Theme/coqui_tokens.dart';
import 'package:coqui_app/Theme/coqui_typography.dart';

/// A single session row in the session rail.
///
/// Shows a leading glyph (`#` for an open session, an archive glyph when
/// [CoquiSession.isClosed]), the session title, and — when [live] — a small
/// online status dot. The [active] tile gets a subtle chip background and a
/// lime accent bar.
class SessionTile extends StatelessWidget {
  const SessionTile({
    super.key,
    required this.session,
    required this.active,
    required this.live,
    required this.onTap,
  });

  final CoquiSession session;
  final bool active;
  final bool live;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = session.title ?? 'Untitled';
    final accent = CoquiTokens.brand.primaryLime;
    final glyphColor = active ? accent : CoquiTokens.text.muted;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: Material(
        color: active ? CoquiTokens.surface.chip : Colors.transparent,
        borderRadius: BorderRadius.circular(CoquiTokens.radii.md),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(CoquiTokens.radii.md),
          hoverColor: CoquiTokens.surface.hover,
          child: SizedBox(
            height: 34,
            child: Row(
              children: [
                // Lime accent bar for the active tile.
                Container(
                  width: 3,
                  height: 18,
                  decoration: BoxDecoration(
                    color: active ? accent : Colors.transparent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 16,
                  child: Center(
                    child: session.isClosed
                        ? Icon(
                            Icons.archive_outlined,
                            size: 15,
                            color: glyphColor,
                          )
                        : Text(
                            '#',
                            style: CoquiTypography.mono(
                              size: 14,
                              color: glyphColor,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: active
                          ? CoquiTokens.text.high
                          : CoquiTokens.text.body,
                      fontWeight:
                          active ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
                if (live) ...[
                  const SizedBox(width: 6),
                  Container(
                    key: const ValueKey('session-live-dot'),
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: CoquiTokens.status.online,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
                const SizedBox(width: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
