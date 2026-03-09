import 'package:uuid/uuid.dart';

enum UploadedFileStatus { uploading, uploaded, error }

final class UploadedFile {
  final String localId;
  final String name;
  final int size;
  final String? mimeType;
  final String? serverId;
  final UploadedFileStatus status;

  UploadedFile({
    String? localId,
    required this.name,
    required this.size,
    this.mimeType,
    this.serverId,
    this.status = UploadedFileStatus.uploading,
  }) : localId = localId ?? const Uuid().v4();

  UploadedFile copyWith({
    String? serverId,
    UploadedFileStatus? status,
  }) {
    return UploadedFile(
      localId: localId,
      name: name,
      size: size,
      mimeType: mimeType,
      serverId: serverId ?? this.serverId,
      status: status ?? this.status,
    );
  }

  /// Human-readable file size (e.g. "1.4 MB").
  String get formattedSize {
    if (size < 1024) return '$size B';
    if (size < 1048576) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / 1048576).toStringAsFixed(1)} MB';
  }

  /// File name truncated to fit in a chip, preserving the extension.
  String get truncatedName {
    const maxLength = 22;
    if (name.length <= maxLength) return name;
    final dotIndex = name.lastIndexOf('.');
    final ext = dotIndex >= 0 ? name.substring(dotIndex) : '';
    final base = name.substring(0, maxLength - ext.length - 1);
    return '$base…$ext';
  }
}
