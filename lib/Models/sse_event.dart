import 'dart:convert';

/// Represents a parsed Server-Sent Event from the Coqui API.
///
/// SSE events follow the format:
///   `event: <type>`
///   `data: <json>`
class SseEvent {
  final SseEventType type;
  final Map<String, dynamic> data;

  SseEvent({
    required this.type,
    required this.data,
  });

  /// Parse a raw SSE block into an [SseEvent].
  ///
  /// A block looks like:
  ///   event: tool_call
  ///   data: {"id":"call_abc","tool":"list_dir","arguments":{"path":"."}}
  static SseEvent? parse(String block) {
    String? eventType;
    String? dataLine;

    for (final line in block.split('\n')) {
      if (line.startsWith('event: ')) {
        eventType = line.substring(7).trim();
      } else if (line.startsWith('data: ')) {
        dataLine = line.substring(6);
      }
    }

    if (eventType == null || dataLine == null) return null;

    try {
      final data = jsonDecode(dataLine) as Map<String, dynamic>;
      final type = SseEventType.fromString(eventType);
      return SseEvent(type: type, data: data);
    } catch (_) {
      return null;
    }
  }

  /// Parse a stream of raw SSE text into individual events.
  ///
  /// SSE blocks are separated by double newlines.
  static List<SseEvent> parseAll(String raw) {
    final events = <SseEvent>[];
    final blocks = raw.split('\n\n');

    for (final block in blocks) {
      final trimmed = block.trim();
      if (trimmed.isEmpty) continue;

      final event = parse(trimmed);
      if (event != null) events.add(event);
    }

    return events;
  }

  // Convenience data accessors

  /// Content from a 'done' or 'complete' event.
  String get content => data['content'] as String? ?? '';

  /// Incremental text delta from a 'text_delta' event.
  String get textDeltaContent => data['content'] as String? ?? '';

  /// Iteration number from an 'iteration' event.
  int get iterationNumber => data['number'] as int? ?? 0;

  /// Tool name from a 'tool_call' event.
  String get toolName => data['tool'] as String? ?? '';

  /// Tool call ID from a 'tool_call' event.
  String get toolCallId => data['id'] as String? ?? '';

  /// Tool arguments from a 'tool_call' event.
  Map<String, dynamic> get toolArguments =>
      data['arguments'] as Map<String, dynamic>? ?? {};

  /// Tool result content from a 'tool_result' event.
  String get toolResultContent => data['content'] as String? ?? '';

  /// Whether the tool result was successful.
  bool get toolResultSuccess => data['success'] as bool? ?? false;

  /// Child agent role from a 'child_start' event.
  String get childRole => data['role'] as String? ?? '';

  /// Nesting depth from child events.
  int get childDepth => data['depth'] as int? ?? 0;

  /// Error message from an 'error' event.
  String get errorMessage => data['message'] as String? ?? '';

  /// Total tokens from a 'complete' event.
  int get totalTokens => data['total_tokens'] as int? ?? 0;

  /// Session title from a 'title' event.
  String get titleText => data['title'] as String? ?? '';

  /// Warning message from a 'warning' event.
  String get warningMessage => data['message'] as String? ?? '';

  /// Turn process ID from a 'connected' event.
  String get turnProcessId => data['turn_process_id'] as String? ?? '';

  /// Duration in ms from a 'complete' event.
  int get durationMs => data['duration_ms'] as int? ?? 0;

  /// Tools used from a 'complete' event.
  List<String> get toolsUsed {
    final tools = data['tools_used'];
    if (tools is List) return tools.cast<String>();
    return [];
  }

  @override
  String toString() => 'SseEvent($type, $data)';
}

enum SseEventType {
  agentStart,
  iteration,
  reasoning,
  toolCall,
  batchStart,
  batchEnd,
  toolResult,
  childStart,
  childEnd,
  reviewStart,
  reviewEnd,
  textDelta,
  done,
  error,
  complete,
  title,
  warning,
  budgetWarning,
  summary,
  memoryExtraction,
  notification,
  loopStart,
  loopIterationStart,
  loopStageStart,
  loopStageEnd,
  loopIterationEnd,
  loopComplete,
  connected,
  unknown;

  factory SseEventType.fromString(String type) {
    return switch (type) {
      'agent_start' => SseEventType.agentStart,
      'iteration' => SseEventType.iteration,
      'reasoning' => SseEventType.reasoning,
      'tool_call' => SseEventType.toolCall,
      'batch_start' => SseEventType.batchStart,
      'batch_end' => SseEventType.batchEnd,
      'tool_result' => SseEventType.toolResult,
      'child_start' => SseEventType.childStart,
      'child_end' => SseEventType.childEnd,
      'review_start' => SseEventType.reviewStart,
      'review_end' => SseEventType.reviewEnd,
      'text_delta' => SseEventType.textDelta,
      'done' => SseEventType.done,
      'error' => SseEventType.error,
      'complete' => SseEventType.complete,
      'title' => SseEventType.title,
      'warning' => SseEventType.warning,
      'budget_warning' => SseEventType.budgetWarning,
      'summary' => SseEventType.summary,
      'memory_extraction' => SseEventType.memoryExtraction,
      'notification' => SseEventType.notification,
      'loop_start' => SseEventType.loopStart,
      'loop_iteration_start' => SseEventType.loopIterationStart,
      'loop_stage_start' => SseEventType.loopStageStart,
      'loop_stage_end' => SseEventType.loopStageEnd,
      'loop_iteration_end' => SseEventType.loopIterationEnd,
      'loop_complete' => SseEventType.loopComplete,
      'connected' => SseEventType.connected,
      _ => SseEventType.unknown,
    };
  }
}
