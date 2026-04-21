import 'package:flutter/material.dart';
import 'package:coqui_app/Constants/constants.dart';
import 'package:coqui_app/Models/local_server_state.dart';
import 'package:coqui_app/Platform/platform_info.dart';
import 'package:coqui_app/Providers/chat_provider.dart';
import 'package:coqui_app/Providers/channel_provider.dart';
import 'package:coqui_app/Providers/instance_provider.dart';
import 'package:coqui_app/Providers/local_server_provider.dart';
import 'package:coqui_app/Providers/task_provider.dart';
import 'package:coqui_app/Theme/coqui_colors.dart';
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
      return ClipRRect(
        borderRadius: const BorderRadius.only(
          bottomRight: Radius.circular(CoquiColors.radiusXl),
        ),
        child: SizedBox(
          width: 300,
          child: Column(
            children: [
              Expanded(child: const ChatNavigationDrawer()),
              _buildSettingsButton(context),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildSettingsButton(BuildContext context) {
    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () {
              if (ResponsiveBreakpoints.of(context).isMobile) {
                Navigator.pop(context);
              }
              Navigator.pushNamed(context, '/settings');
            },
          ),
          _buildTasksButton(context),
          _buildChannelsButton(context),
          _buildConfigButton(context),
          if (PlatformInfo.isDesktop) _buildServerButton(context),
        ],
      ),
    );
  }

  Widget _buildTasksButton(BuildContext context) {
    return Consumer<TaskProvider>(
      builder: (context, taskProvider, _) {
        final hasActive = taskProvider.hasActiveTasks;
        return IconButton(
          icon: Stack(
            children: [
              const Icon(Icons.task_outlined),
              if (hasActive)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: CoquiColors.chart2,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Theme.of(context).colorScheme.surface,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          tooltip: 'Background Tasks',
          onPressed: () {
            if (ResponsiveBreakpoints.of(context).isMobile) {
              Navigator.pop(context);
            }
            Navigator.pushNamed(context, '/tasks');
          },
        );
      },
    );
  }

  Widget _buildChannelsButton(BuildContext context) {
    return Consumer2<InstanceProvider, ChannelProvider>(
      builder: (context, instanceProvider, channelProvider, _) {
        final hasInstance = instanceProvider.hasActiveInstance;
        final dotColor = channelProvider.hasIssues
            ? Theme.of(context).colorScheme.error
            : channelProvider.hasHealthyChannels
                ? CoquiColors.chart2
                : null;

        return IconButton(
          icon: Stack(
            children: [
              const Icon(Icons.satellite_alt_outlined),
              if (dotColor != null)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: dotColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Theme.of(context).colorScheme.surface,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          tooltip: hasInstance ? 'Channels' : 'Connect to a server first',
          color: hasInstance
              ? null
              : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
          onPressed: hasInstance
              ? () {
                  if (ResponsiveBreakpoints.of(context).isMobile) {
                    Navigator.pop(context);
                  }
                  Navigator.pushNamed(context, '/channels');
                }
              : null,
        );
      },
    );
  }

  Widget _buildConfigButton(BuildContext context) {
    return Consumer<InstanceProvider>(
      builder: (context, instanceProvider, _) {
        final hasInstance = instanceProvider.hasActiveInstance;

        return IconButton(
          icon: const Icon(Icons.key_outlined),
          tooltip: hasInstance ? 'Credentials' : 'Connect to a server first',
          color: hasInstance
              ? null
              : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
          onPressed: hasInstance
              ? () {
                  if (ResponsiveBreakpoints.of(context).isMobile) {
                    Navigator.pop(context);
                  }
                  Navigator.pushNamed(context, '/config');
                }
              : null,
        );
      },
    );
  }

  Widget _buildServerButton(BuildContext context) {
    if (!PlatformInfo.isManagedLocalServerSupported) {
      return IconButton(
        icon: const Icon(Icons.dns_outlined),
        tooltip: 'Local Server',
        onPressed: () {
          if (ResponsiveBreakpoints.of(context).isMobile) {
            Navigator.pop(context);
          }
          Navigator.pushNamed(context, '/server');
        },
      );
    }

    return Consumer<LocalServerProvider>(
      builder: (context, provider, _) {
        final status = provider.info.status;
        final Color? dotColor = switch (status) {
          LocalServerStatus.running => CoquiColors.chart2,
          LocalServerStatus.error => Theme.of(context).colorScheme.error,
          LocalServerStatus.starting ||
          LocalServerStatus.stopping ||
          LocalServerStatus.installing ||
          LocalServerStatus.updating ||
          LocalServerStatus.uninstalling =>
            Colors.orange,
          _ => null,
        };

        return IconButton(
          icon: Stack(
            children: [
              const Icon(Icons.dns_outlined),
              if (dotColor != null)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: dotColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Theme.of(context).colorScheme.surface,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          onPressed: () {
            if (ResponsiveBreakpoints.of(context).isMobile) {
              Navigator.pop(context);
            }
            Navigator.pushNamed(context, '/server');
          },
        );
      },
    );
  }
}

class ChatNavigationDrawer extends StatelessWidget {
  const ChatNavigationDrawer({super.key});

  @override
  Widget build(BuildContext context) {
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
                badge =
                    _StatusBadge(color: Theme.of(context).colorScheme.error);
              } else if (isThinking) {
                badge = const _StatusBadge(color: CoquiColors.chart1);
              } else if (hasUnread) {
                badge = const _StatusBadge(color: CoquiColors.chart2);
              } else if (isStreaming) {
                badge = const _StatusBadge(color: CoquiColors.chart2);
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
                    session.title?.isNotEmpty == true
                        ? session.title!
                        : _sessionFallbackTitle(session.createdAt),
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

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static String _sessionFallbackTitle(DateTime createdAt) {
    return 'Chat · ${_months[createdAt.month - 1]} ${createdAt.day}';
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
