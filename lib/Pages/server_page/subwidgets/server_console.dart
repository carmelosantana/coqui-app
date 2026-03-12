import 'package:flutter/material.dart';
import 'package:coqui_app/Providers/local_server_provider.dart';
import 'package:provider/provider.dart';

/// Real-time scrolling console/log viewer for the local server.
class ServerConsole extends StatefulWidget {
  const ServerConsole({super.key});

  @override
  State<ServerConsole> createState() => _ServerConsoleState();
}

class _ServerConsoleState extends State<ServerConsole> {
  final _scrollController = ScrollController();
  int _lastLogLength = 0;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LocalServerProvider>(
      builder: (context, provider, _) {
        final logs = provider.logs;

        // Auto-scroll when new logs arrive
        if (logs.length != _lastLogLength) {
          _lastLogLength = logs.length;
          _scrollToBottom();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Console',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                if (logs.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18),
                    onPressed: provider.clearLogs,
                    tooltip: 'Clear logs',
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: logs.isEmpty
                    ? Center(
                        child: Text(
                          'No output yet. Start the server or run an '
                          'install to see logs here.',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.grey,
                                    fontFamily: 'GeistMono',
                                  ),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        itemCount: logs.length,
                        itemBuilder: (context, index) {
                          final line = logs[index];
                          final isError = line.startsWith('[stderr]');
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 1),
                            child: Text(
                              line,
                              style: TextStyle(
                                fontFamily: 'GeistMono',
                                fontSize: 12,
                                color: isError
                                    ? Colors.redAccent
                                    : Colors.grey.shade300,
                                height: 1.4,
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        );
      },
    );
  }
}
