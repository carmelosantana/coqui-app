import 'package:coqui_app/Models/sse_event.dart';

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

  factory AgentActivityEvent.fromSseEvent(SseEvent event) {
    return switch (event.type) {
      SseEventType.agentStart => AgentActivityEvent(
          type: AgentActivityType.start,
          label: 'Agent started',
        ),
      SseEventType.iteration => AgentActivityEvent(
          type: AgentActivityType.iteration,
          label: 'Iteration ${event.iterationNumber}',
        ),
      SseEventType.toolCall => AgentActivityEvent(
          type: AgentActivityType.toolCall,
          label: event.toolName,
          detail: _formatArguments(event.toolArguments),
        ),
      SseEventType.toolResult => AgentActivityEvent(
          type: AgentActivityType.toolResult,
          label: event.toolResultSuccess ? 'Success' : 'Error',
          detail: _truncate(event.toolResultContent, 200),
        ),
      SseEventType.childStart => AgentActivityEvent(
          type: AgentActivityType.childStart,
          label: 'Child agent: ${event.childRole}',
        ),
      SseEventType.childEnd => AgentActivityEvent(
          type: AgentActivityType.childEnd,
          label: 'Child agent finished',
        ),
      SseEventType.error => AgentActivityEvent(
          type: AgentActivityType.error,
          label: 'Error',
          detail: event.errorMessage,
        ),
      _ => AgentActivityEvent(
          type: AgentActivityType.info,
          label: event.type.name,
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
}

enum AgentActivityType {
  start,
  iteration,
  toolCall,
  toolResult,
  childStart,
  childEnd,
  error,
  info,
}
