import 'package:flutter/material.dart';
import 'package:coqui_app/Constants/constants.dart';
import 'package:coqui_app/Providers/chat_provider.dart';
import 'package:coqui_app/Providers/instance_provider.dart';
import 'package:provider/provider.dart';
import 'package:responsive_framework/responsive_framework.dart';

import 'title_divider.dart';

class ChatDrawer extends StatelessWidget {
  const ChatDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    if (ResponsiveBreakpoints.of(context).isMobile) {
      return Drawer(
        child: SafeArea(
          child: Column(
            children: [
              Expanded(child: const ChatNavigationDrawer()),
              _buildSettingsButton(context),
            ],
          ),
        ),
      );
    } else {
      return SizedBox(
        width: 300,
        child: Column(
          children: [
            Expanded(child: const ChatNavigationDrawer()),
            _buildSettingsButton(context),
          ],
        ),
      );
    }
  }

  Widget _buildSettingsButton(BuildContext context) {
    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      child: IconButton(
        icon: const Icon(Icons.settings_outlined),
        onPressed: () {
          if (ResponsiveBreakpoints.of(context).isMobile) {
            Navigator.pop(context);
          }
          Navigator.pushNamed(context, '/settings');
        },
      ),
    );
  }
}

class ChatNavigationDrawer extends StatelessWidget {
  const ChatNavigationDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final instanceProvider = Provider.of<InstanceProvider>(context);
    final activeInstance = instanceProvider.activeInstance;

    return Consumer<ChatProvider>(
      builder: (context, chatProvider, _) {
        return NavigationDrawer(
          selectedIndex: chatProvider.selectedDestination,
          onDestinationSelected: (destination) {
            // First item is "New Chat" (index 0)
            chatProvider.destinationSelected(destination);

            if (ResponsiveBreakpoints.of(context).isMobile) {
              Navigator.pop(context);
            }
          },
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 16, 16, 10),
              child: Text(
                AppConstants.appName,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            NavigationDrawerDestination(
              icon: const Icon(Icons.add_circle_outline),
              selectedIcon: const Icon(Icons.add_circle),
              label: Text('New Chat'),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(28, 16, 28, 10),
              child: TitleDivider(title: "Sessions"),
            ),
            ...chatProvider.sessions.map((session) {
              // Status indicators
              final isStreaming = chatProvider.isSessionStreaming(session.id);
              final isThinking = chatProvider.isSessionThinking(session.id);
              final hasUnread = chatProvider.hasUnreadMessages(session.id);
              final hasError = chatProvider.hasSessionError(session.id);

              Widget? badge;
              if (hasError) {
                badge = const _StatusBadge(color: Colors.red);
              } else if (isThinking) {
                badge = const _StatusBadge(color: Colors.orange);
              } else if (hasUnread) {
                // Prioritize unread green over generic streaming indicator
                badge = const _StatusBadge(color: Colors.greenAccent);
              } else if (isStreaming) {
                badge = const _StatusBadge(color: Colors.greenAccent);
              }

              return NavigationDrawerDestination(
                icon: Stack(
                  children: [
                    const Icon(Icons.chat_bubble_outline),
                    if (badge != null)
                      Positioned(top: 0, left: 0, child: badge),
                  ],
                ),
                selectedIcon: Stack(
                  children: [
                    const Icon(Icons.chat_bubble),
                    if (badge != null)
                      Positioned(top: 0, left: 0, child: badge),
                  ],
                ),
                label: Expanded(
                  child: Text(
                    session.title ?? 'Untitled',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final Color color;

  const _StatusBadge({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
            color: Theme.of(context).colorScheme.surface, width: 1.5),
      ),
    );
  }
}
