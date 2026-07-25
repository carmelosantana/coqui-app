import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:coqui_app/Pages/shell/chat/chat_column.dart';
import 'package:coqui_app/Pages/shell/persona_rail/persona_rail.dart';
import 'package:coqui_app/Pages/shell/session_rail/session_rail.dart';
import 'package:coqui_app/Pages/shell/shell_controller.dart';
import 'package:coqui_app/Theme/coqui_tokens.dart';

/// Responsive four-column scaffold for the Discord-style reskin.
///
/// Desktop (`maxWidth >= 1024`): a `Row` of persona rail, session rail, chat
/// column, and — when [ShellController.loopPanelOpen] — a loop monitor panel.
/// Mobile (`maxWidth < 640`): a `Scaffold` with the chat body, a persona strip,
/// and a `Drawer` placeholder (Task 14 fills this in).
///
/// Each column currently renders a [_Placeholder]; later tasks swap in the real
/// widgets keyed by the same `ValueKey`s used here.
class CoquiShell extends StatelessWidget {
  const CoquiShell({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 640) {
          return _buildMobile(context);
        }
        return _buildDesktop(context);
      },
    );
  }

  Widget _buildDesktop(BuildContext context) {
    final loopPanelOpen = context.watch<ShellController>().loopPanelOpen;
    return Scaffold(
      backgroundColor: CoquiTokens.surface.chatBg,
      body: Row(
        children: [
          const KeyedSubtree(
            key: ValueKey('persona-rail'),
            child: PersonaRail(),
          ),
          const KeyedSubtree(
            key: ValueKey('session-rail'),
            child: SessionRail(),
          ),
          Expanded(
            child: Container(
              key: const ValueKey('chat-column'),
              color: CoquiTokens.surface.chatBg,
              child: const ChatColumn(),
            ),
          ),
          if (loopPanelOpen)
            Container(
              key: const ValueKey('loop-monitor'),
              width: CoquiTokens.loopPanelWidth,
              color: CoquiTokens.surface.sessionRail,
              child: const _Placeholder('loop'),
            ),
        ],
      ),
    );
  }

  Widget _buildMobile(BuildContext context) {
    return Scaffold(
      key: const ValueKey('mobile-shell'),
      backgroundColor: CoquiTokens.surface.chatBg,
      drawer: const Drawer(child: _Placeholder('drawer')),
      body: Column(
        children: [
          Container(
            key: const ValueKey('persona-strip'),
            height: CoquiTokens.footerBand,
            color: CoquiTokens.surface.personaRail,
            child: const _Placeholder('persona'),
          ),
          Expanded(
            child: Container(
              key: const ValueKey('chat-column'),
              color: CoquiTokens.surface.chatBg,
              child: const _Placeholder('chat'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Centered label placeholder standing in for a real column widget until later
/// tasks replace it.
class _Placeholder extends StatelessWidget {
  const _Placeholder(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        label,
        style: TextStyle(color: CoquiTokens.text.muted),
      ),
    );
  }
}
