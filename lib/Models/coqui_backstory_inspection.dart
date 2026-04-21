class CoquiBackstoryInspection {
  final String? profile;
  final bool available;
  final String? reason;
  final String? sourceFolder;
  final String? generatedBackstoryPath;
  final bool sourceFolderExists;
  final bool hasGeneratedBackstory;
  final String? generatedAt;
  final String? lastModifiedAt;
  final String? contentHash;
  final bool needsRegeneration;
  final int totalFiles;
  final int supportedFileCount;
  final int successfulFileCount;
  final int unsupportedFileCount;
  final int failedFileCount;
  final int totalTokens;
  final int totalSizeBytes;
  final String? content;
  final List<Map<String, dynamic>> files;
  final List<Map<String, dynamic>> folders;
  final List<Map<String, dynamic>> unsupportedFiles;
  final List<dynamic> errors;

  const CoquiBackstoryInspection({
    required this.profile,
    required this.available,
    required this.reason,
    required this.sourceFolder,
    required this.generatedBackstoryPath,
    required this.sourceFolderExists,
    required this.hasGeneratedBackstory,
    required this.generatedAt,
    required this.lastModifiedAt,
    required this.contentHash,
    required this.needsRegeneration,
    required this.totalFiles,
    required this.supportedFileCount,
    required this.successfulFileCount,
    required this.unsupportedFileCount,
    required this.failedFileCount,
    required this.totalTokens,
    required this.totalSizeBytes,
    required this.content,
    required this.files,
    required this.folders,
    required this.unsupportedFiles,
    required this.errors,
  });

  factory CoquiBackstoryInspection.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>> castList(dynamic value) {
      return (value as List? ?? [])
          .map((entry) => (entry as Map).cast<String, dynamic>())
          .toList();
    }

    return CoquiBackstoryInspection(
      profile: json['profile'] as String?,
      available: json['available'] as bool? ?? false,
      reason: json['reason'] as String?,
      sourceFolder: json['source_folder'] as String?,
      generatedBackstoryPath: json['generated_backstory_path'] as String?,
      sourceFolderExists: json['source_folder_exists'] as bool? ?? false,
      hasGeneratedBackstory: json['has_generated_backstory'] as bool? ?? false,
      generatedAt: json['generated_at'] as String?,
      lastModifiedAt: json['last_modified_at'] as String?,
      contentHash: json['content_hash'] as String?,
      needsRegeneration: json['needs_regeneration'] as bool? ?? false,
      totalFiles: json['total_files'] as int? ?? 0,
      supportedFileCount: json['supported_file_count'] as int? ?? 0,
      successfulFileCount: json['successful_file_count'] as int? ?? 0,
      unsupportedFileCount: json['unsupported_file_count'] as int? ?? 0,
      failedFileCount: json['failed_file_count'] as int? ?? 0,
      totalTokens: json['total_tokens'] as int? ?? 0,
      totalSizeBytes: json['total_size_bytes'] as int? ?? 0,
      content: json['content'] as String?,
      files: castList(json['files']),
      folders: castList(json['folders']),
      unsupportedFiles: castList(json['unsupported_files']),
      errors: (json['errors'] as List? ?? []).toList(),
    );
  }
}
