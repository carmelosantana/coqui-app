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

Future<List<String>?> showMultiProfilePickerDialog({
  required BuildContext context,
  required String title,
  required Future<List<CoquiProfile>> Function() fetchProfiles,
  List<String> initialValues = const [],
}) async {
  final profiles = await fetchProfiles();
  if (!context.mounted) return null;

  final result = await showModalBottomSheet<List<String>>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (sheetContext) {
      return _MultiProfilePickerSheet(
        title: title,
        profiles: profiles,
        initialValues: initialValues,
      );
    },
  );

  return result;
}

class _MultiProfilePickerSheet extends StatefulWidget {
  final String title;
  final List<CoquiProfile> profiles;
  final List<String> initialValues;

  const _MultiProfilePickerSheet({
    required this.title,
    required this.profiles,
    required this.initialValues,
  });

  @override
  State<_MultiProfilePickerSheet> createState() =>
      _MultiProfilePickerSheetState();
}

class _MultiProfilePickerSheetState extends State<_MultiProfilePickerSheet> {
  late final List<String> _selectedProfiles;

  @override
  void initState() {
    super.initState();
    _selectedProfiles = widget.initialValues
        .where((profile) => profile.isNotEmpty)
        .toList(growable: true);
  }

  void _toggleProfile(String profileName) {
    setState(() {
      if (_selectedProfiles.contains(profileName)) {
        _selectedProfiles.remove(profileName);
      } else {
        _selectedProfiles.add(profileName);
      }
    });
  }

  List<String> _selectionInDisplayOrder() {
    final selected = _selectedProfiles.toSet();
    return widget.profiles
        .where((profile) => selected.contains(profile.name))
        .map((profile) => profile.name)
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            _selectedProfiles.isEmpty
                ? 'No profiles selected'
                : '${_selectedProfiles.length} selected',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          Flexible(
            child: widget.profiles.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text('No profiles discovered on this server.'),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: widget.profiles.length,
                    itemBuilder: (context, index) {
                      final profile = widget.profiles[index];
                      final isSelected =
                          _selectedProfiles.contains(profile.name);
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          isSelected
                              ? Icons.check_box
                              : Icons.check_box_outline_blank,
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
                        onTap: () => _toggleProfile(profile.name),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () =>
                    Navigator.pop(context, _selectionInDisplayOrder()),
                child: const Text('Apply'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
