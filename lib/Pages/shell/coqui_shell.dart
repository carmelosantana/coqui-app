import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:coqui_app/Pages/shell/chat/chat_column.dart';
import 'package:coqui_app/Pages/shell/loop_monitor/loop_monitor.dart';
import 'package:coqui_app/Pages/shell/persona_rail/persona_rail.dart';
import 'package:coqui_app/Pages/shell/persona_rail/persona_strip.dart';
import 'package:coqui_app/Pages/shell/session_rail/session_rail.dart';
import 'package:coqui_app/Pages/shell/shell_controller.dart';
import 'package:coqui_app/Theme/coqui_tokens.dart';

/// Responsive four-column scaffold for the Discord-style reskin.
///
/// Desktop (`maxWidth >= 1024`): a `Row` of persona rail, session rail, chat
/// column, and — when [ShellController.loopPanelOpen] — a loop monitor panel.
/// Mobile (`maxWidth < 640`): a `Scaffold` whose body is the [ChatColumn] with
/// a top [PersonaStrip] and a menu button opening a `Drawer` hosting the
/// [SessionRail]; when [ShellController.loopPanelOpen] the [LoopMonitor] takes
/// over the body full-screen instead of being a side panel.
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
            const SizedBox(
              key: ValueKey('loop-monitor'),
              width: CoquiTokens.loopPanelWidth,
              child: LoopMonitor(),
            ),
        ],
      ),
    );
  }

  Widget _buildMobile(BuildContext context) {
    final loopPanelOpen = context.watch<ShellController>().loopPanelOpen;
    return Scaffold(
      key: const ValueKey('mobile-shell'),
      backgroundColor: CoquiTokens.surface.chatBg,
      drawer: const Drawer(child: SessionRail()),
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: PersonaStrip.height,
              child: Row(
                children: [
                  Builder(
                    builder: (context) => IconButton(
                      key: const ValueKey('mobile-menu'),
                      icon: Icon(Icons.menu, color: CoquiTokens.text.high),
                      onPressed: () => Scaffold.of(context).openDrawer(),
                    ),
                  ),
                  const Expanded(
                    child: KeyedSubtree(
                      key: ValueKey('persona-strip'),
                      child: PersonaStrip(),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                key: const ValueKey('chat-column'),
                color: CoquiTokens.surface.chatBg,
                // On mobile the loop monitor takes over the body full-screen
                // instead of being a side panel; its close button
                // ([ShellController.closeLoopPanel]) restores the chat.
                child: loopPanelOpen
                    ? const KeyedSubtree(
                        key: ValueKey('loop-monitor'),
                        child: LoopMonitor(),
                      )
                    : const ChatColumn(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
