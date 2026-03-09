import 'package:flutter/material.dart';

import 'package:coqui_app/Models/uploaded_file.dart';

/// A compact chip widget displaying an attached file and its upload status.
///
/// Shows the file name, size, a status icon (spinner / check / error), and
/// a dismiss button to remove the file before sending the prompt.
class ChatFileChip extends StatelessWidget {
  final UploadedFile file;
  final VoidCallback onRemove;

  const ChatFileChip({
    super.key,
    required this.file,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _borderColor(colorScheme),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildStatusIcon(context),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                file.truncatedName,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurface,
                    ),
              ),
              Text(
                file.formattedSize,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: Icon(
              Icons.close,
              size: 14,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIcon(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return switch (file.status) {
      UploadedFileStatus.uploading => SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            color: colorScheme.primary,
          ),
        ),
      UploadedFileStatus.uploaded => Icon(
          Icons.attach_file,
          size: 14,
          color: colorScheme.primary,
        ),
      UploadedFileStatus.error => Icon(
          Icons.error_outline,
          size: 14,
          color: colorScheme.error,
        ),
    };
  }

  Color _borderColor(ColorScheme colorScheme) {
    return switch (file.status) {
      UploadedFileStatus.uploading => colorScheme.outlineVariant,
      UploadedFileStatus.uploaded => colorScheme.primary.withValues(alpha: 0.4),
      UploadedFileStatus.error => colorScheme.error.withValues(alpha: 0.4),
    };
  }
}
