import 'package:flutter/material.dart';
import 'package:coqui_app/Models/coqui_session.dart';
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

import 'package:coqui_app/Pages/work_page/work_navigation.dart';

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
      final theme = Theme.of(context);
      final backgroundColor = theme.navigationDrawerTheme.backgroundColor ??
          theme.drawerTheme.backgroundColor ??
          theme.colorScheme.surface;
      final borderColor = theme.dividerColor;

      return Container(
        width: 300,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: const BorderRadius.only(
            bottomRight: Radius.circular(CoquiColors.radiusXl),
          ),
          border: Border(
            right: BorderSide(color: borderColor),
            bottom: BorderSide(color: borderColor),
          ),
        ),
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
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      child: SizedBox(
        height: 54,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildWorkButton(context),
              _buildTasksButton(context),
              _buildChannelsButton(context),
              _buildConfigButton(context),
              _buildInfoButton(context),
              _buildSettingsRailButton(context),
              if (PlatformInfo.isDesktop) _buildServerButton(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWorkButton(BuildContext context) {
    return Consumer<InstanceProvider>(
      builder: (context, instanceProvider, _) {
        final hasInstance = instanceProvider.hasActiveInstance;

        return _DrawerActionChip(
          icon: Icons.workspaces_outline,
          label: 'Work',
          enabled: hasInstance,
          onPressed: hasInstance
              ? () {
                  if (ResponsiveBreakpoints.of(context).isMobile) {
                    Navigator.pop(context);
                  }
                  openWorkPage(
                    context,
                    arguments: workArgumentsForCurrentSession(
                      context,
                      initialTab: WorkPageTab.projects,
                    ),
                  );
                }
              : null,
        );
      },
    );
  }

  Widget _buildSettingsRailButton(BuildContext context) {
    return _DrawerActionChip(
      icon: Icons.settings_outlined,
      label: 'Settings',
      onPressed: () {
        if (ResponsiveBreakpoints.of(context).isMobile) {
          Navigator.pop(context);
        }
        Navigator.pushNamed(context, '/settings');
      },
    );
  }

  Widget _buildInfoButton(BuildContext context) {
    return _DrawerActionChip(
      icon: Icons.text_snippet_outlined,
      label: 'Prompts',
      onPressed: () {
        if (ResponsiveBreakpoints.of(context).isMobile) {
          Navigator.pop(context);
        }
        Navigator.pushNamed(context, '/info');
      },
    );
  }

  Widget _buildTasksButton(BuildContext context) {
    return Consumer<TaskProvider>(
      builder: (context, taskProvider, _) {
        final hasActive = taskProvider.hasActiveTasks;
        return _DrawerActionChip(
          icon: Icons.task_outlined,
          label: 'Automation',
          badgeColor: hasActive ? CoquiColors.chart2 : null,
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

        return _DrawerActionChip(
          icon: Icons.satellite_alt_outlined,
          label: 'Channels',
          badgeColor: dotColor,
          enabled: hasInstance,
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

        return _DrawerActionChip(
          icon: Icons.key_outlined,
          label: 'Credentials',
          enabled: hasInstance,
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
      return _DrawerActionChip(
        icon: Icons.dns_outlined,
        label: 'Server',
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
            CoquiColors.warning,
          _ => null,
        };

        return _DrawerActionChip(
          icon: Icons.dns_outlined,
          label: 'Server',
          badgeColor: dotColor,
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
    final theme = Theme.of(context);

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
            const SizedBox(height: 12),
            NavigationDrawerDestination(
              icon: const Icon(Icons.add_circle_outline),
              selectedIcon: const Icon(Icons.add_circle),
              label: const Text('New Chat'),
            ),
            if (chatProvider.sessions.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.fromLTRB(28, 16, 28, 10),
                child: TitleDivider(title: 'Sessions'),
              ),
              ...chatProvider.sessions.map(
                (session) => _buildSessionDestination(
                  context,
                  chatProvider,
                  session,
                ),
              ),
            ],
            if (chatProvider.archivedSessions.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.fromLTRB(28, 16, 28, 10),
                child: TitleDivider(title: 'Archived'),
              ),
              ...chatProvider.archivedSessions.map(
                (session) => _buildSessionDestination(
                  context,
                  chatProvider,
                  session,
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  NavigationDrawerDestination _buildSessionDestination(
    BuildContext context,
    ChatProvider chatProvider,
    CoquiSession session,
  ) {
    final theme = Theme.of(context);
    final isLiveSession = !session.isReadOnly;
    final isStreaming =
        isLiveSession && chatProvider.isSessionStreaming(session.id);
    final isThinking =
        isLiveSession && chatProvider.isSessionThinking(session.id);
    final hasUnread =
        isLiveSession && chatProvider.hasUnreadMessages(session.id);
    final hasError = isLiveSession && chatProvider.hasSessionError(session.id);

    Widget? badge;
    if (hasError) {
      badge = _StatusBadge(color: theme.colorScheme.error);
    } else if (isThinking) {
      badge = const _StatusBadge(color: CoquiColors.chart1);
    } else if (hasUnread || isStreaming) {
      badge = const _StatusBadge(color: CoquiColors.chart2);
    }

    final statusIcon = session.isArchived
        ? Icon(
            Icons.archive_outlined,
            size: 16,
            color: theme.colorScheme.onSurfaceVariant,
          )
        : session.isClosed
            ? Icon(
                Icons.lock_outline,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              )
            : null;

    final subtitleParts = <String>[
      if (session.isGroupSession || session.profileLabel != null)
        session.compactParticipantSummary,
      if ((chatProvider.projectLabelForSession(session.id) ??
                  session.activeProjectId)
              ?.isNotEmpty ==
          true)
        chatProvider.projectLabelForSession(session.id) ??
            session.activeProjectId!,
      if (session.isArchived) 'Archived' else if (session.isClosed) 'Closed',
    ];
    final title = _sessionNavigationTitle(session);
    final originLabel = session.sessionOriginBadgeLabel;
    final channelLabel = session.channelBadgeLabel;
    final metaBadgeLabel = switch ((originLabel, channelLabel)) {
      (String origin, String channel) => '$origin · $channel',
      (String origin, null) => origin,
      (null, String channel) => channel,
      _ => null,
    };
    final subtitle = subtitleParts.join(' • ');

    return NavigationDrawerDestination(
      icon: Stack(
        children: [
          Icon(
            session.isGroupSession
                ? Icons.groups_2_outlined
                : Icons.chat_bubble_outline,
          ),
          if (badge != null) Positioned(top: 0, left: 0, child: badge),
        ],
      ),
      selectedIcon: Stack(
        children: [
          Icon(
            session.isGroupSession ? Icons.groups_2 : Icons.chat_bubble,
          ),
          if (badge != null) Positioned(top: 0, left: 0, child: badge),
        ],
      ),
      label: SizedBox(
        width: 184,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  fit: FlexFit.loose,
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (statusIcon != null) ...[
                  const SizedBox(width: 8),
                  statusIcon,
                ],
              ],
            ),
            if (metaBadgeLabel != null || subtitleParts.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  if (metaBadgeLabel != null)
                    Flexible(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: _SessionChannelBadge(label: metaBadgeLabel),
                      ),
                    ),
                  if (metaBadgeLabel != null && subtitleParts.isNotEmpty)
                    const SizedBox(width: 6),
                  if (subtitleParts.isNotEmpty)
                    Expanded(
                      child: Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
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

  static String _sessionNavigationTitle(CoquiSession session) {
    final title = session.title?.isNotEmpty == true
        ? session.title!
        : _sessionFallbackTitle(session.createdAt);

    if (session.isChannelOrigin && title.startsWith('Channel · ')) {
      return title.substring('Channel · '.length);
    }

    return title;
  }
}

class _SessionChannelBadge extends StatelessWidget {
  final String label;

  const _SessionChannelBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.satellite_alt_outlined,
            size: 12,
            color: theme.colorScheme.onSecondaryContainer,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSecondaryContainer,
              ),
            ),
          ),
        ],
      ),
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

class _DrawerActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final Color? badgeColor;
  final bool enabled;

  const _DrawerActionChip({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.badgeColor,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final foregroundColor = enabled
        ? colorScheme.onSurface
        : colorScheme.onSurface.withValues(alpha: 0.38);

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(999),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(icon, size: 18, color: foregroundColor),
                    if (badgeColor != null)
                      Positioned(
                        top: -1,
                        right: -3,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: badgeColor,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: colorScheme.surfaceContainerHighest,
                              width: 1,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: foregroundColor,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
