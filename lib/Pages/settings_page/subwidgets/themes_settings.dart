import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:coqui_app/Constants/constants.dart';
import 'package:coqui_app/Theme/theme.dart';

class ThemesSettings extends StatefulWidget {
  const ThemesSettings({super.key});

  @override
  State<ThemesSettings> createState() => _ThemesSettingsState();
}

class _ThemesSettingsState extends State<ThemesSettings> {
  final _settingsBox = Hive.box('settings');

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Themes',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: ShapeDecoration(
            shape: StadiumBorder(),
            color: Theme.of(context).colorScheme.primaryContainer,
          ),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: CircleAvatar(
                  backgroundImage: AssetImage(AppConstants.appIconPng),
                  radius: MediaQuery.of(context).textScaler.scale(16),
                ),
              ),
              Expanded(child: Text("Here is your current theme")),
              IconButton(
                icon: Icon(_brightnessIcon),
                iconSize: MediaQuery.of(context).textScaler.scale(24),
                onPressed: () {
                  setState(() => _toggleBrightness());
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildThemePreviewRow(context),
      ],
    );
  }

  void _toggleBrightness() {
    final currentBrightness = _settingsBox.get('brightness');
    // Brightness: 1 = light, 0 = dark, null = auto
    // Toggle between light, dark, and auto. 1 > 0 > null > 1 > ...
    final nb = currentBrightness == 1 ? 0 : (currentBrightness == 0 ? null : 1);
    _settingsBox.put('brightness', nb);
  }

  IconData get _brightnessIcon {
    final brightness = _settingsBox.get('brightness');
    if (brightness == null) return Icons.radio_button_off;
    return brightness == 1
        ? Icons.light_mode_outlined
        : Icons.dark_mode_outlined;
  }

  Widget _buildThemePreviewRow(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: colorScheme.primary,
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(CoquiColors.radiusMd),
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              'Primary',
              style: TextStyle(color: colorScheme.onPrimary, fontSize: 12),
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 48,
            color: colorScheme.tertiary,
            alignment: Alignment.center,
            child: Text(
              'Accent',
              style: TextStyle(color: colorScheme.onTertiary, fontSize: 12),
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 48,
            color: colorScheme.surface,
            alignment: Alignment.center,
            child: Text(
              'Surface',
              style: TextStyle(color: colorScheme.onSurface, fontSize: 12),
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: colorScheme.secondary,
              borderRadius: const BorderRadius.horizontal(
                right: Radius.circular(CoquiColors.radiusMd),
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              'Muted',
              style: TextStyle(color: colorScheme.onSecondary, fontSize: 12),
            ),
          ),
        ),
      ],
    );
  }
}
