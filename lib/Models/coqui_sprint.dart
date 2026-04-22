class CoquiSprint {
  final String id;
  final String projectId;
  final String title;
  final int sprintNumber;
  final String status;
  final String? acceptanceCriteria;
  final String? reviewerNotes;
  final int reviewRound;
  final int maxReviewRounds;
  final String? lastSessionId;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? completedAt;

  const CoquiSprint({
    required this.id,
    required this.projectId,
    required this.title,
    required this.sprintNumber,
    required this.status,
    required this.acceptanceCriteria,
    required this.reviewerNotes,
    required this.reviewRound,
    required this.maxReviewRounds,
    required this.lastSessionId,
    required this.createdAt,
    required this.updatedAt,
    required this.completedAt,
  });

  factory CoquiSprint.fromJson(Map<String, dynamic> json) {
    return CoquiSprint(
      id: json['id'] as String? ?? '',
      projectId: json['project_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      sprintNumber: _coerceInt(json['sprint_number']),
      status: json['status'] as String? ?? 'planned',
      acceptanceCriteria: json['acceptance_criteria'] as String?,
      reviewerNotes: json['reviewer_notes'] as String?,
      reviewRound: _coerceInt(json['review_round']),
      maxReviewRounds: _coerceInt(json['max_review_rounds']),
      lastSessionId: json['last_session_id'] as String?,
      createdAt: _parseDateTime(json['created_at']),
      updatedAt: _parseDateTime(json['updated_at']),
      completedAt: _parseDateTime(json['completed_at']),
    );
  }

  String get label => sprintNumber > 0 ? 'Sprint $sprintNumber: $title' : title;

  bool get hasAcceptanceCriteria =>
      acceptanceCriteria != null && acceptanceCriteria!.isNotEmpty;

  bool get isPlanned => status == 'planned';

  bool get isInProgress => status == 'in_progress';

  bool get isReview => status == 'review';

  bool get isComplete => status == 'complete';

  bool get isRejected => status == 'rejected';

  bool get canDelete => isPlanned;

  bool get canStart => isPlanned;

  bool get canSubmitReview => isInProgress;

  bool get canComplete => isReview;

  bool get canReject => isReview;
}

DateTime? _parseDateTime(Object? value) {
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value);
}

int _coerceInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}
