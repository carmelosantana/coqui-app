import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:coqui_app/Extensions/markdown_stylesheet_extension.dart';
import 'package:coqui_app/Models/coqui_message.dart';
import 'package:url_launcher/url_launcher_string.dart';

import 'chat_bubble_actions.dart';
import 'chat_bubble_menu.dart';
import 'chat_bubble_think_block.dart';
import 'tool_call_card.dart';

class ChatBubble extends StatelessWidget {
  final CoquiMessage message;

  /// All messages in the session — used to match tool results to tool calls.
  final List<CoquiMessage> allMessages;

  const ChatBubble({
    super.key,
    required this.message,
    this.allMessages = const [],
  });

  @override
  Widget build(BuildContext context) {
    final actions = ChatBubbleActions(message);

    return ChatBubbleMenu(
      menuChildren: [
        MenuItemButton(
          onPressed: actions.handleCopy,
          leadingIcon: const Icon(Icons.copy_outlined),
          child: const Text('Copy'),
        ),
        MenuItemButton(
          onPressed: () => actions.handleSelectText(context),
          leadingIcon: const Icon(Icons.select_all_outlined),
          child: const Text('Select Text'),
        ),
      ],
      child: _ChatBubbleBody(
        message: message,
        allMessages: allMessages,
      ),
    );
  }
}

class _ChatBubbleBody extends StatelessWidget {
  final CoquiMessage message;
  final List<CoquiMessage> allMessages;

  const _ChatBubbleBody({
    required this.message,
    required this.allMessages,
  });

  @override
  Widget build(BuildContext context) {
    final hasContent = message.content.trim().isNotEmpty;
    final hasTools = message.hasToolCalls;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25.0, vertical: 15.0),
      child: Column(
        spacing: 8,
        crossAxisAlignment: bubbleAlignment,
        children: [
          // Tool call cards (if this message has tool_calls)
          if (hasTools)
            Container(
              constraints: const BoxConstraints(maxWidth: double.infinity),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _buildToolCallCards(),
              ),
            ),
          // Text content (if non-empty)
          if (hasContent)
            Container(
              padding: isSentFromUser ? const EdgeInsets.all(10.0) : null,
              constraints: BoxConstraints(
                maxWidth: isSentFromUser
                    ? MediaQuery.of(context).size.width * 0.8
                    : double.infinity,
              ),
              decoration: BoxDecoration(
                color: isSentFromUser
                    ? Theme.of(context).colorScheme.primaryContainer
                    : Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(10.0),
              ),
              child: MarkdownBody(
                data: message.content,
                selectable: true,
                softLineBreak: true,
                styleSheet: context.markdownStyleSheet.copyWith(
                  code: GoogleFonts.sourceCodePro(),
                ),
                builders: {'think': ThinkBlockBuilder()},
                extensionSet: md.ExtensionSet(
                  <md.BlockSyntax>[
                    ThinkBlockSyntax(),
                    ...md.ExtensionSet.gitHubFlavored.blockSyntaxes
                  ],
                  <md.InlineSyntax>[
                    md.EmojiSyntax(),
                    ...md.ExtensionSet.gitHubFlavored.inlineSyntaxes
                  ],
                ),
                onTapLink: (text, href, title) => launchUrlString(href!),
              ),
            ),
          Text(
            TimeOfDay.fromDateTime(message.createdAt.toLocal()).format(context),
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  /// Build a ToolCallCard for each tool call, matching results from allMessages.
  List<Widget> _buildToolCallCards() {
    final toolCalls = message.parsedToolCalls;
    return toolCalls.map((call) {
      final callId = call['id'] as String? ?? '';

      // Find the matching tool result message
      String? resultContent;
      bool? resultSuccess;

      if (callId.isNotEmpty) {
        for (final msg in allMessages) {
          if (msg.role == CoquiMessageRole.tool && msg.toolCallId == callId) {
            resultContent = msg.content;
            // Heuristic: if content starts with error indicators, mark as failure
            resultSuccess = !msg.content.toLowerCase().startsWith('error');
            break;
          }
        }
      }

      return ToolCallCard(
        toolCall: call,
        resultContent: resultContent,
        resultSuccess: resultSuccess,
      );
    }).toList();
  }

  bool get isSentFromUser => message.role == CoquiMessageRole.user;

  CrossAxisAlignment get bubbleAlignment =>
      isSentFromUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;
}
