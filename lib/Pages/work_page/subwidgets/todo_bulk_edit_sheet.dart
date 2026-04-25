import 'package:flutter/material.dart';

class TodoBulkEditResult {
  final String? priority;
  final String? status;
  final String? notes;

  const TodoBulkEditResult({
    this.priority,
    this.status,
    this.notes,
  });

  bool get hasChanges =>
      priority != null ||
      status != null ||
      (notes != null && notes!.isNotEmpty);
}

class TodoBulkEditSheet extends StatefulWidget {
  final int itemCount;

  const TodoBulkEditSheet({
    super.key,
    required this.itemCount,
  });

  @override
  State<TodoBulkEditSheet> createState() => _TodoBulkEditSheetState();
}

class _TodoBulkEditSheetState extends State<TodoBulkEditSheet> {
  final _notesController = TextEditingController();
  String? _priority;
  String? _status;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  void _apply() {
    final result = TodoBulkEditResult(
      priority: _priority,
      status: _status,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
    );

    if (!result.hasChanges) {
      Navigator.pop(context);
      return;
    }

    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.54,
        minChildSize: 0.4,
        maxChildSize: 0.82,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurfaceVariant
                        .withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bulk Edit Todos',
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Apply the same changes to ${widget.itemCount} selected todos.',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    FilledButton(
                      onPressed: _apply,
                      child: const Text('Apply'),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  children: [
                    DropdownButtonFormField<String?>(
                      initialValue: _status,
                      decoration: const InputDecoration(
                        labelText: 'Status',
                        helperText: 'Leave unset to keep each todo as-is.',
                      ),
                      items: const [
                        DropdownMenuItem<String?>(
                          value: null,
                          child: Text('No change'),
                        ),
                        DropdownMenuItem(
                          value: 'pending',
                          child: Text('Pending'),
                        ),
                        DropdownMenuItem(
                          value: 'in_progress',
                          child: Text('In Progress'),
                        ),
                        DropdownMenuItem(
                          value: 'completed',
                          child: Text('Completed'),
                        ),
                        DropdownMenuItem(
                          value: 'cancelled',
                          child: Text('Cancelled'),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() => _status = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String?>(
                      initialValue: _priority,
                      decoration: const InputDecoration(
                        labelText: 'Priority',
                        helperText:
                            'Leave unset to preserve each existing priority.',
                      ),
                      items: const [
                        DropdownMenuItem<String?>(
                          value: null,
                          child: Text('No change'),
                        ),
                        DropdownMenuItem(value: 'high', child: Text('High')),
                        DropdownMenuItem(
                          value: 'medium',
                          child: Text('Medium'),
                        ),
                        DropdownMenuItem(value: 'low', child: Text('Low')),
                      ],
                      onChanged: (value) {
                        setState(() => _priority = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _notesController,
                      minLines: 3,
                      maxLines: 6,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Shared Notes',
                        helperText:
                            'When provided, this overwrites the notes field on every selected todo.',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
