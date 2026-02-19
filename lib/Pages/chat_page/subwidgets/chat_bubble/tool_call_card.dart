import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// An inline collapsible card that displays a tool call within a chat bubble.
///
/// Shows the tool name and a brief argument summary when collapsed.
/// Expands to show full arguments and, if available, the tool result.
class ToolCallCard extends StatefulWidget {
  final Map<String, dynamic> toolCall;

  /// Optional tool result content (matched by tool_call_id).
  final String? resultContent;

  /// Whether the tool call succeeded (from the result message).
  final bool? resultSuccess;

  const ToolCallCard({
    super.key,
    required this.toolCall,
    this.resultContent,
    this.resultSuccess,
  });

  @override
  State<ToolCallCard> createState() => _ToolCallCardState();
}

class _ToolCallCardState extends State<ToolCallCard> {
  bool _expanded = false;

  String get _toolName =>
      widget.toolCall['name'] as String? ??
      widget.toolCall['function']?['name'] as String? ??
      'unknown';

  Map<String, dynamic> get _arguments {
    final args = widget.toolCall['arguments'];
    if (args is Map<String, dynamic>) return args;
    if (args is String) {
      try {
        final decoded = jsonDecode(args);
        if (decoded is Map<String, dynamic>) return decoded;
      } catch (_) {}
    }
    // Check nested function.arguments format
    final fn = widget.toolCall['function'];
    if (fn is Map<String, dynamic>) {
      final fnArgs = fn['arguments'];
      if (fnArgs is Map<String, dynamic>) return fnArgs;
      if (fnArgs is String) {
        try {
          final decoded = jsonDecode(fnArgs);
          if (decoded is Map<String, dynamic>) return decoded;
        } catch (_) {}
      }
    }
    return {};
  }

  String get _argsSummary {
    final args = _arguments;
    if (args.isEmpty) return '';
    return args.entries
        .take(3) // Show at most 3 args in collapsed view
        .map((e) => '${e.key}: ${_truncate(e.value.toString(), 40)}')
        .join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasResult = widget.resultContent != null;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2.0),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(
          color: colorScheme.outlineVariant,
          width: 0.5,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8.0),
        onTap: () => setState(() => _expanded = !_expanded),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header row: icon + tool name + expand indicator
              Row(
                children: [
                  Icon(
                    Icons.build_rounded,
                    size: 14,
                    color: colorScheme.tertiary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _toolName,
                      style: GoogleFonts.sourceCodePro(
                        textStyle:
                            Theme.of(context).textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.onSurface,
                                ),
                      ),
                    ),
                  ),
                  if (hasResult)
                    Icon(
                      widget.resultSuccess == true
                          ? Icons.check_circle_outline
                          : Icons.error_outline,
                      size: 14,
                      color: widget.resultSuccess == true
                          ? colorScheme.primary
                          : colorScheme.error,
                    ),
                  const SizedBox(width: 4),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 16,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
              // Collapsed: brief args summary
              if (!_expanded && _argsSummary.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4.0, left: 20.0),
                  child: Text(
                    _argsSummary,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              // Expanded: full arguments + result
              if (_expanded) ...[
                if (_arguments.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0, left: 20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _arguments.entries.map((entry) {
                        final valueStr =
                            entry.value is Map || entry.value is List
                                ? const JsonEncoder.withIndent('  ')
                                    .convert(entry.value)
                                : entry.value.toString();
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                entry.key,
                                style: GoogleFonts.sourceCodePro(
                                  textStyle: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                        color: colorScheme.tertiary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ),
                              Text(
                                valueStr,
                                style: GoogleFonts.sourceCodePro(
                                  textStyle: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                ),
                                maxLines: 10,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                if (hasResult)
                  Container(
                    margin: const EdgeInsets.only(top: 8.0, left: 20.0),
                    padding: const EdgeInsets.all(8.0),
                    decoration: BoxDecoration(
                      color: widget.resultSuccess == true
                          ? colorScheme.primaryContainer.withValues(alpha: 0.3)
                          : colorScheme.errorContainer.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(6.0),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              widget.resultSuccess == true
                                  ? Icons.check_circle_outline
                                  : Icons.error_outline,
                              size: 12,
                              color: widget.resultSuccess == true
                                  ? colorScheme.primary
                                  : colorScheme.error,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              widget.resultSuccess == true ? 'Result' : 'Error',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: widget.resultSuccess == true
                                        ? colorScheme.primary
                                        : colorScheme.error,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _truncate(widget.resultContent!, 500),
                          style: GoogleFonts.sourceCodePro(
                            textStyle:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                          ),
                          maxLines: 15,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String _truncate(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }
}
