import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:coqui_app/Theme/coqui_typography.dart';

/// Extension on [BuildContext] to provide consistent markdown styling across the app.
extension MarkdownStyleSheetExtension on BuildContext {
  /// Returns a [MarkdownStyleSheet] that matches the app's theme with bodyLarge text size.
  ///
  /// This ensures markdown content uses the same base size as other readable text
  /// in the app, while respecting user accessibility settings up to 2x scale.
  MarkdownStyleSheet get markdownStyleSheet {
    return MarkdownStyleSheet.fromTheme(
      Theme.of(this).copyWith(
        textTheme: Theme.of(this).textTheme.copyWith(
              bodyMedium: Theme.of(this).textTheme.bodyLarge,
            ),
      ),
    ).copyWith(
      code: CoquiTypography.monoStyle(
        TextStyle(fontSize: Theme.of(this).textTheme.bodyMedium?.fontSize),
      ),
      codeblockDecoration: BoxDecoration(
        color: Theme.of(this).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
      ),
      textScaler: MediaQuery.textScalerOf(this).clamp(
        minScaleFactor: 0.8,
        maxScaleFactor: 2.0,
      ),
    );
  }
}
