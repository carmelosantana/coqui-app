import 'package:coqui_app/Models/coqui_mcp_server_audit.dart';

class CoquiMcpServer {
  final String name;
  final String? description;
  final bool connected;
  final bool disabled;
  final String loadingMode;
  final String? serverName;
  final String? serverVersion;
  final int toolCount;
  final String? error;
  final String? instructions;
  final String? command;
  final List<String> args;
  final Map<String, String> env;
  final CoquiMcpServerAudit audit;

  const CoquiMcpServer({
    required this.name,
    required this.description,
    required this.connected,
    required this.disabled,
    required this.loadingMode,
    required this.serverName,
    required this.serverVersion,
    required this.toolCount,
    required this.error,
    required this.instructions,
    required this.command,
    required this.args,
    required this.env,
    required this.audit,
  });

  factory CoquiMcpServer.fromJson(Map<String, dynamic> json) {
    return CoquiMcpServer(
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      connected: _coerceBool(json['connected']),
      disabled: _coerceBool(json['disabled']),
      loadingMode: json['loadingMode'] as String? ?? 'auto',
      serverName: json['serverName'] as String?,
      serverVersion: json['serverVersion'] as String?,
      toolCount: _coerceInt(json['toolCount']),
      error: json['error'] as String?,
      instructions: json['instructions'] as String?,
      command: json['command'] as String?,
      args: _coerceStringList(json['args']),
      env: _coerceStringMap(json['env']),
      audit: json['audit'] is Map<String, dynamic>
          ? CoquiMcpServerAudit.fromJson(json['audit'] as Map<String, dynamic>)
          : CoquiMcpServerAudit.empty,
    );
  }

  bool get enabled => !disabled;

  bool get hasDescription => description != null && description!.isNotEmpty;

  bool get hasError => error != null && error!.isNotEmpty;

  bool get hasInstructions => instructions != null && instructions!.isNotEmpty;

  String get displayName =>
      (serverName != null && serverName!.isNotEmpty) ? serverName! : name;

  String get commandLabel {
    if (command == null || command!.isEmpty) {
      return 'No command configured';
    }

    return ([command!, ...args]).join(' ');
  }

  String get statusLabel {
    if (disabled) return 'Disabled';
    if (connected) return 'Connected';
    return 'Disconnected';
  }

  CoquiMcpServer copyWith({
    String? name,
    String? description,
    bool? connected,
    bool? disabled,
    String? loadingMode,
    String? serverName,
    String? serverVersion,
    int? toolCount,
    String? error,
    String? instructions,
    String? command,
    List<String>? args,
    Map<String, String>? env,
    CoquiMcpServerAudit? audit,
  }) {
    return CoquiMcpServer(
      name: name ?? this.name,
      description: description ?? this.description,
      connected: connected ?? this.connected,
      disabled: disabled ?? this.disabled,
      loadingMode: loadingMode ?? this.loadingMode,
      serverName: serverName ?? this.serverName,
      serverVersion: serverVersion ?? this.serverVersion,
      toolCount: toolCount ?? this.toolCount,
      error: error ?? this.error,
      instructions: instructions ?? this.instructions,
      command: command ?? this.command,
      args: args ?? this.args,
      env: env ?? this.env,
      audit: audit ?? this.audit,
    );
  }
}

bool _coerceBool(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    return value == '1' || value.toLowerCase() == 'true';
  }
  return false;
}

int _coerceInt(Object? value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

List<String> _coerceStringList(Object? value) {
  if (value is! List) return const [];
  return value.map((item) => item.toString()).toList(growable: false);
}

Map<String, String> _coerceStringMap(Object? value) {
  if (value is! Map) return const {};

  return value.map(
    (key, item) => MapEntry(key.toString(), item.toString()),
  );
}
