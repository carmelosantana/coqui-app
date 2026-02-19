import 'package:flutter/material.dart';
import 'package:coqui_app/Models/agent_activity_event.dart';
import 'package:coqui_app/Models/coqui_message.dart';

import 'chat_bubble/chat_bubble.dart';
import 'package:coqui_app/Utils/observe_size.dart';
import 'package:coqui_app/Utils/retained_position_scroll_physics.dart';

class ChatListView extends StatefulWidget {
  final List<CoquiMessage> messages;
  final bool isAwaitingReply;
  final Widget? error;
  final double? bottomPadding;
  final List<AgentActivityEvent> agentActivity;
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
                child: _AgentActivityPanel(
                  activity: widget.agentActivity,
                  turnSummary: widget.turnSummary,
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
            if (!widget.isStreaming && widget.turnSummary != null)
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

                if (index == 0) {
                  return ObserveSize(
                    key: Key(message.id),
                    onSizeChanged: _onMessageSizeChanged,
                    child: ChatBubble(
                      message: message,
                      allMessages: widget.allMessages,
                    ),
                  );
                }

                return ChatBubble(
                  message: message,
                  allMessages: widget.allMessages,
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

/// Displays real-time agent activity during streaming.
class _AgentActivityPanel extends StatelessWidget {
  final List<AgentActivityEvent> activity;
  final String? turnSummary;

  const _AgentActivityPanel({
    required this.activity,
    this.turnSummary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Agent Activity',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...activity.map((event) => _ActivityEventRow(event: event)),
          if (turnSummary != null)
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                turnSummary!,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ActivityEventRow extends StatelessWidget {
  final AgentActivityEvent event;

  const _ActivityEventRow({required this.event});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            _iconForType(event.type),
            size: 14,
            color: _colorForType(context, event.type),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              event.description,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconForType(AgentActivityType type) {
    return switch (type) {
      AgentActivityType.start => Icons.play_arrow_rounded,
      AgentActivityType.iteration => Icons.loop_rounded,
      AgentActivityType.toolCall => Icons.build_rounded,
      AgentActivityType.toolResult => Icons.check_circle_outline,
      AgentActivityType.childStart => Icons.account_tree_rounded,
      AgentActivityType.childEnd => Icons.account_tree_rounded,
      AgentActivityType.error => Icons.error_outline,
      AgentActivityType.info => Icons.info_outline,
    };
  }

  Color _colorForType(BuildContext context, AgentActivityType type) {
    return switch (type) {
      AgentActivityType.error => Theme.of(context).colorScheme.error,
      AgentActivityType.toolCall => Theme.of(context).colorScheme.tertiary,
      AgentActivityType.toolResult => Theme.of(context).colorScheme.primary,
      _ => Theme.of(context).colorScheme.onSurfaceVariant,
    };
  }
}
