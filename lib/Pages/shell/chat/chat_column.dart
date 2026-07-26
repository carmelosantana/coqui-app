import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:coqui_app/Models/coqui_loop.dart';
import 'package:coqui_app/Pages/chat_page/subwidgets/chat_error.dart';
import 'package:coqui_app/Pages/chat_page/subwidgets/chat_list_view.dart';
import 'package:coqui_app/Pages/shell/chat/composer.dart';
import 'package:coqui_app/Pages/shell/chat/loop_card.dart';
import 'package:coqui_app/Providers/chat_provider.dart';
import 'package:coqui_app/Providers/loop_provider.dart';
import 'package:coqui_app/Theme/coqui_tokens.dart';
import 'package:coqui_app/Theme/coqui_typography.dart';

/// Discord-style chat column: a 52px channel header, an optional strip of
/// inline [LoopCard]s for the current session, the scrolling message list
/// (reusing the existing [ChatListView] chat bubbles), and the composer.
///
/// Loops and their definitions are fetched exactly once on first mount
/// (mirroring the persona-rail initState pattern) so a user can launch → see →
/// monitor a loop from the chat surface.
class ChatColumn extends StatefulWidget {
  const ChatColumn({super.key});

  @override
  State<ChatColumn> createState() => _ChatColumnState();
}

class _ChatColumnState extends State<ChatColumn> {
  /// Minimal fallback used when a loop references a definition we haven't
  /// loaded yet. [LoopCard] handles the empty name/roles gracefully.
  static const CoquiLoopDefinition _emptyDefinition = CoquiLoopDefinition(
    name: '',
    description: '',
    parameters: [],
    roles: [],
    termination: {},
  );

  @override
  void initState() {
    super.initState();
    // Fetch loops + definitions exactly once for the life of this State.
    // Tied to initState (not build) so an empty/error result cannot re-trigger.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final loops = context.read<LoopProvider>();
      loops.fetchLoops();
      loops.fetchDefinitions();
    });
  }

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatProvider>();
    final session = chat.currentSession;

    final loopProvider = context.watch<LoopProvider>();
    final sessionLoops = session == null
        ? const <CoquiLoop>[]
        : loopProvider.loops
            .where((l) => l.sessionId == session.id)
            .toList(growable: false);

    return Container(
      color: CoquiTokens.surface.chatBg,
      child: Column(
        children: [
          _ChannelHeader(
            title: session?.title ?? 'No session',
            subtitle: session == null
                ? null
                : '${session.model} · ${session.modelRole}',
          ),
          if (sessionLoops.isNotEmpty)
            _LoopStrip(loops: sessionLoops, provider: loopProvider),
          Expanded(
            child: session == null
                ? const _EmptyState()
                : ChatListView(
                    key: ValueKey('chat-list-${session.id}'),
                    messages: chat.displayMessages,
                    allMessages: chat.messages,
                    isAwaitingReply: chat.isCurrentSessionThinking,
                    isStreaming: chat.isCurrentSessionStreaming,
                    agentActivity: chat.currentTurnActivity,
                    turnData: chat.lastCompletedTurn,
                    error: chat.currentSessionError != null
                        ? ChatError(
                            error: chat.currentSessionError!,
                            onRetry: chat.retryLastPrompt,
                          )
                        : null,
                  ),
          ),
          const KeyedSubtree(
            key: ValueKey('composer-slot'),
            child: Composer(),
          ),
        ],
      ),
    );
  }
}

/// Horizontal strip of inline [LoopCard]s pinned above the message list. Each
/// card resolves its definition from [LoopProvider.definitions] (falling back
/// to an empty definition) and opens the loop monitor on tap.
class _LoopStrip extends StatelessWidget {
  const _LoopStrip({required this.loops, required this.provider});

  final List<CoquiLoop> loops;
  final LoopProvider provider;

  CoquiLoopDefinition _definitionFor(CoquiLoop loop) {
    return provider.definitions.firstWhere(
      (d) => d.name == loop.definitionName,
      orElse: () => _ChatColumnState._emptyDefinition,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('loop-strip'),
      height: 120,
      decoration: BoxDecoration(
        color: CoquiTokens.surface.chatBg,
        border: Border(
          bottom: BorderSide(color: CoquiTokens.border.hairline),
        ),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: loops.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final loop = loops[index];
          return SizedBox(
            width: 320,
            child: LoopCard(
              key: ValueKey('loop-card-${loop.id}'),
              loop: loop,
              definition: _definitionFor(loop),
            ),
          );
        },
      ),
    );
  }
}

/// 52px channel header showing the session title and a mono model/role
/// subtitle, with a hairline bottom border.
class _ChannelHeader extends StatelessWidget {
  const _ChannelHeader({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('channel-header'),
      height: CoquiTokens.channelHeader,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: CoquiTokens.surface.chatBg,
        border: Border(
          bottom: BorderSide(color: CoquiTokens.border.hairline),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: CoquiTokens.text.high,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: CoquiTypography.mono(color: CoquiTokens.text.muted),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Centered placeholder shown when no session is selected.
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Select or start a session',
        style: TextStyle(color: CoquiTokens.text.muted),
      ),
    );
  }
}
