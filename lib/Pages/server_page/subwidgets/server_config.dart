import 'package:flutter/material.dart';
import 'package:coqui_app/Providers/local_server_provider.dart';
import 'package:provider/provider.dart';

/// Port and host configuration for the local server.
class ServerConfig extends StatefulWidget {
  const ServerConfig({super.key});

  @override
  State<ServerConfig> createState() => _ServerConfigState();
}

class _ServerConfigState extends State<ServerConfig> {
  late final TextEditingController _portController;

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<LocalServerProvider>(context, listen: false);
    _portController = TextEditingController(text: '${provider.port}');
  }

  @override
  void dispose() {
    _portController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Configuration',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            SizedBox(
              width: 120,
              child: TextField(
                controller: _portController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Port',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Default: 3300. Change requires restart.',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Consumer<LocalServerProvider>(
          builder: (context, provider, _) {
            return Text(
              'Install path: ${provider.installPath}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            );
          },
        ),
      ],
    );
  }
}
