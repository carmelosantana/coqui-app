import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:coqui_app/Models/coqui_profile.dart';
import 'package:coqui_app/Models/coqui_session.dart';
import 'package:coqui_app/Pages/shell/session_rail/session_section.dart';
import 'package:coqui_app/Pages/shell/session_rail/session_tile.dart';
import 'package:coqui_app/Pages/shell/shell_controller.dart';
import 'package:coqui_app/Providers/chat_provider.dart';
import 'package:coqui_app/Providers/profile_provider.dart';
import 'package:coqui_app/Theme/coqui_tokens.dart';
import 'package:coqui_app/Theme/coqui_typography.dart';

/// The 250px middle rail: persona header, search field, session sections
/// (PINNED / SESSIONS / GROUP), and a 74px footer band.
///
/// Sessions come from [ChatProvider.sessions], filtered to the active persona
/// (`session.profile == ShellController.activePersona`; all sessions when no
/// persona is active). Tapping a tile opens the session in [ChatProvider] and
/// records it on [ShellController].
class SessionRail extends StatefulWidget {
  const SessionRail({super.key});

  @override
  State<SessionRail> createState() => _SessionRailState();
}

class _SessionRailState extends State<SessionRail> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatProvider>();
    final shell = context.watch<ShellController>();
    final activePersona = shell.activePersona;

    final visible = chat.sessions.where((session) {
      // Persona filter: null persona shows every session.
      if (activePersona != null && session.profile != activePersona) {
        return false;
      }
      // Client-side title filter for the search field.
      if (_query.isNotEmpty) {
        final title = (session.title ?? 'Untitled').toLowerCase();
        if (!title.contains(_query.toLowerCase())) {
          return false;
        }
      }
      return true;
    }).toList(growable: false);

    // TODO: pinning needs a backend/session field; PINNED stays empty until then
    const List<CoquiSession> pinned = [];
    final sessions = visible
        .where((s) => !s.groupEnabled && !s.isArchived)
        .toList(growable: false);
    final groups =
        visible.where((s) => s.groupEnabled).toList(growable: false);

    return Container(
      width: CoquiTokens.sessionRailWidth,
      color: CoquiTokens.surface.sessionRail,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PersonaHeader(activePersona: activePersona),
          _SearchField(
            onChanged: (value) => setState(() => _query = value),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 8),
              children: [
                SessionSection(
                  label: 'Pinned',
                  children: [for (final s in pinned) _tile(context, s, chat, shell)],
                ),
                SessionSection(
                  label: 'Sessions',
                  children: [
                    for (final s in sessions) _tile(context, s, chat, shell),
                  ],
                ),
                SessionSection(
                  label: 'Group',
                  children: [
                    for (final s in groups) _tile(context, s, chat, shell),
                  ],
                ),
              ],
            ),
          ),
          const _FooterBand(),
        ],
      ),
    );
  }

  Widget _tile(
    BuildContext context,
    CoquiSession session,
    ChatProvider chat,
    ShellController shell,
  ) {
    return SessionTile(
      key: ValueKey('session-tile-${session.id}'),
      session: session,
      active: shell.activeSessionId == session.id,
      live: chat.isSessionStreaming(session.id),
      onTap: () {
        context.read<ChatProvider>().openSession(session.id);
        context.read<ShellController>().selectSession(session.id);
      },
    );
  }
}

/// The persona header: avatar initials, display name, model (mono), and a
/// switch chevron. Falls back to a neutral prompt when no persona is active.
class _PersonaHeader extends StatelessWidget {
  const _PersonaHeader({required this.activePersona});

  final String? activePersona;

  @override
  Widget build(BuildContext context) {
    final profiles = context.watch<ProfileProvider>().profiles;
    final CoquiProfile? profile = _resolve(profiles, activePersona);

    final name = profile?.label ?? 'Select a persona';
    final model = profile?.model;
    final initials = _initials(profile?.label ?? activePersona);

    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: CoquiTokens.border.hairline),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: CoquiTokens.surface.chip,
              borderRadius: BorderRadius.circular(CoquiTokens.radii.sm),
            ),
            child: Text(
              initials,
              style: CoquiTypography.mono(
                size: 12,
                weight: FontWeight.w600,
                color: profile != null
                    ? CoquiTokens.brand.primaryLime
                    : CoquiTokens.text.muted,
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
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: profile != null
                        ? CoquiTokens.text.high
                        : CoquiTokens.text.muted,
                  ),
                ),
                if (model != null && model.isNotEmpty)
                  Text(
                    model,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: CoquiTypography.mono(
                      size: 10,
                      color: CoquiTokens.text.faint,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            key: const ValueKey('persona-switch'),
            onPressed: () {},
            visualDensity: VisualDensity.compact,
            iconSize: 18,
            icon: Icon(
              Icons.unfold_more,
              color: CoquiTokens.text.muted,
            ),
          ),
        ],
      ),
    );
  }

  CoquiProfile? _resolve(List<CoquiProfile> profiles, String? persona) {
    if (persona == null) {
      return null;
    }
    for (final profile in profiles) {
      if (profile.name == persona) {
        return profile;
      }
    }
    return null;
  }

  String _initials(String? source) {
    final value = source?.trim() ?? '';
    if (value.isEmpty) {
      return '?';
    }
    final parts = value.split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    final letters = parts.map((p) => p[0].toUpperCase()).take(2).join();
    return letters.isEmpty ? '?' : letters;
  }
}

/// A non-submitting search box that filters visible sessions by title.
class _SearchField extends StatelessWidget {
  const _SearchField({required this.onChanged});

  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      child: SizedBox(
        height: 32,
        child: TextField(
          key: const ValueKey('session-search'),
          onChanged: onChanged,
          style: TextStyle(fontSize: 12, color: CoquiTokens.text.body),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: CoquiTokens.surface.input,
            hintText: 'Search sessions',
            hintStyle: TextStyle(fontSize: 12, color: CoquiTokens.text.faint),
            prefixIcon: Icon(
              Icons.search,
              size: 16,
              color: CoquiTokens.text.muted,
            ),
            prefixIconConstraints:
                const BoxConstraints(minWidth: 32, minHeight: 32),
            contentPadding: const EdgeInsets.symmetric(vertical: 8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(CoquiTokens.radii.md),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ),
    );
  }
}

/// The 74px footer band: a server chip on the left, user avatar + settings
/// gear on the right. All controls are placeholders wired up by later tasks.
class _FooterBand extends StatelessWidget {
  const _FooterBand();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('session-footer-band'),
      height: CoquiTokens.footerBand,
      color: CoquiTokens.surface.footerWell,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          // Server chip (Task 13).
          Expanded(
            child: InkWell(
              key: const ValueKey('server-chip'),
              onTap: () {},
              borderRadius: BorderRadius.circular(CoquiTokens.radii.md),
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: CoquiTokens.surface.chip,
                  borderRadius: BorderRadius.circular(CoquiTokens.radii.md),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        gradient: CoquiTokens.brand.limeGradient,
                        borderRadius: BorderRadius.circular(CoquiTokens.radii.sm),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'coqui',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: CoquiTypography.mono(
                          size: 11,
                          weight: FontWeight.w500,
                          color: CoquiTokens.text.secondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _FooterIconButton(
            buttonKey: const ValueKey('session-footer-user'),
            child: Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: CoquiTokens.surface.chip,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.person_outline,
                size: 16,
                color: CoquiTokens.text.body,
              ),
            ),
          ),
          _FooterIconButton(
            buttonKey: const ValueKey('settings-gear'),
            child: Icon(
              Icons.settings_outlined,
              size: 18,
              color: CoquiTokens.text.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _FooterIconButton extends StatelessWidget {
  const _FooterIconButton({required this.buttonKey, required this.child});

  final Key buttonKey;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: InkResponse(
        key: buttonKey,
        onTap: () {},
        radius: 20,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: child,
        ),
      ),
    );
  }
}
