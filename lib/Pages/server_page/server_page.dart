import 'package:flutter/material.dart';
import 'package:coqui_app/Models/local_server_state.dart';
import 'package:coqui_app/Platform/platform_info.dart';
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
    if (!PlatformInfo.isManagedLocalServerSupported) {
      return const _ManualServerSetupPage();
    }

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
              const ServerConfig(),
              const SizedBox(height: 24),
              const ServerDangerZone(),
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

class _ManualServerSetupPage extends StatelessWidget {
  const _ManualServerSetupPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Local Server'),
        forceMaterialTransparency: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Manual Setup Required',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              'This app only manages a local Coqui server directly on macOS and Linux. '
              'On Windows, run Coqui manually through WSL2 or Docker, then connect to it as a normal server instance.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Recommended paths',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 8),
                    Text(
                        '1. Install Coqui in WSL2 and run `coqui-launcher --api-only`.'),
                    SizedBox(height: 6),
                    Text(
                        '2. Or run the Docker API workflow and expose port 3300 locally.'),
                    SizedBox(height: 6),
                    Text('3. Then add the server URL and API key in Settings.'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
