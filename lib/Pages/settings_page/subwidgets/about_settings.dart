import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher_string.dart';

import 'package:coqui_app/Constants/constants.dart';
import 'package:coqui_app/Widgets/flexible_text.dart';

class AboutSettings extends StatelessWidget {
  const AboutSettings({super.key});

  @override
  Widget build(BuildContext context) {
    final mutedColor =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'About',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        ListTile(
          leading: const Icon(Icons.code),
          title: const Text('Source Code'),
          subtitle: const Text('View on GitHub'),
          onTap: () {
            launchUrlString(AppConstants.githubCoreUrl);
          },
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 5,
          children: [
            Icon(Icons.favorite, color: mutedColor, size: 16),
            FlexibleText(
              "Thanks for using ${AppConstants.appName}!",
              textAlign: TextAlign.center,
              style: TextStyle(color: mutedColor),
            ),
          ],
        ),
      ],
    );
  }
}
