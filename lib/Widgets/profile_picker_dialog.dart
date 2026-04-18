import 'package:flutter/material.dart';

Future<String?> showProfilePickerDialog({
  required BuildContext context,
  required String title,
  required Future<List<String>> Function() fetchProfiles,
  String? initialValue,
  bool allowClear = true,
}) async {
  final profiles = await fetchProfiles();
  if (!context.mounted) return null;

  final controller = TextEditingController(text: initialValue ?? '');
  final result = await showDialog<String>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(title),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: controller,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'profile name',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  if (profiles.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Known profiles',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: profiles
                          .map(
                            (profile) => ActionChip(
                              label: Text(profile),
                              onPressed: () {
                                controller.text = profile;
                                setState(() {});
                              },
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              if (allowClear)
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, ''),
                  child: const Text('Clear'),
                ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () =>
                    Navigator.pop(dialogContext, controller.text.trim()),
                child: const Text('Save'),
              ),
            ],
          );
        },
      );
    },
  );
  controller.dispose();
  return result;
}