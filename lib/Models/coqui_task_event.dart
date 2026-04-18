import 'dart:convert';

class CoquiTaskEvent {
  final int? id;
  final String type;
  final Map<String, dynamic> data;
  final DateTime receivedAt;

  CoquiTaskEvent({
    required this.id,
    required this.type,
    required this.data,
    required this.receivedAt,
  });

  factory CoquiTaskEvent.fromSseBlock(String block) {
    int? id;
    String? eventType;
    String? dataLine;

    for (final line in block.split('\n')) {
      if (line.startsWith('id: ')) {
        id = int.tryParse(line.substring(4).trim());
      } else if (line.startsWith('event: ')) {
        eventType = line.substring(7).trim();
      } else if (line.startsWith('data: ')) {
        dataLine = line.substring(6);
      }
    }

    Map<String, dynamic> decoded = const {};
    if (dataLine != null && dataLine.isNotEmpty) {
      final parsed = jsonDecode(dataLine);
      if (parsed is Map<String, dynamic>) {
        decoded = parsed;
      }
    }

    return CoquiTaskEvent(
      id: id,
      type: eventType ?? 'message',
      data: decoded,
      receivedAt: DateTime.now(),
    );
  }

  bool get isConnected => type == 'connected';
  bool get isDone => type == 'done';
  bool get isTerminal =>
      type == 'completed' || type == 'failed' || type == 'cancelled';

  String get summary {
    return switch (type) {
      'agent_start' => 'Task started',
      'iteration' => 'Iteration ${data['number'] ?? '?'}',
      'reasoning' => data['content'] as String? ?? 'Reasoning',
      'text_delta' => data['content'] as String? ?? 'Streaming output',
      'tool_call' => 'Tool call: ${data['tool'] ?? 'unknown'}',
      'tool_result' => (data['success'] as bool? ?? false)
          ? 'Tool completed'
          : 'Tool returned an error',
      'tool_start' => 'Tool task started: ${data['tool_name'] ?? 'unknown'}',
      'tool_error' => data['error'] as String? ?? 'Tool failed',
      'completed' => 'Task completed',
      'failed' => data['error'] as String? ?? 'Task failed',
      'cancelled' => data['message'] as String? ?? 'Task cancelled',
      'cancel_requested' => data['message'] as String? ?? 'Cancellation requested',
      'budget_exhausted' => 'Task budget exhausted',
      'child_start' => 'Child agent: ${data['role'] ?? 'unknown'}',
      'child_end' => 'Child agent finished',
      _ => type,
    };
  }
}