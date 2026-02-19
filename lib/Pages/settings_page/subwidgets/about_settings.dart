import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'dart:io' show Platform;

import 'package:coqui_app/Constants/constants.dart';
import 'package:coqui_app/Widgets/flexible_text.dart';

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
          leading: const Icon(Icons.info_outline),
          title: const Text('Version'),
          subtitle: Text(AppConstants.appVersion),
        ),
        ListTile(
          leading: const Icon(Icons.code),
          title: const Text('Source Code'),
          subtitle: const Text('View on GitHub'),
          onTap: () {
            launchUrlString(AppConstants.githubUrl);
          },
        ),
        ListTile(
          leading: const Icon(Icons.star),
          title: const Text('Give a Star on GitHub'),
          subtitle: const Text('Support the project'),
          onTap: () {
            launchUrlString(AppConstants.githubUrl);
          },
        ),
        if (Platform.isAndroid || Platform.isIOS)
          ListTile(
            leading: const Icon(Icons.desktop_mac_outlined),
            title: const Text('Try Desktop App'),
            subtitle: const Text('Available on Linux'),
            onTap: () {
              launchUrlString(AppConstants.githubUrl);
            },
          ),
        if (Platform.isMacOS || Platform.isLinux || Platform.isWindows)
          ListTile(
            leading: const Icon(Icons.phone_iphone_outlined),
            title: const Text('Try Mobile App'),
            subtitle: const Text('Coming soon'),
            onTap: () {
              launchUrlString(AppConstants.githubUrl);
            },
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 5,
          children: [
            const Icon(Icons.favorite, color: Colors.red, size: 16),
            FlexibleText(
              "Thanks for using ${AppConstants.appName}!",
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ],
    );
  }
}
