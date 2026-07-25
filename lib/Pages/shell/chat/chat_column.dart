import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:coqui_app/Pages/chat_page/subwidgets/chat_error.dart';
import 'package:coqui_app/Pages/chat_page/subwidgets/chat_list_view.dart';
import 'package:coqui_app/Pages/shell/chat/composer.dart';
import 'package:coqui_app/Providers/chat_provider.dart';
import 'package:coqui_app/Theme/coqui_tokens.dart';
import 'package:coqui_app/Theme/coqui_typography.dart';

/// Discord-style chat column: a 52px channel header, the scrolling message
/// list (reusing the existing [ChatListView] chat bubbles), and a composer
/// slot mounted by Task 8.
class ChatColumn extends StatelessWidget {
  const ChatColumn({super.key});

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatProvider>();
    final session = chat.currentSession;

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
