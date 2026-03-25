import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:url_launcher/url_launcher_string.dart';

import 'package:coqui_app/Constants/constants.dart';
import 'package:coqui_app/Theme/theme.dart';

class HostedBanner extends StatefulWidget {
  const HostedBanner({super.key});

  @override
  State<HostedBanner> createState() => _HostedBannerState();
}

class _HostedBannerState extends State<HostedBanner> {
  static const _dismissedKey = 'hosted_banner_dismissed';

  final _settingsBox = Hive.box('settings');

  bool get _isDismissed => _settingsBox.get(_dismissedKey, defaultValue: false);

  void _dismiss() {
    _settingsBox.put(_dismissedKey, true);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_isDismissed) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final onSurface = colorScheme.onSurface;
    final borderRadius = BorderRadius.circular(CoquiColors.radiusMd);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colorScheme.surface, colorScheme.secondary],
        ),
        border: Border.all(
          color: colorScheme.tertiary,
          width: 1.0,
        ),
        borderRadius: borderRadius,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(CoquiColors.radiusMd),
                  child: Image.asset(
                    'assets/images/coqui-bot.png',
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Skip the setup. We\'ll host it.',
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Managed hosting with secure sandboxing, '
                        'full API access, and BYOK. Plans from \$15/mo.',
                        style: textTheme.bodySmall?.copyWith(
                          color: onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 32,
                  height: 32,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    iconSize: 18,
                    icon: Icon(
                      Icons.close,
                      color: onSurface.withValues(alpha: 0.35),
                    ),
                    onPressed: _dismiss,
                    tooltip: 'Dismiss',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: () {
                  launchUrlString(
                    '${AppConstants.hostedUrl}/pricing?utm_source=app&utm_medium=banner&utm_campaign=hosted',
                  );
                },
                child: const Text('Learn More'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
