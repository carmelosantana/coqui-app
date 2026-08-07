import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:coqui_app/Providers/chat_provider.dart';
import 'package:coqui_app/Services/coqui_api_service.dart';

/// Inline card that renders a structured agent question and posts the answer
/// through the question-scoped route ([CoquiApiService.answerQuestion]).
///
/// Two shapes are supported: a single-select list of choice chips (when
/// `options` are present) with an optional free-text field for "Other", or a
/// plain free-text field (when `options` are absent/empty). Submit stays
/// disabled until the answer is valid — a chip is chosen or the free-text is
/// non-empty. On success the pending question is cleared from [ChatProvider];
/// on failure a compact SnackBar is shown and the question is left intact.
class QuestionCard extends StatefulWidget {
  final Map<String, dynamic> question;
  final String sessionId;

  const QuestionCard({
    super.key,
    required this.question,
    required this.sessionId,
  });

  @override
  State<QuestionCard> createState() => _QuestionCardState();
}

class _QuestionCardState extends State<QuestionCard> {
  final TextEditingController _textController = TextEditingController();

  late final List<String> _options;
  String? _selectedLabel;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();

    _options = _parseOptions(widget.question['options']);

    final suggested = widget.question['suggested'];
    if (suggested is String && _options.contains(suggested)) {
      _selectedLabel = suggested;
    }

    _textController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  /// Parse the raw `options` value defensively. Each element may be a bare
  /// string or a map `{value, label?}`; the label string is what we display
  /// and send back.
  static List<String> _parseOptions(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .map((option) {
          if (option is Map) {
            final label = option['label'] ?? option['value'];
            return (label ?? option.toString()).toString();
          }
          return option.toString();
        })
        .toList(growable: false);
  }

  bool get _hasOptions => _options.isNotEmpty;

  bool get _canSubmit =>
      !_submitting &&
      (_selectedLabel != null || _textController.text.trim().isNotEmpty);

  Future<void> _submit() async {
    final text = _textController.text.trim();
    final selected = _selectedLabel != null ? [_selectedLabel!] : const <String>[];

    setState(() => _submitting = true);

    final api = context.read<CoquiApiService>();
    final chatProvider = context.read<ChatProvider>();
    final messenger = ScaffoldMessenger.of(context);

    try {
      await api.answerQuestion(
        widget.sessionId,
        widget.question['question_id'] as String,
        selected: selected,
        text: text.isEmpty ? null : text,
      );
      chatProvider.clearPendingQuestion(widget.sessionId);
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not send your answer.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final prompt = widget.question['prompt'];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Material(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.outlineVariant,
              width: 0.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.help_outline,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      prompt is String && prompt.isNotEmpty
                          ? prompt
                          : 'The agent needs your input',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_hasOptions) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _options.map((label) {
                    return ChoiceChip(
                      label: Text(label),
                      selected: _selectedLabel == label,
                      onSelected: _submitting
                          ? null
                          : (chosen) => setState(
                                () => _selectedLabel = chosen ? label : null,
                              ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _textController,
                  enabled: !_submitting,
                  decoration: const InputDecoration(
                    isDense: true,
                    border: OutlineInputBorder(),
                    hintText: 'Other (optional)',
                  ),
                  onChanged: (value) {
                    // Typing free text clears any chip selection so the answer
                    // stays single-valued per the CAP contract.
                    if (value.trim().isNotEmpty && _selectedLabel != null) {
                      setState(() => _selectedLabel = null);
                    }
                  },
                ),
              ] else
                TextField(
                  controller: _textController,
                  enabled: !_submitting,
                  autofocus: true,
                  minLines: 1,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    isDense: true,
                    border: OutlineInputBorder(),
                    hintText: 'Type your answer',
                  ),
                ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: _canSubmit ? _submit : null,
                  child: const Text('Submit'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
