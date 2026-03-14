import 'package:flutter/material.dart';

import 'package:coqui_app/Services/analytics_service.dart';

import 'subwidgets/subwidgets.dart';

/// Server configuration page with tabs for editing openclaw.json
/// and managing API key credentials.
class ConfigPage extends StatelessWidget {
  const ConfigPage({super.key});

  @override
  Widget build(BuildContext context) {
    AnalyticsService.trackEvent('config_page_opened');

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Configuration'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Config', icon: Icon(Icons.code)),
              Tab(text: 'Credentials', icon: Icon(Icons.key)),
            ],
          ),
        ),
        body: const SafeArea(
          child: TabBarView(
            children: [
              ConfigEditor(),
              CredentialsEditor(),
            ],
          ),
        ),
      ),
    );
  }
}
