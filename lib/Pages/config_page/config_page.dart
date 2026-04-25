import 'package:flutter/material.dart';

import 'package:coqui_app/Services/analytics_service.dart';

import 'subwidgets/subwidgets.dart';

/// Server credentials page.
class ConfigPage extends StatelessWidget {
  const ConfigPage({super.key});

  @override
  Widget build(BuildContext context) {
    AnalyticsService.trackEvent('credentials_page_opened');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Credentials'),
      ),
      body: const SafeArea(
        child: CredentialsEditor(),
      ),
    );
  }
}
