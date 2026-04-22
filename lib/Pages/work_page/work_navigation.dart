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
  return Navigator.pushNamed(
    context,
    '/work',
    arguments: arguments,
  );
}
