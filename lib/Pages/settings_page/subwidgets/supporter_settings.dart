import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher_string.dart';

import 'package:coqui_app/Platform/platform_info.dart';
import 'package:coqui_app/Providers/supporter_provider.dart';
import 'package:coqui_app/Theme/theme.dart';

/// Settings section for supporter perks and external support links.
class SupporterSettings extends StatelessWidget {
  const SupporterSettings({super.key});

  static const _sponsorUrl = 'https://github.com/sponsors/carmelosantana';

  @override
  Widget build(BuildContext context) {
    return Consumer<SupporterProvider>(
      builder: (context, supporter, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  supporter.isSupporter ? 'Perks' : 'Support',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                if (supporter.isSupporter) ...[
                  const SizedBox(width: 8),
                  const _SupporterBadge(),
                ],
              ],
            ),
            const SizedBox(height: 8),
            if (!supporter.isSupporter)
              _SupporterCta(supporter: supporter)
            else
              _SupporterPerks(supporter: supporter),
          ],
        );
      },
    );
  }
}

// ── Badge ──────────────────────────────────────────────────────────────────

class _SupporterBadge extends StatelessWidget {
  const _SupporterBadge();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(CoquiColors.radiusSm),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, size: 14, color: colorScheme.primary),
          const SizedBox(width: 4),
          Text(
            'Supporter',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

// ── Call to Action (not yet a supporter) ────────────────────────────────────

class _SupporterCta extends StatelessWidget {
  final SupporterProvider supporter;

  const _SupporterCta({required this.supporter});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colorScheme.surface, colorScheme.secondary],
        ),
        border: Border.all(color: colorScheme.outline),
        borderRadius: BorderRadius.circular(CoquiColors.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.favorite_rounded,
                  color: colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Support Open Source Development',
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Support Coqui via GitHub Sponsors. Native in-app supporter '
            'purchases are currently disabled while this flow is being redesigned.',
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 12),
          if (supporter.lastError != null) ...[
            Text(
              supporter.lastError!,
              style: textTheme.bodySmall?.copyWith(color: colorScheme.error),
            ),
            const SizedBox(height: 8),
          ],
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => launchUrlString(SupporterSettings._sponsorUrl),
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text('Support via GitHub Sponsors'),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Unlocked Perks ──────────────────────────────────────────────────────────

class _SupporterPerks extends StatelessWidget {
  final SupporterProvider supporter;

  const _SupporterPerks({required this.supporter});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ThemeSelector(supporter: supporter),
        if (PlatformInfo.isIOS) ...[
          const SizedBox(height: 16),
          _IconSelector(supporter: supporter),
        ],
      ],
    );
  }
}

// ── Theme selector ──────────────────────────────────────────────────────────

class _ThemeSelector extends StatelessWidget {
  final SupporterProvider supporter;

  const _ThemeSelector({required this.supporter});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final currentTheme = supporter.selectedTheme;

    final allThemes = [null, ...SupporterThemes.all.values];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Color Theme',
            style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        ...allThemes.map((palette) {
          final name = palette?.name;
          final label = palette?.label ?? 'Default';
          final isSelected = currentTheme == name;

          return _ThemeOptionTile(
            label: label,
            palette: palette,
            isSelected: isSelected,
            onTap: () => supporter.setTheme(name),
          );
        }),
      ],
    );
  }
}

class _ThemeOptionTile extends StatelessWidget {
  final String label;
  final SupporterThemePalette? palette;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeOptionTile({
    required this.label,
    required this.palette,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      leading: Icon(
        isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color: isSelected ? colorScheme.primary : null,
      ),
      title: Text(label),
      trailing: SizedBox(
        width: 120,
        height: 28,
        child: _ThemePreviewStrip(palette: palette),
      ),
      onTap: onTap,
    );
  }
}

class _ThemePreviewStrip extends StatelessWidget {
  final SupporterThemePalette? palette;

  const _ThemePreviewStrip({required this.palette});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final Color primary;
    final Color accent;
    final Color surface;
    final Color muted;

    if (palette != null) {
      primary = isDark ? palette!.darkPrimary : palette!.lightPrimary;
      accent = isDark ? palette!.darkAccent : palette!.lightAccent;
      surface = isDark ? palette!.darkSurface : palette!.lightSurface;
      muted = isDark ? palette!.darkMuted : palette!.lightMuted;
    } else {
      // Default Coqui palette
      primary = isDark ? CoquiColors.darkPrimary : CoquiColors.lightPrimary;
      accent = isDark ? CoquiColors.darkAccent : CoquiColors.lightAccent;
      surface =
          isDark ? CoquiColors.darkBackground : CoquiColors.lightBackground;
      muted = isDark ? CoquiColors.darkSecondary : CoquiColors.lightSecondary;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(CoquiColors.radiusSm),
      child: Row(
        children: [
          Expanded(child: Container(color: primary)),
          Expanded(child: Container(color: accent)),
          Expanded(child: Container(color: surface)),
          Expanded(child: Container(color: muted)),
        ],
      ),
    );
  }
}

// ── Icon selector (iOS only) ────────────────────────────────────────────────

class _IconSelector extends StatelessWidget {
  final SupporterProvider supporter;

  const _IconSelector({required this.supporter});

  static const _icons = [
    _AppIconOption(
        name: null, label: 'Default', asset: 'assets/images/coqui-icon.png'),
    _AppIconOption(
        name: 'CoquiBW',
        label: 'B\u0026W',
        asset: 'assets/images/coqui-bw-icon.png'),
    _AppIconOption(
        name: 'CoquiBot',
        label: 'Bot',
        asset: 'assets/images/coqui-bot-icon.png'),
  ];

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final currentIcon = supporter.selectedIcon;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('App Icon',
            style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: _icons.map((icon) {
            final isSelected = currentIcon == icon.name;
            return Padding(
              padding: const EdgeInsets.only(right: 12),
              child: GestureDetector(
                onTap: () => supporter.setIcon(icon.name),
                child: Column(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        borderRadius:
                            BorderRadius.circular(CoquiColors.radiusMd),
                        border: Border.all(
                          color: isSelected
                              ? colorScheme.primary
                              : colorScheme.outline,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius:
                            BorderRadius.circular(CoquiColors.radiusMd - 1),
                        child: Image.asset(icon.asset, fit: BoxFit.cover),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      icon.label,
                      style: textTheme.labelSmall?.copyWith(
                        color: isSelected
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _AppIconOption {
  final String? name;
  final String label;
  final String asset;

  const _AppIconOption({
    required this.name,
    required this.label,
    required this.asset,
  });
}
