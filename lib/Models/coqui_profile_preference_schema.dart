class CoquiProfilePreferenceSchema {
  final int version;
  final List<CoquiProfilePreferenceSection> sections;
  final bool advancedEditorDeferred;
  final bool unsupportedFieldsHidden;

  const CoquiProfilePreferenceSchema({
    required this.version,
    required this.sections,
    required this.advancedEditorDeferred,
    required this.unsupportedFieldsHidden,
  });

  factory CoquiProfilePreferenceSchema.fromJson(Map<String, dynamic> json) {
    final deferred = (json['deferred'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};

    return CoquiProfilePreferenceSchema(
      version: json['version'] as int? ?? 1,
      sections: (json['sections'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (section) => CoquiProfilePreferenceSection.fromJson(
              section.cast<String, dynamic>(),
            ),
          )
          .toList(growable: false),
      advancedEditorDeferred:
          deferred['advanced_editor'] as bool? ?? false,
      unsupportedFieldsHidden:
          deferred['unsupported_fields_hidden'] as bool? ?? false,
    );
  }
}

class CoquiProfilePreferenceSection {
  final String id;
  final String label;
  final String description;
  final List<CoquiProfilePreferenceField> fields;

  const CoquiProfilePreferenceSection({
    required this.id,
    required this.label,
    required this.description,
    required this.fields,
  });

  factory CoquiProfilePreferenceSection.fromJson(Map<String, dynamic> json) {
    return CoquiProfilePreferenceSection(
      id: json['id'] as String? ?? '',
      label: json['label'] as String? ?? '',
      description: json['description'] as String? ?? '',
      fields: (json['fields'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (field) => CoquiProfilePreferenceField.fromJson(
              field.cast<String, dynamic>(),
            ),
          )
          .toList(growable: false),
    );
  }
}

class CoquiProfilePreferenceField {
  final String id;
  final String label;
  final String storagePath;
  final String input;
  final String description;
  final List<String> suggestions;
  final List<String> options;
  final List<CoquiProfilePreferenceOption> optionItems;

  const CoquiProfilePreferenceField({
    required this.id,
    required this.label,
    required this.storagePath,
    required this.input,
    required this.description,
    this.suggestions = const [],
    this.options = const [],
    this.optionItems = const [],
  });

  factory CoquiProfilePreferenceField.fromJson(Map<String, dynamic> json) {
    final rawOptions = json['options'] as List? ?? const [];

    return CoquiProfilePreferenceField(
      id: json['id'] as String? ?? '',
      label: json['label'] as String? ?? '',
      storagePath: json['storage_path'] as String? ?? '',
      input: json['input'] as String? ?? 'text',
      description: json['description'] as String? ?? '',
      suggestions: (json['suggestions'] as List? ?? const [])
          .whereType<String>()
          .toList(growable: false),
      options: rawOptions.whereType<String>().toList(growable: false),
      optionItems: rawOptions
          .whereType<Map>()
          .map(
            (option) => CoquiProfilePreferenceOption.fromJson(
              option.cast<String, dynamic>(),
            ),
          )
          .toList(growable: false),
    );
  }
}

class CoquiProfilePreferenceOption {
  final String value;
  final String label;

  const CoquiProfilePreferenceOption({
    required this.value,
    required this.label,
  });

  factory CoquiProfilePreferenceOption.fromJson(Map<String, dynamic> json) {
    return CoquiProfilePreferenceOption(
      value: json['value'] as String? ?? '',
      label: json['label'] as String? ?? '',
    );
  }
}