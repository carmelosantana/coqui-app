import 'package:flutter/material.dart';

import 'package:coqui_app/Models/coqui_profile.dart';

Future<String?> showProfilePickerDialog({
  required BuildContext context,
  required String title,
  required Future<List<CoquiProfile>> Function() fetchProfiles,
  String? initialValue,
  bool allowClear = true,
}) async {
  final profiles = await fetchProfiles();
  if (!context.mounted) return null;

  final result = await showModalBottomSheet<String>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (sheetContext) {
      return SafeArea(
        minimum: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(sheetContext).textTheme.titleLarge),
            const SizedBox(height: 12),
            if (allowClear)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  initialValue == null || initialValue.isEmpty
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                ),
                title: const Text('No profile'),
                subtitle: const Text('Use the unprofiled session scope'),
                onTap: () => Navigator.pop(sheetContext, ''),
              ),
            Flexible(
              child: profiles.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text('No profiles discovered on this server.'),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: profiles.length,
                      itemBuilder: (context, index) {
                        final profile = profiles[index];
                        final isSelected = profile.name == initialValue;
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            isSelected
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                          ),
                          title: Row(
                            children: [
                              Expanded(child: Text(profile.label)),
                              if (profile.isDefault)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    'Default',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                        ),
                                  ),
                                ),
                            ],
                          ),
                          subtitle: profile.description.isNotEmpty
                              ? Text(profile.description)
                              : Text(profile.name),
                          onTap: () =>
                              Navigator.pop(sheetContext, profile.name),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pop(sheetContext),
                child: const Text('Cancel'),
              ),
            ),
          ],
        ),
      );
    },
  );
  return result;
}
