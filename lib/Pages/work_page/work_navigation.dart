import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:coqui_app/Providers/chat_provider.dart';
import 'package:coqui_app/Providers/project_provider.dart';

enum WorkPageTab { projects, sprints, todos, artifacts }

class WorkPageArguments {
  final WorkPageTab initialTab;
  final String? sessionId;
  final String? projectId;
  final String? sprintId;

  const WorkPageArguments({
    this.initialTab = WorkPageTab.projects,
    this.sessionId,
    this.projectId,
    this.sprintId,
  });

  Map<String, dynamic> toMap() {
    return {
      'initial_tab': initialTab.index,
      if (sessionId != null) 'session_id': sessionId,
      if (projectId != null) 'project_id': projectId,
      if (sprintId != null) 'sprint_id': sprintId,
    };
  }

  static WorkPageArguments? fromRouteArguments(Object? arguments) {
    if (arguments is WorkPageArguments) {
      return arguments;
    }

    if (arguments is Map) {
      final initialTabIndex = arguments['initial_tab'];
      final parsedTabIndex = initialTabIndex is int
          ? initialTabIndex
          : int.tryParse('$initialTabIndex') ?? 0;
      final tabIndex = parsedTabIndex < 0
          ? 0
          : parsedTabIndex >= WorkPageTab.values.length
              ? WorkPageTab.values.length - 1
              : parsedTabIndex;

      return WorkPageArguments(
        initialTab: WorkPageTab.values[tabIndex],
        sessionId: arguments['session_id'] as String?,
        projectId: arguments['project_id'] as String?,
        sprintId: arguments['sprint_id'] as String?,
      );
    }

    return null;
  }
}

WorkPageArguments workArgumentsForCurrentSession(
  BuildContext context, {
  required WorkPageTab initialTab,
  String? projectId,
  String? sprintId,
}) {
  final chatProvider = context.read<ChatProvider>();
  final projectProvider = context.read<ProjectProvider>();
  final session = chatProvider.currentSession;

  final resolvedProjectId = projectId ?? session?.activeProjectId;
  String? resolvedSprintId = sprintId;

  if (resolvedSprintId == null &&
      session != null &&
      resolvedProjectId != null &&
      resolvedProjectId.isNotEmpty) {
    final project = projectProvider.projectById(resolvedProjectId);
    final matchingSprint = projectProvider
        .sprintsForProject(resolvedProjectId)
        .where((item) => item.lastSessionId == session.id)
        .firstOrNull;

    resolvedSprintId = matchingSprint?.id ?? project?.activeSprintId;
  }

  return WorkPageArguments(
    initialTab: initialTab,
    sessionId: session?.id,
    projectId: resolvedProjectId,
    sprintId: resolvedSprintId,
  );
}

Future<void> openWorkPage(
  BuildContext context, {
  required WorkPageArguments arguments,
}) {
  Navigator.of(context).restorablePushNamed(
    '/work',
    arguments: arguments.toMap(),
  );
  return Future<void>.value();
}
