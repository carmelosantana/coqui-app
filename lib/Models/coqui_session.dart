import 'dart:convert';

import 'package:coqui_app/Models/coqui_session_channel.dart';
import 'package:coqui_app/Models/coqui_session_member.dart';

/// Represents a Coqui API session (conversation context).
///
/// Sessions are persistent server-side and identified by a 32-char hex ID.
/// Each session has a model role that determines which LLM model is used.
/// Session titles are generated server-side after the first turn and
/// delivered via an SSE `title` event.
class CoquiSession {
  final String id;
  final String modelRole;
  final String model;
  final String? profile;
  final bool groupEnabled;
  final int groupMaxRounds;
  final String? groupCompositionKey;
  final List<CoquiSessionMember> groupMembers;
  final String? activeProjectId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int tokenCount;
  final bool isClosed;
  final bool isArchived;
  final DateTime? closedAt;
  final DateTime? archivedAt;
  final String? closureReason;
  final bool channelBound;
  final CoquiSessionChannel? channel;

  /// Server-generated session title, delivered via SSE `title` event.
  String? title;

  CoquiSession({
    required this.id,
    required this.modelRole,
    required this.model,
    this.profile,
    this.groupEnabled = false,
    this.groupMaxRounds = 3,
    this.groupCompositionKey,
    this.groupMembers = const [],
    this.activeProjectId,
    required this.createdAt,
    required this.updatedAt,
    this.tokenCount = 0,
    this.isClosed = false,
    this.isArchived = false,
    this.closedAt,
    this.archivedAt,
    this.closureReason,
    this.channelBound = false,
    this.channel,
    this.title,
  });

  factory CoquiSession.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value is! String || value.isEmpty) return null;
      return DateTime.tryParse(value);
    }

    bool parseFlag(dynamic value) {
      if (value is bool) return value;
      if (value is num) return value != 0;
      if (value is String) {
        return value == '1' || value.toLowerCase() == 'true';
      }
      return false;
    }

    int parseInt(dynamic value, {int fallback = 0}) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) {
        return int.tryParse(value) ?? fallback;
      }
      return fallback;
    }

    List<CoquiSessionMember> parseGroupMembers(dynamic value) {
      if (value is! List) return const [];

      final members = value
          .whereType<Map>()
          .map(
            (member) => CoquiSessionMember.fromJson(
              member.map(
                (key, value) => MapEntry(key.toString(), value),
              ),
            ),
          )
          .where((member) => member.profile.isNotEmpty)
          .toList();

      members.sort((left, right) => left.position.compareTo(right.position));
      return members;
    }

    CoquiSessionChannel? parseChannel(dynamic value) {
      if (value is! Map) return null;

      return CoquiSessionChannel.fromJson(
        value.map((key, value) => MapEntry(key.toString(), value)),
      );
    }

    final channel = parseChannel(json['channel']);

    return CoquiSession(
      id: json['id'] as String,
      modelRole: json['model_role'] as String? ?? 'orchestrator',
      model: json['model'] as String? ?? '',
      profile: json['profile'] as String?,
      groupEnabled: parseFlag(json['group_enabled']),
      groupMaxRounds: parseInt(json['group_max_rounds'], fallback: 3),
      groupCompositionKey: json['group_composition_key'] as String?,
      groupMembers: parseGroupMembers(json['group_members']),
      activeProjectId: json['active_project_id'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
      tokenCount: json['token_count'] as int? ?? 0,
      isClosed: parseFlag(json['is_closed']),
      isArchived: parseFlag(json['is_archived']),
      closedAt: parseDate(json['closed_at']),
      archivedAt: parseDate(json['archived_at']),
      closureReason: json['closure_reason'] as String?,
      channelBound: parseFlag(json['channel_bound']) || channel != null,
      channel: channel,
      title: json['title'] as String?,
    );
  }

  factory CoquiSession.fromDatabase(Map<String, dynamic> map) {
    final closedAtMillis = map['closed_at'] as int?;
    final archivedAtMillis = map['archived_at'] as int?;
    final groupMembersJson = map['group_members_json'] as String?;
    final channelJson = map['channel_json'] as String?;
    final groupMembers = groupMembersJson == null || groupMembersJson.isEmpty
        ? <CoquiSessionMember>[]
        : (jsonDecode(groupMembersJson) as List<dynamic>)
            .whereType<Map>()
            .map(
              (member) => CoquiSessionMember.fromDatabase(
                member.map(
                  (key, value) => MapEntry(key.toString(), value),
                ),
              ),
            )
            .toList();
    final channel = channelJson == null || channelJson.isEmpty
        ? null
        : CoquiSessionChannel.fromDatabase(
            (jsonDecode(channelJson) as Map<dynamic, dynamic>).map(
              (key, value) => MapEntry(key.toString(), value),
            ),
          );

    groupMembers.sort((left, right) => left.position.compareTo(right.position));

    return CoquiSession(
      id: map['id'] as String,
      modelRole: map['model_role'] as String,
      model: map['model'] as String? ?? '',
      profile: map['profile'] as String?,
      groupEnabled: (map['group_enabled'] as int? ?? 0) != 0,
      groupMaxRounds: map['group_max_rounds'] as int? ?? 3,
      groupCompositionKey: map['group_composition_key'] as String?,
      groupMembers: groupMembers,
      activeProjectId: map['active_project_id'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
      tokenCount: map['token_count'] as int? ?? 0,
      isClosed: (map['is_closed'] as int? ?? 0) != 0,
      isArchived: (map['is_archived'] as int? ?? 0) != 0,
      closedAt: closedAtMillis != null
          ? DateTime.fromMillisecondsSinceEpoch(closedAtMillis)
          : null,
      archivedAt: archivedAtMillis != null
          ? DateTime.fromMillisecondsSinceEpoch(archivedAtMillis)
          : null,
      closureReason: map['closure_reason'] as String?,
      channelBound: (map['channel_bound'] as int? ?? 0) != 0 || channel != null,
      channel: channel,
      title: map['title'] as String?,
    );
  }

  Map<String, dynamic> toDatabaseMap() {
    return {
      'id': id,
      'model_role': modelRole,
      'model': model,
      'profile': profile,
      'group_enabled': groupEnabled ? 1 : 0,
      'group_max_rounds': groupMaxRounds,
      'group_composition_key': groupCompositionKey,
      'group_members_json': jsonEncode(
        orderedGroupMembers.map((member) => member.toDatabaseMap()).toList(),
      ),
      'active_project_id': activeProjectId,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
      'token_count': tokenCount,
      'is_closed': isClosed ? 1 : 0,
      'is_archived': isArchived ? 1 : 0,
      'closed_at': closedAt?.millisecondsSinceEpoch,
      'archived_at': archivedAt?.millisecondsSinceEpoch,
      'closure_reason': closureReason,
      'channel_bound': isChannelBound ? 1 : 0,
      'channel_json':
          channel == null ? null : jsonEncode(channel!.toDatabaseMap()),
      'title': title,
    };
  }

  CoquiSession copyWith({
    String? modelRole,
    String? model,
    String? profile,
    bool? groupEnabled,
    int? groupMaxRounds,
    String? groupCompositionKey,
    List<CoquiSessionMember>? groupMembers,
    String? activeProjectId,
    String? title,
    int? tokenCount,
    DateTime? updatedAt,
    bool? isClosed,
    bool? isArchived,
    DateTime? closedAt,
    DateTime? archivedAt,
    String? closureReason,
    bool? channelBound,
    CoquiSessionChannel? channel,
  }) {
    return CoquiSession(
      id: id,
      modelRole: modelRole ?? this.modelRole,
      model: model ?? this.model,
      profile: profile ?? this.profile,
      groupEnabled: groupEnabled ?? this.groupEnabled,
      groupMaxRounds: groupMaxRounds ?? this.groupMaxRounds,
      groupCompositionKey: groupCompositionKey ?? this.groupCompositionKey,
      groupMembers: groupMembers ?? this.groupMembers,
      activeProjectId: activeProjectId ?? this.activeProjectId,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      tokenCount: tokenCount ?? this.tokenCount,
      isClosed: isClosed ?? this.isClosed,
      isArchived: isArchived ?? this.isArchived,
      closedAt: closedAt ?? this.closedAt,
      archivedAt: archivedAt ?? this.archivedAt,
      closureReason: closureReason ?? this.closureReason,
      channelBound: channelBound ?? this.channelBound,
      channel: channel ?? this.channel,
      title: title ?? this.title,
    );
  }

  bool get isReadOnly => isClosed || isArchived;

  bool get isChannelBound => channelBound || channel != null;

  bool get isActive => !isClosed;

  bool get isGroupSession => groupEnabled;

  List<CoquiSessionMember> get orderedGroupMembers {
    final members = List<CoquiSessionMember>.from(groupMembers);
    members.sort((left, right) => left.position.compareTo(right.position));
    return List.unmodifiable(members);
  }

  List<String> get groupProfileNames => orderedGroupMembers
      .map((member) => member.profile)
      .where((profile) => profile.isNotEmpty)
      .toList(growable: false);

  String? get primaryProfileLabel {
    if (isGroupSession) {
      return groupProfileNames.isNotEmpty ? groupProfileNames.first : null;
    }

    return profileLabel;
  }

  String get participantSummary {
    if (isGroupSession) {
      final names = groupProfileNames;
      if (names.isEmpty) {
        return 'Group session';
      }

      return names.join(', ');
    }

    return profileLabel ?? 'No profile';
  }

  String get compactParticipantSummary {
    if (!isGroupSession) {
      return participantSummary;
    }

    final names = groupProfileNames;
    if (names.isEmpty) return 'Group session';
    if (names.length <= 3) return names.join(', ');
    return '${names.take(2).join(', ')} +${names.length - 2}';
  }

  String get status {
    if (isArchived) return 'archived';
    if (isClosed) return 'closed';
    return 'active';
  }

  String? get profileLabel => profile?.isNotEmpty == true ? profile : null;

  String get shortId => id.length <= 8 ? id : id.substring(0, 8);

  String get displayTitle {
    final trimmedTitle = title?.trim();
    if (trimmedTitle != null && trimmedTitle.isNotEmpty) {
      return trimmedTitle;
    }

    return 'Session $shortId';
  }

  String? get channelSummaryLabel {
    if (!isChannelBound) return null;
    return channel?.summaryLabel ?? 'Channel linked';
  }

  @override
  String toString() => title ?? 'Session ${id.substring(0, 8)}';
}
