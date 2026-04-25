class ChatPreset {
  final String title;
  final String subtitle;
  final String prompt;
  final String? category;
  final String? role;

  ChatPreset({
    required this.title,
    required this.subtitle,
    required this.prompt,
    this.category,
    this.role,
  });
}
