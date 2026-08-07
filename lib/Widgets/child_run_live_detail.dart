import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:coqui_app/Models/coqui_child_run.dart';
import 'package:coqui_app/Models/sse_event.dart';
import 'package:coqui_app/Services/coqui_api_service.dart';

/// Live streaming detail for a single child run.
///
/// When the run is `running`, subscribes to
/// [CoquiApiService.streamChildRunEvents] in [initState], accumulates `token`
/// frame text into a live output view, and settles on the terminal `done`
/// frame (parsed via [CoquiChildRun.fromJson]). The subscription is cancelled
/// in [dispose]. Non-running runs render a static detail from the record's
/// existing `result` and token counters — no stream is opened.
class ChildRunLiveDetail extends StatefulWidget {
  final String sessionId;
  final CoquiChildRun childRun;

  const ChildRunLiveDetail({
    super.key,
    required this.sessionId,
    required this.childRun,
  });

  @override
  State<ChildRunLiveDetail> createState() => _ChildRunLiveDetailState();
}

class _ChildRunLiveDetailState extends State<ChildRunLiveDetail> {
  StreamSubscription<SseEvent>? _subscription;
  final StringBuffer _output = StringBuffer();

  late CoquiChildRun _run;
  bool _streaming = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _run = widget.childRun;

    if (_run.status == 'running') {
      _startStreaming();
    }
  }

  void _startStreaming() {
    final api = context.read<CoquiApiService>();
    setState(() => _streaming = true);

    _subscription = api
        .streamChildRunEvents(widget.sessionId, _run.id)
        .listen(
      _handleEvent,
      onError: (Object error) {
        if (!mounted) return;
        setState(() {
          _error = error.toString();
          _streaming = false;
        });
      },
      onDone: () {
        if (!mounted) return;
        setState(() => _streaming = false);
      },
    );
  }

  void _handleEvent(SseEvent event) {
    if (!mounted) return;

    switch (event.type) {
      case SseEventType.token:
        final text = event.tokenText;
        if (text != null && text.isNotEmpty) {
          setState(() => _output.write(text));
        }
        break;
      case SseEventType.done:
        setState(() {
          _run = CoquiChildRun.fromJson(event.data);
          _streaming = false;
        });
        break;
      case SseEventType.error:
        setState(() {
          _error = event.errorMessage;
          _streaming = false;
        });
        break;
      default:
        break;
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final liveText = _output.toString();
    final bodyText = liveText.isNotEmpty ? liveText : (_run.result ?? '');

    return Scaffold(
      appBar: AppBar(
        title: Text(_run.role),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _StatusPill(status: _run.status),
                  const SizedBox(width: 8),
                  if (_streaming)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                _run.model ?? 'inherit',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  _TokenCounter(label: 'Prompt', value: _run.promptTokens),
                  _TokenCounter(
                    label: 'Completion',
                    value: _run.completionTokens,
                  ),
                  _TokenCounter(label: 'Total', value: _run.totalTokens),
                ],
              ),
              const SizedBox(height: 16),
              Text('Prompt', style: theme.textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(_run.prompt, style: theme.textTheme.bodySmall),
              const SizedBox(height: 16),
              Text('Output', style: theme.textTheme.titleSmall),
              const SizedBox(height: 4),
              if (_error != null)
                Text(
                  _error!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              Expanded(
                child: SingleChildScrollView(
                  child: SelectableText(
                    bodyText.isEmpty
                        ? (_streaming ? 'Waiting for output…' : 'No output.')
                        : bodyText,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String status;

  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Text(
        status,
        style: theme.textTheme.labelMedium,
      ),
    );
  }
}

class _TokenCounter extends StatelessWidget {
  final String label;
  final int value;

  const _TokenCounter({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      '$label: $value',
      style: theme.textTheme.labelSmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}
