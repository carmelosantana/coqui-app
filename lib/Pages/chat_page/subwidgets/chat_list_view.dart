import 'package:flutter/material.dart';
import 'package:coqui_app/Models/agent_activity_event.dart';
import 'package:coqui_app/Models/coqui_message.dart';
import 'package:coqui_app/Models/coqui_turn.dart';
import 'package:coqui_app/Widgets/turn_inspection_widgets.dart';

import 'chat_bubble/chat_bubble.dart';
import 'package:coqui_app/Utils/observe_size.dart';
import 'package:coqui_app/Utils/retained_position_scroll_physics.dart';

class ChatListView extends StatefulWidget {
  final List<CoquiMessage> messages;
  final bool isAwaitingReply;
  final Widget? error;
  final double? bottomPadding;
  final List<AgentActivityEvent> agentActivity;
  final CoquiTurn? turnData;
  final String? turnSummary;
  final bool isStreaming;

  /// Full unfiltered message list (includes tool-role messages) for matching
  /// tool results to tool calls.
  final List<CoquiMessage> allMessages;

  const ChatListView({
    super.key,
    required this.messages,
    required this.isAwaitingReply,
    this.error,
    this.bottomPadding,
    this.agentActivity = const [],
    this.turnData,
    this.turnSummary,
    this.isStreaming = false,
    this.allMessages = const [],
  });

  @override
  State<ChatListView> createState() => _ChatListViewState();
}

class _ChatListViewState extends State<ChatListView> {
  final ScrollController _scrollController = ScrollController();
  bool _isScrollToBottomButtonVisible = false;

  final _messageSizeProxy = WidgetSizeProxy();

  @override
  void initState() {
    super.initState();

    _scrollController.addListener(() {
      _updateScrollToBottomButtonVisibility();
    });
  }

  @override
  void didUpdateWidget(covariant ChatListView oldWidget) {
    super.didUpdateWidget(oldWidget);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateScrollToBottomButtonVisibility();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        CustomScrollView(
          controller: _scrollController,
          reverse: true,
          physics: RetainedPositionScrollPhysics(
            widgetSizeProxy: _messageSizeProxy,
          ),
          slivers: [
            if (widget.bottomPadding != null)
              SliverPadding(
                padding: EdgeInsets.only(bottom: widget.bottomPadding!),
              ),
            if (widget.error != null)
              SliverToBoxAdapter(
                child: widget.error,
              ),
            // Agent activity panel (shown during streaming)
            if (widget.isStreaming && widget.agentActivity.isNotEmpty)
              SliverToBoxAdapter(
                child: TurnActivityPanel(
                  activity: widget.agentActivity,
                  isActive: true,
                ),
              ),
            if (widget.isAwaitingReply)
              SliverToBoxAdapter(
                child: ListTile(
                  title: Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          "Thinking",
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            // Turn summary (shown after streaming completes)
            if (!widget.isStreaming && widget.turnData != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: TurnSummaryCard(turn: widget.turnData!),
                ),
              ),
            if (!widget.isStreaming &&
                widget.turnData == null &&
                widget.turnSummary != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 25.0,
                    vertical: 4.0,
                  ),
                  child: Text(
                    widget.turnSummary!,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            SliverList.builder(
              key: widget.key,
              itemCount: widget.messages.length,
              itemBuilder: (context, index) {
                final message =
                    widget.messages[widget.messages.length - index - 1];

                return ObserveSize(
                  key: ValueKey(message.id),
                  onSizeChanged:
                      index == 0 ? _onMessageSizeChanged : (_, __) {},
                  child: ChatBubble(
                    key: ValueKey(message.id),
                    message: message,
                    allMessages: widget.allMessages,
                  ),
                );
              },
            ),
          ],
        ),
        if (_isScrollToBottomButtonVisible)
          IconButton(
            onPressed: _scrollToBottom,
            icon: const Icon(Icons.arrow_downward_rounded),
            style: IconButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.onInverseSurface,
            ),
          ),
      ],
    );
  }

  void _onMessageSizeChanged(Size? previousSize, Size currentSize) {
    final currentHeight = currentSize.height;
    final previousHeight = (previousSize ?? currentSize).height;
    _messageSizeProxy.deltaHeight = currentHeight - previousHeight;
  }

  void _updateScrollToBottomButtonVisibility() {
    if (_scrollController.position.pixels > 100 &&
        !_isScrollToBottomButtonVisible) {
      setState(() {
        _isScrollToBottomButtonVisible = true;
      });
    }

    if (_scrollController.position.pixels < 100 &&
        _isScrollToBottomButtonVisible) {
      setState(() {
        _isScrollToBottomButtonVisible = false;
      });
    }
  }

  void _scrollToBottom() {
    _scrollController.animateTo(
      0.0,
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
    );
  }
}
