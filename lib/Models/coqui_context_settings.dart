import 'package:coqui_app/Models/coqui_restart_state.dart';

class CoquiContextSettingsValues {
  final bool conversationHistoryInSystemPrompt;
  final String autoSummarizeMode;
  final double autoSummarizeThreshold;
  final int autoSummarizeTurnThreshold;
  final int autoSummarizeKeepRecent;

  const CoquiContextSettingsValues({
    required this.conversationHistoryInSystemPrompt,
    required this.autoSummarizeMode,
    required this.autoSummarizeThreshold,
    required this.autoSummarizeTurnThreshold,
    required this.autoSummarizeKeepRecent,
  });

  factory CoquiContextSettingsValues.fromJson(Map<String, dynamic> json) {
    return CoquiContextSettingsValues(
      conversationHistoryInSystemPrompt:
          json['conversationHistoryInSystemPrompt'] as bool? ?? false,
      autoSummarizeMode: json['autoSummarizeMode'] as String? ?? 'token',
      autoSummarizeThreshold:
          (json['autoSummarizeThreshold'] as num?)?.toDouble() ?? 64.0,
      autoSummarizeTurnThreshold:
          (json['autoSummarizeTurnThreshold'] as num?)?.toInt() ?? 32,
      autoSummarizeKeepRecent:
          (json['autoSummarizeKeepRecent'] as num?)?.toInt() ?? 15,
    );
  }
}

class CoquiContextSettingField {
  final String key;
  final String dotKey;
  final String label;
  final String description;
  final String type;
  final bool resettable;
  final bool restartRequired;
  final bool configured;
  final dynamic defaultValue;
  final dynamic value;
  final List<String> options;
  final double? minimum;
  final double? maximum;
  final String? presentation;

  const CoquiContextSettingField({
    required this.key,
    required this.dotKey,
    required this.label,
    required this.description,
    required this.type,
    required this.resettable,
    required this.restartRequired,
    required this.configured,
    required this.defaultValue,
    required this.value,
    required this.options,
    required this.minimum,
    required this.maximum,
    required this.presentation,
  });

  factory CoquiContextSettingField.fromJson(Map<String, dynamic> json) {
    final options = (json['options'] as List? ?? const <dynamic>[])
        .map((item) => item.toString())
        .toList(growable: false);

    return CoquiContextSettingField(
      key: json['key'] as String? ?? '',
      dotKey: json['dot_key'] as String? ?? '',
      label: json['label'] as String? ?? '',
      description: json['description'] as String? ?? '',
      type: json['type'] as String? ?? '',
      resettable: json['resettable'] as bool? ?? false,
      restartRequired: json['restart_required'] as bool? ?? false,
      configured: json['configured'] as bool? ?? false,
      defaultValue: json['default'],
      value: json['value'],
      options: options,
      minimum: (json['minimum'] as num?)?.toDouble(),
      maximum: (json['maximum'] as num?)?.toDouble(),
      presentation: json['presentation'] as String?,
    );
  }
}

class CoquiContextSettings {
  final CoquiContextSettingsValues context;
  final CoquiContextSettingsValues defaults;
  final Map<String, CoquiContextSettingField> fields;
  final CoquiRestartState restart;

  const CoquiContextSettings({
    required this.context,
    required this.defaults,
    required this.fields,
    required this.restart,
  });

  factory CoquiContextSettings.fromJson(Map<String, dynamic> json) {
    final fieldsJson = json['fields'] as Map? ?? const {};

    return CoquiContextSettings(
      context: CoquiContextSettingsValues.fromJson(
        (json['context'] as Map? ?? const {}).cast<String, dynamic>(),
      ),
      defaults: CoquiContextSettingsValues.fromJson(
        (json['defaults'] as Map? ?? const {}).cast<String, dynamic>(),
      ),
      fields: fieldsJson.map(
        (key, value) => MapEntry(
          key.toString(),
          CoquiContextSettingField.fromJson(
            (value as Map).cast<String, dynamic>(),
          ),
        ),
      ),
      restart: CoquiRestartState.fromJson(
        (json['restart'] as Map? ?? const {}).cast<String, dynamic>(),
      ),
    );
  }
}

class CoquiContextSettingsUpdateResult {
  final CoquiContextSettingsValues context;
  final List<String> updated;
  final List<String> reset;
  final bool restartRequired;
  final CoquiRestartState restart;

  const CoquiContextSettingsUpdateResult({
    required this.context,
    required this.updated,
    required this.reset,
    required this.restartRequired,
    required this.restart,
  });

  factory CoquiContextSettingsUpdateResult.fromJson(Map<String, dynamic> json) {
    return CoquiContextSettingsUpdateResult(
      context: CoquiContextSettingsValues.fromJson(
        (json['context'] as Map? ?? const {}).cast<String, dynamic>(),
      ),
      updated: (json['updated'] as List? ?? const <dynamic>[])
          .map((item) => item.toString())
          .toList(growable: false),
      reset: (json['reset'] as List? ?? const <dynamic>[])
          .map((item) => item.toString())
          .toList(growable: false),
      restartRequired: json['restart_required'] as bool? ?? false,
      restart: CoquiRestartState.fromJson(
        (json['restart'] as Map? ?? const {}).cast<String, dynamic>(),
      ),
    );
  }
}
