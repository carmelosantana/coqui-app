class CoquiCommandCatalog {
  final List<CoquiCommandSection> sections;
  final List<CoquiCommandEntry> commands;
  final int count;

  const CoquiCommandCatalog({
    required this.sections,
    required this.commands,
    required this.count,
  });

  factory CoquiCommandCatalog.fromJson(Map<String, dynamic> json) {
    final sections = (json['sections'] as List? ?? [])
        .map((section) =>
            CoquiCommandSection.fromJson(section as Map<String, dynamic>))
        .toList();
    final commands = (json['commands'] as List? ?? [])
        .map((command) =>
            CoquiCommandEntry.fromJson(command as Map<String, dynamic>))
        .toList();

    return CoquiCommandCatalog(
      sections: sections,
      commands: commands,
      count: json['count'] as int? ?? commands.length,
    );
  }
}

class CoquiCommandSection {
  final String name;
  final List<CoquiCommandEntry> commands;

  const CoquiCommandSection({
    required this.name,
    required this.commands,
  });

  factory CoquiCommandSection.fromJson(Map<String, dynamic> json) {
    final commands = (json['commands'] as List? ?? [])
        .map((command) =>
            CoquiCommandEntry.fromJson(command as Map<String, dynamic>))
        .toList();

    return CoquiCommandSection(
      name: json['name'] as String? ?? '',
      commands: commands,
    );
  }
}

class CoquiCommandEntry {
  final String name;
  final String usage;
  final String description;
  final String helpDescription;
  final List<String> aliases;
  final List<String> firstArguments;
  final String section;

  const CoquiCommandEntry({
    required this.name,
    required this.usage,
    required this.description,
    required this.helpDescription,
    required this.aliases,
    required this.firstArguments,
    required this.section,
  });

  factory CoquiCommandEntry.fromJson(Map<String, dynamic> json) {
    return CoquiCommandEntry(
      name: json['name'] as String? ?? '',
      usage: json['usage'] as String? ?? '',
      description: json['description'] as String? ?? '',
      helpDescription: json['help_description'] as String? ?? '',
      aliases: (json['aliases'] as List? ?? []).cast<String>(),
      firstArguments: (json['first_arguments'] as List? ?? []).cast<String>(),
      section: json['section'] as String? ?? '',
    );
  }
}
