import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher_string.dart';

import 'package:coqui_app/Constants/constants.dart';

class AboutSettings extends StatelessWidget {
  const AboutSettings({super.key});

  @override
  Widget build(BuildContext context) {
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
      ],
    );
  }
}
