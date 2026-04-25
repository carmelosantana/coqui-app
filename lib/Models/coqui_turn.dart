import 'dart:convert';

import 'package:coqui_app/Models/coqui_message.dart';

/// Represents a single prompt-response cycle within a session.
///
/// Turns record detailed metadata: token usage, duration, tools used,
/// and child agent counts.
class CoquiTurn {
  final String id;
  final String sessionId;
  final int turnNumber;
  final String userPrompt;
  final String responseText;
  final String content;
  final String model;
  final int promptTokens;
  final int completionTokens;
  final int totalTokens;
  final int iterations;
  final int durationMs;
  final List<String> toolsUsed;
  final int childAgentCount;
  final String? turnProcessId;
  final bool restartRequested;
  final bool iterationLimitReached;
  final bool budgetExhausted;
  final CoquiTurnContextUsage? contextUsage;
  final List<CoquiTurnFileEdit> fileEdits;
  final String? reviewFeedback;
  final bool? reviewApproved;
  final CoquiTurnBackgroundTasks? backgroundTasks;
  final String? error;
  final DateTime createdAt;
  final DateTime? completedAt;

  CoquiTurn({
    required this.id,
    required this.sessionId,
    required this.turnNumber,
    required this.userPrompt,
    required this.responseText,
    required this.content,
    required this.model,
    this.promptTokens = 0,
    this.completionTokens = 0,
    this.totalTokens = 0,
    this.iterations = 0,
    this.durationMs = 0,
    this.toolsUsed = const [],
    this.childAgentCount = 0,
    this.turnProcessId,
    this.restartRequested = false,
    this.iterationLimitReached = false,
    this.budgetExhausted = false,
    this.contextUsage,
    this.fileEdits = const [],
    this.reviewFeedback,
    this.reviewApproved,
    this.backgroundTasks,
    this.error,
    required this.createdAt,
    this.completedAt,
  });

  factory CoquiTurn.fromJson(Map<String, dynamic> json) {
    List<String> tools = [];
    if (json['tools_used'] is String) {
      final decoded = jsonDecode(json['tools_used'] as String);
      if (decoded is List) {
        tools = decoded.cast<String>();
      }
    } else if (json['tools_used'] is List) {
      tools = (json['tools_used'] as List).cast<String>();
    }

    final fileEdits = (json['file_edits'] as List? ?? [])
        .whereType<Map>()
        .map((edit) => CoquiTurnFileEdit.fromJson(edit.cast<String, dynamic>()))
        .toList();

    return CoquiTurn(
      id: json['id'] as String? ?? '',
      sessionId: json['session_id'] as String? ?? '',
      turnNumber: json['turn_number'] as int? ?? 0,
      userPrompt: json['user_prompt'] as String? ?? '',
      responseText: json['response_text'] as String? ?? '',
      content: json['content'] as String? ?? json['response_text'] as String? ?? '',
      model: json['model'] as String? ?? '',
      promptTokens: json['prompt_tokens'] as int? ?? 0,
      completionTokens: json['completion_tokens'] as int? ?? 0,
      totalTokens: json['total_tokens'] as int? ?? 0,
      iterations: json['iterations'] as int? ?? 0,
      durationMs: json['duration_ms'] as int? ?? 0,
      toolsUsed: tools,
      childAgentCount: json['child_agent_count'] as int? ?? 0,
      turnProcessId: json['turn_process_id'] as String?,
      restartRequested: json['restart_requested'] as bool? ?? false,
      iterationLimitReached: json['iteration_limit_reached'] as bool? ?? false,
      budgetExhausted: json['budget_exhausted'] as bool? ?? false,
      contextUsage: json['context_usage'] is Map<String, dynamic>
          ? CoquiTurnContextUsage.fromJson(json['context_usage'] as Map<String, dynamic>)
          : null,
      fileEdits: fileEdits,
      reviewFeedback: json['review_feedback'] as String?,
      reviewApproved: json['review_approved'] as bool?,
      backgroundTasks: json['background_tasks'] is Map<String, dynamic>
          ? CoquiTurnBackgroundTasks.fromJson(json['background_tasks'] as Map<String, dynamic>)
          : null,
      error: json['error'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
    );
  }

  /// Duration as a human-readable string.
  String get durationFormatted {
    if (durationMs < 1000) return '${durationMs}ms';
    final seconds = (durationMs / 1000).toStringAsFixed(1);
    return '${seconds}s';
  }

  /// Summary line for the turn metadata.
  String get summary {
    final parts = <String>[];
    if (iterations > 0) parts.add('$iterations iteration${iterations > 1 ? 's' : ''}');
    if (toolsUsed.isNotEmpty) parts.add('${toolsUsed.length} tool${toolsUsed.length > 1 ? 's' : ''}');
    if (childAgentCount > 0) parts.add('$childAgentCount child${childAgentCount > 1 ? 'ren' : ''}');
    if (totalTokens > 0) parts.add('$totalTokens tokens');
    if (durationMs > 0) parts.add(durationFormatted);
    return parts.join(' · ');
  }
}

class CoquiTurnContextUsage {
  final int maxTokens;
  final int reservedTokens;
  final int usedTokens;
  final double usagePercent;
  final int availableTokens;
  final int effectiveBudget;
  final Map<String, int> breakdown;

  const CoquiTurnContextUsage({
    required this.maxTokens,
    required this.reservedTokens,
    required this.usedTokens,
    required this.usagePercent,
    required this.availableTokens,
    required this.effectiveBudget,
    required this.breakdown,
  });

  factory CoquiTurnContextUsage.fromJson(Map<String, dynamic> json) {
    final rawBreakdown = (json['breakdown'] as Map?)?.cast<String, dynamic>() ?? const {};

    return CoquiTurnContextUsage(
      maxTokens: json['max_tokens'] as int? ?? 0,
      reservedTokens: json['reserved_tokens'] as int? ?? 0,
      usedTokens: json['used_tokens'] as int? ?? 0,
      usagePercent: (json['usage_percent'] as num?)?.toDouble() ?? 0,
      availableTokens: json['available_tokens'] as int? ?? 0,
      effectiveBudget: json['effective_budget'] as int? ?? 0,
      breakdown: rawBreakdown.map((key, value) => MapEntry(key, value as int? ?? 0)),
    );
  }
}

class CoquiTurnFileEdit {
  final String filePath;
  final String operation;

  const CoquiTurnFileEdit({
    required this.filePath,
    required this.operation,
  });

  factory CoquiTurnFileEdit.fromJson(Map<String, dynamic> json) {
    return CoquiTurnFileEdit(
      filePath: json['file_path'] as String? ?? '',
      operation: json['operation'] as String? ?? '',
    );
  }
}

class CoquiTurnBackgroundTasks {
  final List<CoquiTurnBackgroundTaskEntry> agents;
  final List<CoquiTurnBackgroundTaskEntry> tools;
  final int totalCount;

  const CoquiTurnBackgroundTasks({
    required this.agents,
    required this.tools,
    required this.totalCount,
  });

  factory CoquiTurnBackgroundTasks.fromJson(Map<String, dynamic> json) {
    final agents = (json['agents'] as List? ?? [])
        .whereType<Map>()
        .map((entry) => CoquiTurnBackgroundTaskEntry.fromJson(entry.cast<String, dynamic>()))
        .toList();
    final tools = (json['tools'] as List? ?? [])
        .whereType<Map>()
        .map((entry) => CoquiTurnBackgroundTaskEntry.fromJson(entry.cast<String, dynamic>()))
        .toList();

    return CoquiTurnBackgroundTasks(
      agents: agents,
      tools: tools,
      totalCount: json['total_count'] as int? ?? (agents.length + tools.length),
    );
  }
}

class CoquiTurnBackgroundTaskEntry {
  final String id;
  final String status;
  final String title;
  final String? role;
  final String? toolName;
  final DateTime? startedAt;
  final DateTime? createdAt;

  const CoquiTurnBackgroundTaskEntry({
    required this.id,
    required this.status,
    required this.title,
    this.role,
    this.toolName,
    this.startedAt,
    this.createdAt,
  });

  factory CoquiTurnBackgroundTaskEntry.fromJson(Map<String, dynamic> json) {
    return CoquiTurnBackgroundTaskEntry(
      id: json['id'] as String? ?? '',
      status: json['status'] as String? ?? '',
      title: json['title'] as String? ?? '',
      role: json['role'] as String?,
      toolName: json['tool_name'] as String?,
      startedAt: json['started_at'] != null
          ? DateTime.tryParse(json['started_at'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }
}

class CoquiTurnEvent {
  final int id;
  final String eventType;
  final Map<String, dynamic> data;
  final DateTime? createdAt;

  const CoquiTurnEvent({
    required this.id,
    required this.eventType,
    required this.data,
    required this.createdAt,
  });

  factory CoquiTurnEvent.fromJson(Map<String, dynamic> json) {
    return CoquiTurnEvent(
      id: json['id'] as int? ?? 0,
      eventType: json['event_type'] as String? ?? '',
      data: (json['data'] as Map?)?.cast<String, dynamic>() ?? const {},
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }
}

class CoquiTurnDetail {
  final CoquiTurn turn;
  final List<CoquiMessage> messages;
  final List<CoquiTurnEvent> events;

  const CoquiTurnDetail({
    required this.turn,
    required this.messages,
    required this.events,
  });

  factory CoquiTurnDetail.fromJson(Map<String, dynamic> json) {
    final messages = (json['messages'] as List? ?? [])
        .whereType<Map>()
        .map((message) => CoquiMessage.fromJson(message.cast<String, dynamic>()))
        .toList();
    final events = (json['events'] as List? ?? [])
        .whereType<Map>()
        .map((event) => CoquiTurnEvent.fromJson(event.cast<String, dynamic>()))
        .toList();

    return CoquiTurnDetail(
      turn: CoquiTurn.fromJson(json),
      messages: messages,
      events: events,
    );
  }
}
