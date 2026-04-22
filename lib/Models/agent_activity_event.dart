import 'package:coqui_app/Models/sse_event.dart';
import 'package:coqui_app/Models/coqui_turn.dart';

/// Represents a single agent activity event for UI rendering.
///
/// These events are collected during an SSE stream and displayed
/// in the agent activity panel to show real-time tool usage,
/// iterations, and child agent activity.
class AgentActivityEvent {
  final AgentActivityType type;
  final String label;
  final String? detail;
  final DateTime timestamp;

  AgentActivityEvent({
    required this.type,
    required this.label,
    this.detail,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// User-friendly description combining label and detail.
  String get description {
    if (detail != null && detail!.isNotEmpty) {
      return '$label: $detail';
    }
    return label;
  }

  static AgentActivityEvent? fromSseEvent(SseEvent event) {
    return _fromTypeAndData(
      event.type,
      event.data,
      timestamp: DateTime.now(),
    );
  }

  static AgentActivityEvent? fromTurnEvent(CoquiTurnEvent event) {
    return _fromTypeAndData(
      SseEventType.fromString(event.eventType),
      event.data,
      timestamp: event.createdAt,
    );
  }

  static AgentActivityEvent? _fromTypeAndData(
    SseEventType type,
    Map<String, dynamic> data, {
    DateTime? timestamp,
  }) {
    return switch (type) {
      SseEventType.agentStart => AgentActivityEvent(
          type: AgentActivityType.start,
          label: 'Agent started',
          timestamp: timestamp,
        ),
      SseEventType.iteration => AgentActivityEvent(
          type: AgentActivityType.iteration,
          label: 'Iteration ${data['number'] as int? ?? 0}',
          timestamp: timestamp,
        ),
      SseEventType.toolCall => AgentActivityEvent(
          type: AgentActivityType.toolCall,
          label: data['tool'] as String? ?? 'Tool call',
          detail: _formatArguments(
            (data['arguments'] as Map?)?.cast<String, dynamic>() ?? const {},
          ),
          timestamp: timestamp,
        ),
      SseEventType.batchStart => AgentActivityEvent(
          type: AgentActivityType.info,
          label: 'Parallel tools started',
          detail: _countDetail(data['count']),
          timestamp: timestamp,
        ),
      SseEventType.batchEnd => AgentActivityEvent(
          type: AgentActivityType.info,
          label: 'Parallel tools finished',
          detail: _countDetail(data['count']),
          timestamp: timestamp,
        ),
      SseEventType.toolResult => AgentActivityEvent(
          type: AgentActivityType.toolResult,
          label: (data['success'] as bool? ?? false) ? 'Success' : 'Error',
          detail: _truncate(data['content'] as String? ?? '', 200),
          timestamp: timestamp,
        ),
      SseEventType.childStart => AgentActivityEvent(
          type: AgentActivityType.childStart,
          label: 'Child agent: ${data['role'] as String? ?? 'child'}',
          timestamp: timestamp,
        ),
      SseEventType.childEnd => AgentActivityEvent(
          type: AgentActivityType.childEnd,
          label: 'Child agent finished',
          timestamp: timestamp,
        ),
      SseEventType.reviewStart => AgentActivityEvent(
          type: AgentActivityType.info,
          label: 'Review round ${data['round'] as int? ?? 1}',
          detail: 'Max ${data['max_rounds'] as int? ?? 1} rounds',
          timestamp: timestamp,
        ),
      SseEventType.reviewEnd => AgentActivityEvent(
          type: AgentActivityType.info,
          label: (data['approved'] as bool? ?? false)
              ? 'Review approved'
              : 'Review completed',
          detail: data['verdict'] as String?,
          timestamp: timestamp,
        ),
      SseEventType.error => AgentActivityEvent(
          type: AgentActivityType.error,
          label: 'Error',
          detail: data['message'] as String? ?? '',
          timestamp: timestamp,
        ),
      SseEventType.warning => AgentActivityEvent(
          type: AgentActivityType.warning,
          label: 'Warning',
          detail: data['message'] as String? ?? '',
          timestamp: timestamp,
        ),
      SseEventType.budgetWarning => AgentActivityEvent(
          type: AgentActivityType.warning,
          label: 'Budget warning',
          detail: _budgetWarningDetail(data),
          timestamp: timestamp,
        ),
      SseEventType.summary => AgentActivityEvent(
          type: AgentActivityType.info,
          label: 'Conversation summarized',
          detail: _summaryDetail(data),
          timestamp: timestamp,
        ),
      SseEventType.memoryExtraction => AgentActivityEvent(
          type: AgentActivityType.info,
          label: 'Memory extracted',
          detail: _memoryDetail(data),
          timestamp: timestamp,
        ),
      SseEventType.notification => AgentActivityEvent(
          type: AgentActivityType.info,
          label: 'Notification',
          detail: (data['title'] as String?) ?? (data['kind'] as String?),
          timestamp: timestamp,
        ),
      SseEventType.loopStart => AgentActivityEvent(
          type: AgentActivityType.info,
          label: 'Loop started',
          detail: data['loop_id'] as String?,
          timestamp: timestamp,
        ),
      SseEventType.loopIterationStart => AgentActivityEvent(
          type: AgentActivityType.info,
          label: 'Loop iteration ${data['iteration'] as int? ?? 0}',
          detail: data['loop_id'] as String?,
          timestamp: timestamp,
        ),
      SseEventType.loopStageStart => AgentActivityEvent(
          type: AgentActivityType.info,
          label: 'Loop stage started',
          detail: data['role'] as String? ?? data['loop_id'] as String?,
          timestamp: timestamp,
        ),
      SseEventType.loopStageEnd => AgentActivityEvent(
          type: AgentActivityType.info,
          label: 'Loop stage finished',
          detail: data['role'] as String? ?? data['loop_id'] as String?,
          timestamp: timestamp,
        ),
      SseEventType.loopIterationEnd => AgentActivityEvent(
          type: AgentActivityType.info,
          label: 'Loop iteration finished',
          detail: 'Iteration ${data['iteration'] as int? ?? 0}',
          timestamp: timestamp,
        ),
      SseEventType.loopComplete => AgentActivityEvent(
          type: AgentActivityType.info,
          label: 'Loop completed',
          detail: data['status'] as String? ?? data['loop_id'] as String?,
          timestamp: timestamp,
        ),
      SseEventType.title => AgentActivityEvent(
          type: AgentActivityType.info,
          label: 'Title generated',
          detail: data['title'] as String?,
          timestamp: timestamp,
        ),
      SseEventType.textDelta || SseEventType.reasoning => null,
      SseEventType.complete ||
      SseEventType.connected ||
      SseEventType.unknown => null,
      _ => AgentActivityEvent(
          type: AgentActivityType.info,
          label: type.name,
          timestamp: timestamp,
        ),
    };
  }

  static String _formatArguments(Map<String, dynamic> args) {
    if (args.isEmpty) return '';
    return args.entries
        .map((e) => '${e.key}: ${_truncate(e.value.toString(), 80)}')
        .join(', ');
  }

  static String _truncate(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }

  static String? _countDetail(Object? value) {
    final count = value as int?;
    if (count == null || count <= 0) return null;
    return '$count task${count == 1 ? '' : 's'}';
  }

  static String _budgetWarningDetail(Map<String, dynamic> data) {
    final usage = (data['usage_percent'] as num?)?.toDouble();
    final threshold = (data['threshold_percent'] as num?)?.toDouble();
    if (usage == null) return 'Near context limit';
    if (threshold == null) return '${usage.toStringAsFixed(1)}% used';
    return '${usage.toStringAsFixed(1)}% used (threshold ${threshold.toStringAsFixed(1)}%)';
  }

  static String _summaryDetail(Map<String, dynamic> data) {
    final messages = data['messages_summarized'] as int?;
    final tokens = data['tokens_saved'] as int?;
    final parts = <String>[];
    if (messages != null && messages > 0) parts.add('$messages messages');
    if (tokens != null && tokens > 0) parts.add('$tokens tokens saved');
    return parts.isEmpty ? 'Summary complete' : parts.join(' · ');
  }

  static String _memoryDetail(Map<String, dynamic> data) {
    final count = data['memories_saved'] as int?;
    if (count == null || count <= 0) return 'Memory extraction complete';
    return '$count memor${count == 1 ? 'y' : 'ies'} saved';
  }
}

enum AgentActivityType {
  start,
  iteration,
  toolCall,
  toolResult,
  childStart,
  childEnd,
  error,
  warning,
  info,
}
