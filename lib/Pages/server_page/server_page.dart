import 'package:flutter/material.dart';
import 'package:coqui_app/Models/local_server_state.dart';
import 'package:coqui_app/Providers/local_server_provider.dart';
import 'package:coqui_app/Services/analytics_service.dart';
import 'package:provider/provider.dart';

import 'subwidgets/subwidgets.dart';

/// Desktop server management page.
///
/// Wide two-panel layout: controls on the left, console/logs on the right.
class ServerPage extends StatefulWidget {
  const ServerPage({super.key});

  @override
  State<ServerPage> createState() => _ServerPageState();
}

class _ServerPageState extends State<ServerPage> {
  @override
  void initState() {
    super.initState();
    AnalyticsService.trackEvent('server_page_opened');

    // Refresh server state when the page opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<LocalServerProvider>(context, listen: false).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Local Server'),
        forceMaterialTransparency: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Left panel: controls ──
              Expanded(
                flex: 2,
                child: _buildControlPanel(),
              ),
              const SizedBox(width: 16),
              // ── Right panel: console ──
              Expanded(
                flex: 3,
                child: _buildConsolePanel(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControlPanel() {
    return Consumer<LocalServerProvider>(
      builder: (context, provider, _) {
        final info = provider.info;

        return ListView(
          children: [
            const ServerStatusHeader(),
            const SizedBox(height: 24),
            const InstallProgress(),
            if (!info.isBusy ||
                info.status == LocalServerStatus.starting ||
                info.status == LocalServerStatus.stopping)
              const ServerControls(),
            if (info.isInstalled) ...[
              const SizedBox(height: 24),
              const ServiceControls(),
              const SizedBox(height: 24),
              const ServerConfig(),
            ],
          ],
        );
      },
    );
  }

  Widget _buildConsolePanel() {
    return const ServerConsole();
  }
}
