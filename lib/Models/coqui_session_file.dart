class CoquiSessionFile {
  final String id;
  final String originalName;
  final String mimeType;
  final int size;
  final bool isImage;
  final DateTime createdAt;

  CoquiSessionFile({
    required this.id,
    required this.originalName,
    required this.mimeType,
    required this.size,
    required this.isImage,
    required this.createdAt,
  });

  factory CoquiSessionFile.fromJson(Map<String, dynamic> json) {
    return CoquiSessionFile(
      id: json['id'] as String? ?? '',
      originalName: json['original_name'] as String? ?? '',
      mimeType: json['mime_type'] as String? ?? 'application/octet-stream',
      size: json['size'] as int? ?? 0,
      isImage: json['is_image'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  String get sizeLabel {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) {
      return '${(size / 1024).toStringAsFixed(1)} KB';
    }
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}