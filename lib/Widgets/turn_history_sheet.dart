import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';

import 'package:coqui_app/Extensions/markdown_stylesheet_extension.dart';
import 'package:coqui_app/Models/agent_activity_event.dart';
import 'package:coqui_app/Models/coqui_message.dart';
import 'package:coqui_app/Models/coqui_turn.dart';
import 'package:coqui_app/Services/coqui_api_service.dart';
import 'package:coqui_app/Widgets/bottom_sheet_header.dart';
import 'package:coqui_app/Widgets/turn_inspection_widgets.dart';

class TurnHistorySheet extends StatefulWidget {
  final String sessionId;
  final CoquiTurn? highlightedTurn;

  const TurnHistorySheet({
    super.key,
    required this.sessionId,
    this.highlightedTurn,
  });

  @override
  State<TurnHistorySheet> createState() => _TurnHistorySheetState();
}

class _TurnHistorySheetState extends State<TurnHistorySheet> {
  bool _isLoading = true;
  List<CoquiTurn> _turns = const [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTurns();
  }

  Future<void> _loadTurns() async {
    final api = context.read<CoquiApiService>();
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final turns = await api.listTurns(widget.sessionId);
      if (!mounted) return;
      setState(() {
        _turns = turns.reversed.toList(growable: false);
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _openTurn(CoquiTurn turn) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _TurnDetailSheet(
        sessionId: widget.sessionId,
        initialTurn: turn,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BottomSheetHeader(title: 'Turn History'),
            const SizedBox(height: 12),
            Flexible(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? _ErrorState(message: _error!, onRetry: _loadTurns)
                      : _turns.isEmpty
                          ? const _EmptyState(label: 'No turns recorded yet.')
                          : ListView.separated(
                              shrinkWrap: true,
                              itemCount: _turns.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final turn = _turns[index];
                                final isHighlighted =
                                    widget.highlightedTurn?.id.isNotEmpty == true &&
                                        widget.highlightedTurn?.id == turn.id;
                                return ListTile(
                                  leading: CircleAvatar(
                                    radius: 16,
                                    child: Text(
                                      turn.turnNumber > 0
                                          ? '${turn.turnNumber}'
                                          : '${index + 1}',
                                    ),
                                  ),
                                  title: Text(
                                    turn.userPrompt.isNotEmpty
                                        ? turn.userPrompt
                                        : 'Turn ${turn.turnNumber}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(
                                    turn.summary.isNotEmpty
                                        ? turn.summary
                                        : (turn.error ?? 'No summary available'),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  trailing: isHighlighted
                                      ? Icon(
                                          Icons.play_circle_outline,
                                          color: Theme.of(context).colorScheme.primary,
                                        )
                                      : const Icon(Icons.chevron_right),
                                  onTap: () => _openTurn(turn),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TurnDetailSheet extends StatefulWidget {
  final String sessionId;
  final CoquiTurn initialTurn;

  const _TurnDetailSheet({
    required this.sessionId,
    required this.initialTurn,
  });

  @override
  State<_TurnDetailSheet> createState() => _TurnDetailSheetState();
}

class _TurnDetailSheetState extends State<_TurnDetailSheet> {
  bool _isLoading = true;
  CoquiTurnDetail? _detail;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    final api = context.read<CoquiApiService>();
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final detail = await api.getTurnDetail(
        widget.sessionId,
        widget.initialTurn.id,
      );
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    final activity = detail == null
        ? const <AgentActivityEvent>[]
        : detail.events
            .map(AgentActivityEvent.fromTurnEvent)
            .whereType<AgentActivityEvent>()
            .toList(growable: false);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.92,
      maxChildSize: 0.96,
      minChildSize: 0.6,
      builder: (context, scrollController) {
        return Material(
          color: Theme.of(context).colorScheme.surface,
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(16),
            children: [
              BottomSheetHeader(
                title: widget.initialTurn.turnNumber > 0
                    ? 'Turn ${widget.initialTurn.turnNumber}'
                    : 'Turn Detail',
              ),
              const SizedBox(height: 12),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                _ErrorState(message: _error!, onRetry: _loadDetail)
              else if (detail != null) ...[
                TurnSummaryCard(turn: detail.turn),
                const SizedBox(height: 8),
                TurnActivityPanel(
                  activity: activity,
                  title: 'Turn Activity',
                  emptyLabel: 'No replayable events recorded for this turn.',
                ),
                if (detail.messages.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Messages',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 8),
                  ...detail.messages.map((message) => _TurnMessageCard(message: message)),
                ],
              ],
            ],
          ),
        );
      },
    );
  }
}

class _TurnMessageCard extends StatelessWidget {
  final CoquiMessage message;

  const _TurnMessageCard({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isAssistant = message.role == CoquiMessageRole.assistant;
    final isUser = message.role == CoquiMessageRole.user;
    final backgroundColor = isAssistant
        ? colorScheme.surfaceContainerLow
        : isUser
            ? colorScheme.primaryContainer.withValues(alpha: 0.35)
            : colorScheme.surfaceContainerHighest;
    final content = message.content.trim().isEmpty ? '_No content_' : message.content;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: colorScheme.outlineVariant,
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _iconForRole(message.role),
                size: 16,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                _titleForRole(message.role),
                style: theme.textTheme.labelLarge,
              ),
            ],
          ),
          const SizedBox(height: 8),
          MarkdownBody(
            data: content,
            styleSheet: context.markdownStyleSheet,
          ),
          if (message.toolCalls != null && message.toolCalls!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              message.toolCalls!,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }

  IconData _iconForRole(CoquiMessageRole role) {
    return switch (role) {
      CoquiMessageRole.user => Icons.person_outline,
      CoquiMessageRole.assistant => Icons.smart_toy_outlined,
      CoquiMessageRole.tool => Icons.handyman_outlined,
    };
  }

  String _titleForRole(CoquiMessageRole role) {
    return switch (role) {
      CoquiMessageRole.user => 'User',
      CoquiMessageRole.assistant => 'Assistant',
      CoquiMessageRole.tool => 'Tool',
    };
  }
}

class _EmptyState extends StatelessWidget {
  final String label;

  const _EmptyState({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _ErrorState({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: onRetry,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
