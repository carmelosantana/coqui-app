import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:coqui_app/Models/coqui_artifact.dart';
import 'package:coqui_app/Models/coqui_project.dart';
import 'package:coqui_app/Models/coqui_sprint.dart';
import 'package:coqui_app/Models/coqui_todo.dart';
import 'package:coqui_app/Models/coqui_todo_stats.dart';
import 'package:coqui_app/Providers/chat_provider.dart';
import 'package:coqui_app/Providers/instance_provider.dart';
import 'package:coqui_app/Providers/project_provider.dart';
import 'package:coqui_app/Providers/work_provider.dart';
import 'package:coqui_app/Widgets/selection_bottom_sheet.dart';

import 'subwidgets/subwidgets.dart';
import 'work_navigation.dart';

class WorkPage extends StatefulWidget {
  final WorkPageArguments? arguments;

  const WorkPage({super.key, this.arguments});

  @override
  State<WorkPage> createState() => _WorkPageState();
}

class _WorkPageState extends State<WorkPage>
    with SingleTickerProviderStateMixin, RestorationMixin {
  late final TabController _tabController;
  late final RestorableInt _restoredTabIndex;
  late final RestorableStringN _restoredSessionId;
  late final RestorableStringN _restoredProjectId;
  late final RestorableStringN _restoredSprintId;
  late final RestorableStringN _restoredProjectStatusFilter;
  late final RestorableStringN _restoredSprintStatusFilter;
  late final RestorableStringN _restoredTodoStatusFilter;
  late final RestorableStringN _restoredArtifactStageFilter;
  String? _projectStatusFilter;
  String? _sprintStatusFilter;
  String? _todoStatusFilter;
  String? _artifactStageFilter;
  String? _selectedProjectId;
  String? _selectedSprintId;
  String? _lastSessionId;
  bool _todoSelectionMode = false;
  bool _todoReorderMode = false;
  final Set<String> _selectedTodoIds = <String>{};

  static const _projectFilters = [
    (label: 'All', value: null),
    (label: 'Active', value: 'active'),
    (label: 'Completed', value: 'completed'),
    (label: 'Archived', value: 'archived'),
  ];

  static const _sprintFilters = [
    (label: 'All', value: null),
    (label: 'Planned', value: 'planned'),
    (label: 'In Progress', value: 'in_progress'),
    (label: 'Review', value: 'review'),
    (label: 'Complete', value: 'complete'),
    (label: 'Rejected', value: 'rejected'),
  ];

  static const _todoFilters = [
    (label: 'All', value: null),
    (label: 'Pending', value: 'pending'),
    (label: 'In Progress', value: 'in_progress'),
    (label: 'Completed', value: 'completed'),
    (label: 'Cancelled', value: 'cancelled'),
  ];

  static const _artifactFilters = [
    (label: 'All', value: null),
    (label: 'Draft', value: 'draft'),
    (label: 'Review', value: 'review'),
    (label: 'Final', value: 'final'),
  ];

  @override
  void initState() {
    super.initState();
    _restoredTabIndex = RestorableInt(widget.arguments?.initialTab.index ?? 0);
    _restoredSessionId = RestorableStringN(widget.arguments?.sessionId);
    _restoredProjectId = RestorableStringN(widget.arguments?.projectId);
    _restoredSprintId = RestorableStringN(widget.arguments?.sprintId);
    _restoredProjectStatusFilter = RestorableStringN(null);
    _restoredSprintStatusFilter = RestorableStringN(null);
    _restoredTodoStatusFilter = RestorableStringN(null);
    _restoredArtifactStageFilter = RestorableStringN(null);
    _selectedProjectId = _restoredProjectId.value;
    _selectedSprintId = _restoredSprintId.value;
    _projectStatusFilter = _restoredProjectStatusFilter.value;
    _sprintStatusFilter = _restoredSprintStatusFilter.value;
    _todoStatusFilter = _restoredTodoStatusFilter.value;
    _artifactStageFilter = _restoredArtifactStageFilter.value;

    _tabController =
        TabController(length: WorkPageTab.values.length, vsync: this)
          ..addListener(() {
            if (!_tabController.indexIsChanging) {
              _restoredTabIndex.value = _tabController.index;
              setState(() {});
            }
          });

    _tabController.index = _restoredTabIndex.value;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final chatProvider = context.read<ChatProvider>();
      final provider = context.read<ProjectProvider>();
      await _applyInitialNavigation(provider, chatProvider);
      if (!mounted) return;
      await provider.fetchProjects();
      if (!mounted) return;
      _syncSelectedProject(provider);
      final selectedProjectId = _selectedProjectId;
      if (selectedProjectId != null) {
        await provider.fetchProjectSprints(selectedProjectId);
        if (mounted) {
          _syncSelectedSprint(provider,
              preferredSprintId: widget.arguments?.sprintId);
        }
      }
    });
  }

  @override
  String? get restorationId => 'work_page';

  @override
  void restoreState(RestorationBucket? oldBucket, bool initialRestore) {
    registerForRestoration(_restoredTabIndex, 'work_tab_index');
    registerForRestoration(_restoredSessionId, 'work_session_id');
    registerForRestoration(_restoredProjectId, 'work_project_id');
    registerForRestoration(_restoredSprintId, 'work_sprint_id');
    registerForRestoration(
      _restoredProjectStatusFilter,
      'work_project_status_filter',
    );
    registerForRestoration(
      _restoredSprintStatusFilter,
      'work_sprint_status_filter',
    );
    registerForRestoration(
        _restoredTodoStatusFilter, 'work_todo_status_filter');
    registerForRestoration(
      _restoredArtifactStageFilter,
      'work_artifact_stage_filter',
    );

    _tabController.index = _restoredTabIndex.value.clamp(
      0,
      WorkPageTab.values.length - 1,
    );
    _selectedProjectId = _restoredProjectId.value;
    _selectedSprintId = _restoredSprintId.value;
    _projectStatusFilter = _restoredProjectStatusFilter.value;
    _sprintStatusFilter = _restoredSprintStatusFilter.value;
    _todoStatusFilter = _restoredTodoStatusFilter.value;
    _artifactStageFilter = _restoredArtifactStageFilter.value;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _restoredTabIndex.dispose();
    _restoredSessionId.dispose();
    _restoredProjectId.dispose();
    _restoredSprintId.dispose();
    _restoredProjectStatusFilter.dispose();
    _restoredSprintStatusFilter.dispose();
    _restoredTodoStatusFilter.dispose();
    _restoredArtifactStageFilter.dispose();
    super.dispose();
  }

  WorkPageTab get _activeTab => WorkPageTab.values[_tabController.index];

  Future<void> _applyInitialNavigation(
    ProjectProvider provider,
    ChatProvider chatProvider,
  ) async {
    final targetSessionId = _restoredSessionId.value;
    if (targetSessionId != null &&
        targetSessionId.isNotEmpty &&
        chatProvider.currentSession?.id != targetSessionId) {
      chatProvider.openSession(targetSessionId);
    }

    String? targetProjectId = _restoredProjectId.value;
    final targetSprintId = _restoredSprintId.value;

    if ((targetProjectId == null || targetProjectId.isEmpty) &&
        targetSprintId != null &&
        targetSprintId.isNotEmpty) {
      final sprint = await provider.loadSprintDetail(targetSprintId);
      if (!mounted) {
        return;
      }
      targetProjectId = sprint?.projectId;
      if (sprint != null) {
        setState(() {
          _setSelectedProjectId(sprint.projectId);
          _setSelectedSprintId(sprint.id);
        });
      }
    }

    if (targetProjectId != null && targetProjectId.isNotEmpty) {
      await provider.fetchProjects(silent: true);
      if (!mounted) {
        return;
      }
      final resolvedProject = provider.projectById(targetProjectId);
      if (resolvedProject != null) {
        setState(() => _setSelectedProjectId(resolvedProject.id));
      }
    }
  }

  void _setSelectedProjectId(String? value) {
    _selectedProjectId = value;
    _restoredProjectId.value = value;
  }

  void _setSelectedSprintId(String? value) {
    _selectedSprintId = value;
    _restoredSprintId.value = value;
  }

  void _setProjectStatusFilter(String? value) {
    _projectStatusFilter = value;
    _restoredProjectStatusFilter.value = value;
  }

  void _setSprintStatusFilter(String? value) {
    _sprintStatusFilter = value;
    _restoredSprintStatusFilter.value = value;
  }

  void _setTodoStatusFilter(String? value) {
    _todoStatusFilter = value;
    _restoredTodoStatusFilter.value = value;
  }

  void _setArtifactStageFilter(String? value) {
    _artifactStageFilter = value;
    _restoredArtifactStageFilter.value = value;
  }

  void _ensureSessionScopedData(
    ChatProvider chatProvider,
    WorkProvider workProvider,
  ) {
    final sessionId = chatProvider.currentSession?.id;
    if (_lastSessionId == sessionId) {
      return;
    }

    _lastSessionId = sessionId;
    _restoredSessionId.value = sessionId;
    if (sessionId == null) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(workProvider.fetchTodos(sessionId, force: true));
      unawaited(workProvider.fetchArtifacts(sessionId, force: true));
    });
  }

  void _syncSelectedProject(ProjectProvider provider) {
    final currentSessionProjectId =
        context.read<ChatProvider>().currentSession?.activeProjectId;
    if (_selectedProjectId != null &&
        provider.projectById(_selectedProjectId!) != null) {
      return;
    }
    if (currentSessionProjectId != null &&
        provider.projectById(currentSessionProjectId) != null) {
      setState(() => _setSelectedProjectId(currentSessionProjectId));
      return;
    }
    if (provider.projects.isNotEmpty) {
      setState(() => _setSelectedProjectId(provider.projects.first.id));
    }
  }

  void _syncSelectedSprint(
    ProjectProvider provider, {
    String? preferredSprintId,
  }) {
    final projectId = _selectedProjectId;
    if (projectId == null) {
      if (_selectedSprintId != null) {
        setState(() => _setSelectedSprintId(null));
      }
      return;
    }

    final sprints = provider.sprintsForProject(projectId);
    if (_selectedSprintId != null &&
        sprints.any((item) => item.id == _selectedSprintId)) {
      return;
    }

    if (preferredSprintId != null &&
        sprints.any((item) => item.id == preferredSprintId)) {
      setState(() => _setSelectedSprintId(preferredSprintId));
      return;
    }

    final activeSprintId = provider.projectById(projectId)?.activeSprintId;
    final nextSprintId = activeSprintId != null &&
            sprints.any((item) => item.id == activeSprintId)
        ? activeSprintId
        : null;

    if (_selectedSprintId != nextSprintId) {
      setState(() => _setSelectedSprintId(nextSprintId));
    }
  }

  List<CoquiProject> _visibleProjects(ProjectProvider provider) {
    return provider.projects.where((project) {
      if (_projectStatusFilter == null) return true;
      return project.status == _projectStatusFilter;
    }).toList();
  }

  List<CoquiSprint> _visibleSprints(ProjectProvider provider) {
    final projectId = _selectedProjectId;
    if (projectId == null) return const [];
    return provider.sprintsForProject(projectId).where((sprint) {
      if (_sprintStatusFilter == null) return true;
      return sprint.status == _sprintStatusFilter;
    }).toList();
  }

  List<CoquiTodo> _visibleTodos(
    WorkProvider provider,
    String sessionId,
  ) {
    return provider.todosForSession(sessionId).where((todo) {
      if (_todoStatusFilter != null && todo.status != _todoStatusFilter) {
        return false;
      }
      if (_selectedSprintId != null && todo.sprintId != _selectedSprintId) {
        return false;
      }
      return true;
    }).toList();
  }

  List<CoquiArtifact> _visibleArtifacts(
    WorkProvider provider,
    String sessionId,
  ) {
    return provider.artifactsForSession(sessionId).where((artifact) {
      if (_artifactStageFilter != null &&
          artifact.stage != _artifactStageFilter) {
        return false;
      }
      if (_selectedProjectId != null &&
          artifact.projectId != _selectedProjectId) {
        return false;
      }
      if (_selectedSprintId != null && artifact.sprintId != _selectedSprintId) {
        return false;
      }
      return true;
    }).toList();
  }

  Future<void> _refreshCurrentTab() async {
    final projectProvider = context.read<ProjectProvider>();
    final workProvider = context.read<WorkProvider>();
    final sessionId = context.read<ChatProvider>().currentSession?.id;

    switch (_activeTab) {
      case WorkPageTab.projects:
        await projectProvider.fetchProjects();
        _syncSelectedProject(projectProvider);
      case WorkPageTab.sprints:
        final projectId = _selectedProjectId;
        if (projectId != null) {
          await projectProvider.fetchProjectSprints(projectId, force: true);
          await projectProvider.loadProjectDetail(projectId, force: true);
          if (mounted) {
            _syncSelectedSprint(projectProvider);
          }
        }
      case WorkPageTab.todos:
        if (sessionId != null) {
          await workProvider.fetchTodos(sessionId, force: true);
        }
      case WorkPageTab.artifacts:
        if (sessionId != null) {
          await workProvider.fetchArtifacts(sessionId, force: true);
        }
    }
  }

  Future<void> _openCreate() async {
    final chatProvider = context.read<ChatProvider>();

    switch (_activeTab) {
      case WorkPageTab.projects:
        await _openProjectEditor();
      case WorkPageTab.sprints:
        final projectId = _selectedProjectId;
        if (projectId == null) {
          _showSnack('Choose a project first');
          return;
        }
        await _openSprintEditor(projectId: projectId);
      case WorkPageTab.todos:
        final sessionId = chatProvider.currentSession?.id;
        if (sessionId == null) {
          _showSnack('Open a chat session first');
          return;
        }
        if (chatProvider.isCurrentSessionReadOnly) {
          _showSnack('This chat session is read only');
          return;
        }
        await _openTodoEditor(sessionId: sessionId);
      case WorkPageTab.artifacts:
        final sessionId = chatProvider.currentSession?.id;
        if (sessionId == null) {
          _showSnack('Open a chat session first');
          return;
        }
        if (chatProvider.isCurrentSessionReadOnly) {
          _showSnack('This chat session is read only');
          return;
        }
        await _openArtifactEditor(sessionId: sessionId);
    }
  }

  Future<void> _openProjectEditor({CoquiProject? project}) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<ProjectProvider>(),
        child: ProjectEditorSheet(project: project),
      ),
    );

    if (!mounted) return;
    final provider = context.read<ProjectProvider>();
    await provider.fetchProjects();
    _syncSelectedProject(provider);
  }

  Future<void> _openSprintEditor({
    required String projectId,
    CoquiSprint? sprint,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<ProjectProvider>(),
        child: SprintEditorSheet(
          projectId: projectId,
          sprint: sprint,
          suggestedSessionId: context.read<ChatProvider>().currentSession?.id,
        ),
      ),
    );

    if (!mounted) return;
    await context
        .read<ProjectProvider>()
        .fetchProjectSprints(projectId, force: true);
    if (mounted) {
      _syncSelectedSprint(context.read<ProjectProvider>());
    }
  }

  Future<void> _openTodoEditor({
    required String sessionId,
    CoquiTodo? todo,
    String? initialParentId,
    String? initialArtifactId,
    String? initialSprintId,
  }) async {
    final projectProvider = context.read<ProjectProvider>();
    final workProvider = context.read<WorkProvider>();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => ChangeNotifierProvider.value(
        value: workProvider,
        child: TodoEditorSheet(
          sessionId: sessionId,
          todo: todo,
          availableTodos: _availableParentTodos(
            provider: workProvider,
            sessionId: sessionId,
            currentTodo: todo,
          ),
          availableSprints: _selectedProjectId == null
              ? const []
              : projectProvider.sprintsForProject(_selectedProjectId!),
          availableArtifacts: workProvider.artifactsForSession(sessionId),
          initialSprintId:
              todo?.sprintId ?? initialSprintId ?? _selectedSprintId,
          initialParentId: initialParentId,
          initialArtifactId: initialArtifactId,
        ),
      ),
    );
  }

  List<CoquiTodo> _availableParentTodos({
    required WorkProvider provider,
    required String sessionId,
    CoquiTodo? currentTodo,
  }) {
    final excludedIds = <String>{};
    if (currentTodo != null) {
      excludedIds
        ..add(currentTodo.id)
        ..addAll(_descendantTodoIds(currentTodo));
    }

    return provider.todosForSession(sessionId).where((todo) {
      return !excludedIds.contains(todo.id);
    }).toList();
  }

  Set<String> _descendantTodoIds(CoquiTodo todo) {
    final descendants = <String>{};

    void visit(CoquiTodo item) {
      for (final child in item.subtasks) {
        descendants.add(child.id);
        visit(child);
      }
    }

    visit(todo);
    return descendants;
  }

  Future<void> _openArtifactEditor({
    required String sessionId,
    CoquiArtifact? artifact,
  }) async {
    final projectProvider = context.read<ProjectProvider>();
    final workProvider = context.read<WorkProvider>();
    final initialProjectId = artifact?.projectId ??
        _selectedProjectId ??
        context.read<ChatProvider>().currentSession?.activeProjectId;
    final initialSprintId = artifact?.sprintId ?? _selectedSprintId;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => ChangeNotifierProvider.value(
        value: workProvider,
        child: ArtifactEditorSheet(
          sessionId: sessionId,
          artifact: artifact,
          availableProjects: projectProvider.projects,
          availableSprints: initialProjectId == null
              ? const []
              : projectProvider.sprintsForProject(initialProjectId),
          initialProjectId: initialProjectId,
          initialSprintId: initialSprintId,
        ),
      ),
    );
  }

  Future<void> _openProjectPicker(ProjectProvider provider) async {
    final selected = await showSelectionBottomSheet<CoquiProject>(
      context: context,
      header: const Text('Project'),
      fetchItems: () async => provider.projects,
      currentSelection: provider.projectById(_selectedProjectId ?? ''),
      itemBuilder: (project, selected, onSelected) {
        return ListTile(
          leading: Icon(
            selected
                ? Icons.radio_button_checked
                : Icons.radio_button_unchecked,
          ),
          onTap: () => onSelected(project),
          title: Text(project.label),
          subtitle: project.hasDescription
              ? Text(
                  project.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                )
              : null,
          trailing: ProjectStatusBadge(project: project),
        );
      },
    );

    if (!mounted || selected == null) return;
    setState(() {
      _setSelectedProjectId(selected.id);
      _setSelectedSprintId(null);
    });
    await provider.fetchProjectSprints(selected.id, force: true);
    if (mounted) {
      _syncSelectedSprint(provider);
    }
  }

  Future<void> _openSprintPicker(ProjectProvider provider) async {
    final projectId = _selectedProjectId;
    if (projectId == null) {
      _showSnack('Choose a project first');
      return;
    }

    await provider.fetchProjectSprints(projectId, force: true);
    if (!mounted) return;
    final sprints = provider.sprintsForProject(projectId);
    final selected = await showSelectionBottomSheet<CoquiSprint>(
      context: context,
      header: const Text('Sprint'),
      fetchItems: () async => sprints,
      currentSelection: _selectedSprintId == null
          ? null
          : provider.sprintById(_selectedSprintId!),
      itemBuilder: (sprint, selected, onSelected) {
        return ListTile(
          leading: Icon(
            selected
                ? Icons.radio_button_checked
                : Icons.radio_button_unchecked,
          ),
          onTap: () => onSelected(sprint),
          title: Text(sprint.label),
          trailing: SprintStatusBadge(sprint: sprint),
        );
      },
    );

    if (!mounted) return;
    setState(() => _setSelectedSprintId(selected?.id));
  }

  Future<void> _completeSelectedTodos(String sessionId) async {
    if (_selectedTodoIds.isEmpty) {
      return;
    }

    final provider = context.read<WorkProvider>();
    final updatedCount = await provider.bulkUpdateTodos(
      sessionId,
      todoIds: _selectedTodoIds.toList(growable: false),
      status: 'completed',
    );

    if (!mounted) {
      return;
    }

    if (updatedCount > 0) {
      _showSnack('Completed $updatedCount todos');
      setState(() {
        _selectedTodoIds.clear();
        _todoSelectionMode = false;
      });
      return;
    }

    _showSnack(provider.error ?? 'Unable to complete todos');
    provider.clearError();
  }

  Future<void> _deleteSelectedTodos(String sessionId) async {
    if (_selectedTodoIds.isEmpty) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete selected todos?'),
        content: Text(
          'This removes ${_selectedTodoIds.length} selected todos. Parent deletions also remove their subtasks.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    final provider = context.read<WorkProvider>();
    final deletedCount = await provider.bulkDeleteTodos(
      sessionId,
      todoIds: _selectedTodoIds.toList(growable: false),
    );

    if (!mounted) {
      return;
    }

    if (deletedCount > 0) {
      _showSnack('Deleted $deletedCount todos');
      setState(() {
        _selectedTodoIds.clear();
        _todoSelectionMode = false;
      });
      return;
    }

    _showSnack(provider.error ?? 'Unable to delete selected todos');
    provider.clearError();
  }

  void _openProjectDetail(CoquiProject project) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<ProjectProvider>(),
        child: ProjectDetailSheet(project: project),
      ),
    );
  }

  void _openSprintDetail(CoquiSprint sprint) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<ProjectProvider>(),
        child: SprintDetailSheet(sprint: sprint),
      ),
    );
  }

  void _openArtifactDetail(
    String sessionId,
    CoquiArtifact artifact,
    bool readOnly,
  ) {
    final projectProvider = context.read<ProjectProvider>();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<WorkProvider>(),
        child: ArtifactDetailSheet(
          sessionId: sessionId,
          artifact: artifact,
          availableProjects: projectProvider.projects,
          availableSprints: (artifact.projectId ?? _selectedProjectId) == null
              ? const []
              : projectProvider.sprintsForProject(
                  artifact.projectId ?? _selectedProjectId!,
                ),
          readOnly: readOnly,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = context.watch<ChatProvider>();
    _ensureSessionScopedData(chatProvider, context.read<WorkProvider>());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Work'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Projects', icon: Icon(Icons.folder_outlined)),
            Tab(text: 'Sprints', icon: Icon(Icons.flag_outlined)),
            Tab(text: 'Todos', icon: Icon(Icons.checklist_outlined)),
            Tab(text: 'Artifacts', icon: Icon(Icons.description_outlined)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _refreshCurrentTab,
          ),
        ],
      ),
      floatingActionButton: _buildFloatingActionButton(chatProvider),
      body: SafeArea(
        child: Column(
          children: [
            _WorkContextCard(
              selectedProjectId: _selectedProjectId,
              selectedSprintId: _selectedSprintId,
              onUseChatProject: () async {
                final projectId = chatProvider.currentSession?.activeProjectId;
                if (projectId == null || projectId.isEmpty) return;
                final projectProvider = context.read<ProjectProvider>();
                setState(() {
                  _setSelectedProjectId(projectId);
                  _setSelectedSprintId(null);
                });
                await projectProvider.fetchProjectSprints(projectId,
                    force: true);
                if (mounted) {
                  _syncSelectedSprint(projectProvider);
                }
              },
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildProjectsTab(),
                  _buildSprintsTab(),
                  _buildTodosTab(),
                  _buildArtifactsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget? _buildFloatingActionButton(ChatProvider chatProvider) {
    switch (_activeTab) {
      case WorkPageTab.projects:
        return FloatingActionButton.extended(
          onPressed: _openCreate,
          icon: const Icon(Icons.create_new_folder_outlined),
          label: const Text('New Project'),
        );
      case WorkPageTab.sprints:
        return FloatingActionButton.extended(
          onPressed: _openCreate,
          icon: const Icon(Icons.add_task_outlined),
          label: const Text('New Sprint'),
        );
      case WorkPageTab.todos:
        return chatProvider.currentSession == null ||
                chatProvider.isCurrentSessionReadOnly
            ? null
            : FloatingActionButton.extended(
                onPressed: _openCreate,
                icon: const Icon(Icons.add_task_outlined),
                label: const Text('New Todo'),
              );
      case WorkPageTab.artifacts:
        return chatProvider.currentSession == null ||
                chatProvider.isCurrentSessionReadOnly
            ? null
            : FloatingActionButton.extended(
                onPressed: _openCreate,
                icon: const Icon(Icons.note_add_outlined),
                label: const Text('New Artifact'),
              );
    }
  }

  Widget _buildProjectsTab() {
    return Consumer2<InstanceProvider, ProjectProvider>(
      builder: (context, instanceProvider, provider, _) {
        final visibleProjects = _visibleProjects(provider);

        if (!instanceProvider.hasActiveInstance) {
          return const _EmptyState(
            icon: Icons.workspaces_outline,
            title: 'Connect to a server',
            message: 'Work management needs an active Coqui API server.',
          );
        }

        if (provider.isLoading && provider.projects.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (provider.error != null && provider.projects.isEmpty) {
          return _ErrorView(
            title: 'Could not load projects',
            error: provider.error!,
            onRetry: provider.fetchProjects,
          );
        }

        if (provider.projects.isNotEmpty && _selectedProjectId == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _syncSelectedProject(provider);
            }
          });
        }

        return Column(
          children: [
            _FilterChips(
              selected: _projectStatusFilter,
              filters: _projectFilters,
              onSelected: (value) {
                setState(() => _setProjectStatusFilter(value as String?));
              },
            ),
            Expanded(
              child: visibleProjects.isEmpty
                  ? const _EmptyState(
                      icon: Icons.folder_outlined,
                      title: 'No projects yet',
                      message:
                          'Create a project first so sprint planning and session work can link to a stable home.',
                    )
                  : RefreshIndicator(
                      onRefresh: provider.fetchProjects,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                        children: [
                          _ProjectStatsRow(provider: provider),
                          const SizedBox(height: 16),
                          ...visibleProjects.map(
                            (project) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _ProjectCard(
                                project: project,
                                isSelected: _selectedProjectId == project.id,
                                onTap: () => _openProjectDetail(project),
                                onSelect: () async {
                                  setState(() {
                                    _setSelectedProjectId(project.id);
                                    _setSelectedSprintId(null);
                                  });
                                  await provider.fetchProjectSprints(project.id,
                                      force: true);
                                  if (mounted) {
                                    _syncSelectedSprint(provider);
                                  }
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSprintsTab() {
    return Consumer2<InstanceProvider, ProjectProvider>(
      builder: (context, instanceProvider, provider, _) {
        final selectedProject = _selectedProjectId == null
            ? null
            : provider.projectById(_selectedProjectId!);
        final sprints = _visibleSprints(provider);
        final currentSessionId =
            context.watch<ChatProvider>().currentSession?.id;

        if (!instanceProvider.hasActiveInstance) {
          return const _EmptyState(
            icon: Icons.flag_outlined,
            title: 'Connect to a server',
            message: 'Sprint planning needs an active Coqui API server.',
          );
        }

        return Column(
          children: [
            _ScopeSelectorBar(
              projectLabel: selectedProject == null
                  ? 'Choose Project'
                  : selectedProject.label,
              sprintLabel: _selectedSprintId == null
                  ? 'All Sprints'
                  : provider.sprintById(_selectedSprintId!)?.label ?? 'Sprint',
              onProjectTap: provider.projects.isEmpty
                  ? null
                  : () => _openProjectPicker(provider),
              onSprintTap: selectedProject == null
                  ? null
                  : () => _openSprintPicker(provider),
              onClearSprint: _selectedSprintId == null
                  ? null
                  : () => setState(() => _setSelectedSprintId(null)),
            ),
            _FilterChips(
              selected: _sprintStatusFilter,
              filters: _sprintFilters,
              onSelected: (value) {
                setState(() => _setSprintStatusFilter(value as String?));
              },
            ),
            Expanded(
              child: selectedProject == null
                  ? const _EmptyState(
                      icon: Icons.flag_outlined,
                      title: 'Choose a project',
                      message:
                          'Sprints belong to a project. Pick one from the selector to inspect or create sprint work.',
                    )
                  : sprints.isEmpty
                      ? const _EmptyState(
                          icon: Icons.flag_outlined,
                          title: 'No sprints yet',
                          message:
                              'Create the first sprint for this project to track the next bounded delivery slice.',
                        )
                      : RefreshIndicator(
                          onRefresh: () => provider.fetchProjectSprints(
                            selectedProject.id,
                            force: true,
                          ),
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                            children: sprints
                                .map(
                                  (sprint) => Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: _SprintCard(
                                      sprint: sprint,
                                      isSelected:
                                          _selectedSprintId == sprint.id,
                                      isCurrentSessionSprint:
                                          currentSessionId != null &&
                                              sprint.lastSessionId ==
                                                  currentSessionId,
                                      onTap: () => _openSprintDetail(sprint),
                                      onEdit: () => _openSprintEditor(
                                        projectId: sprint.projectId,
                                        sprint: sprint,
                                      ),
                                      onSelect: () =>
                                          setState(() => _setSelectedSprintId(
                                                _selectedSprintId == sprint.id
                                                    ? null
                                                    : sprint.id,
                                              )),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
            ),
          ],
        );
      },
    );
  }

  void _setTodoSelectionMode(bool enabled) {
    setState(() {
      _todoSelectionMode = enabled;
      if (enabled) {
        _todoReorderMode = false;
      } else {
        _selectedTodoIds.clear();
      }
    });
  }

  void _setTodoReorderMode(bool enabled) {
    setState(() {
      _todoReorderMode = enabled;
      if (enabled) {
        _todoSelectionMode = false;
        _selectedTodoIds.clear();
      }
    });
  }

  void _toggleTodoSelection(String todoId) {
    setState(() {
      if (_selectedTodoIds.contains(todoId)) {
        _selectedTodoIds.remove(todoId);
      } else {
        _selectedTodoIds.add(todoId);
      }
    });
  }

  Future<void> _openTodoBulkEdit(String sessionId) async {
    if (_selectedTodoIds.isEmpty) {
      return;
    }

    final result = await showModalBottomSheet<TodoBulkEditResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => TodoBulkEditSheet(itemCount: _selectedTodoIds.length),
    );

    if (!mounted || result == null || !result.hasChanges) {
      return;
    }

    final provider = context.read<WorkProvider>();
    final updatedCount = await provider.bulkUpdateTodos(
      sessionId,
      todoIds: _selectedTodoIds.toList(growable: false),
      priority: result.priority,
      status: result.status,
      notes: result.notes,
    );

    if (!mounted) {
      return;
    }

    if (updatedCount > 0) {
      _showSnack('Updated $updatedCount todos');
      setState(() {
        _selectedTodoIds.clear();
        _todoSelectionMode = false;
      });
      return;
    }

    _showSnack(provider.error ?? 'Unable to update todos');
    provider.clearError();
  }

  List<CoquiTodo> _mergeVisibleTodoOrder({
    required List<CoquiTodo> fullOrder,
    required List<CoquiTodo> reorderedVisible,
    required Set<String> visibleIds,
  }) {
    final reorderedIterator = reorderedVisible.iterator;
    final merged = <CoquiTodo>[];

    for (final todo in fullOrder) {
      if (!visibleIds.contains(todo.id)) {
        merged.add(todo);
        continue;
      }

      if (reorderedIterator.moveNext()) {
        merged.add(reorderedIterator.current);
      }
    }

    return merged;
  }

  Widget _buildTodosTab() {
    return Consumer3<InstanceProvider, ChatProvider, WorkProvider>(
      builder: (context, instanceProvider, chatProvider, provider, _) {
        final session = chatProvider.currentSession;
        final sessionId = session?.id;

        if (!instanceProvider.hasActiveInstance) {
          return const _EmptyState(
            icon: Icons.checklist_outlined,
            title: 'Connect to a server',
            message: 'Todo management needs an active Coqui API server.',
          );
        }

        if (sessionId == null) {
          return const _EmptyState(
            icon: Icons.checklist_outlined,
            title: 'Open a chat session',
            message:
                'Todos are scoped to the current chat session so they can reflect the work happening in that conversation.',
          );
        }

        final todos = _visibleTodos(provider, sessionId);
        final allSessionTodos = provider.todosForSession(sessionId);
        final stats = provider.todoStatsForSession(sessionId);

        if (provider.isTodoSessionLoading(sessionId) &&
            provider.todosForSession(sessionId).isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (provider.error != null &&
            provider.todosForSession(sessionId).isEmpty) {
          return _ErrorView(
            title: 'Could not load todos',
            error: provider.error!,
            onRetry: () => provider.fetchTodos(sessionId, force: true),
          );
        }

        final projectProvider = context.read<ProjectProvider>();
        final workArtifacts = provider.artifactsForSession(sessionId);
        final visibleTodoIds = todos.map((item) => item.id).toSet();
        final selectedVisibleTodoIds = _selectedTodoIds
            .where((item) => visibleTodoIds.contains(item))
            .toSet();

        return Column(
          children: [
            _ScopeSelectorBar(
              projectLabel: _selectedProjectId == null
                  ? 'Choose Project'
                  : projectProvider.projectById(_selectedProjectId!)?.label ??
                      'Project',
              sprintLabel: _selectedSprintId == null
                  ? 'All Sprints'
                  : projectProvider.sprintById(_selectedSprintId!)?.label ??
                      'Sprint',
              onProjectTap: projectProvider.projects.isEmpty
                  ? null
                  : () => _openProjectPicker(projectProvider),
              onSprintTap: _selectedProjectId == null
                  ? null
                  : () => _openSprintPicker(projectProvider),
              onClearSprint: _selectedSprintId == null
                  ? null
                  : () => setState(() => _setSelectedSprintId(null)),
            ),
            _FilterChips(
              selected: _todoStatusFilter,
              filters: _todoFilters,
              onSelected: (value) {
                setState(() => _setTodoStatusFilter(value as String?));
              },
            ),
            _TodoActionBar(
              readOnly: chatProvider.isCurrentSessionReadOnly,
              selectionMode: _todoSelectionMode,
              reorderMode: _todoReorderMode,
              selectedCount: selectedVisibleTodoIds.length,
              visibleCount: todos.length,
              onStartSelection: () => _setTodoSelectionMode(true),
              onStopSelection: () => _setTodoSelectionMode(false),
              onStartReorder:
                  todos.length < 2 ? null : () => _setTodoReorderMode(true),
              onStopReorder: () => _setTodoReorderMode(false),
              onSelectAll: todos.isEmpty
                  ? null
                  : () => setState(() {
                        _selectedTodoIds
                          ..clear()
                          ..addAll(visibleTodoIds);
                      }),
              onClearSelection: selectedVisibleTodoIds.isEmpty
                  ? null
                  : () => setState(
                        () =>
                            _selectedTodoIds.removeAll(selectedVisibleTodoIds),
                      ),
              onBulkEdit: selectedVisibleTodoIds.isEmpty
                  ? null
                  : () => _openTodoBulkEdit(sessionId),
              onBulkComplete: selectedVisibleTodoIds.isEmpty
                  ? null
                  : () => _completeSelectedTodos(sessionId),
              onBulkDelete: selectedVisibleTodoIds.isEmpty
                  ? null
                  : () => _deleteSelectedTodos(sessionId),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => provider.fetchTodos(sessionId, force: true),
                child: todos.isEmpty
                    ? ListView(
                        padding: const EdgeInsets.fromLTRB(24, 48, 24, 100),
                        children: const [
                          _EmptyState(
                            icon: Icons.checklist_outlined,
                            title: 'No todos in this scope',
                            message:
                                'Create a todo for the current session, and optionally link it to the selected sprint or an artifact.',
                          ),
                        ],
                      )
                    : _todoReorderMode
                        ? ReorderableListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                            header: Column(
                              children: [
                                _TodoStatsRow(stats: stats),
                                const SizedBox(height: 12),
                                _InfoBanner(
                                  message:
                                      'Drag todos to change their order in the current filtered view. Hidden items keep their relative positions.',
                                ),
                                const SizedBox(height: 16),
                              ],
                            ),
                            itemCount: todos.length,
                            onReorder: (oldIndex, newIndex) async {
                              if (newIndex > oldIndex) {
                                newIndex -= 1;
                              }

                              final reorderedVisible =
                                  List<CoquiTodo>.from(todos);
                              final moved = reorderedVisible.removeAt(oldIndex);
                              reorderedVisible.insert(newIndex, moved);

                              final merged = _mergeVisibleTodoOrder(
                                fullOrder: allSessionTodos,
                                reorderedVisible: reorderedVisible,
                                visibleIds: visibleTodoIds,
                              );

                              final success = await provider.reorderTodos(
                                sessionId,
                                orderedTodoIds: [
                                  for (final todo in merged) todo.id,
                                ],
                              );

                              if (!mounted) {
                                return;
                              }

                              if (!success) {
                                _showSnack(
                                  provider.error ?? 'Unable to reorder todos',
                                );
                                provider.clearError();
                              }
                            },
                            itemBuilder: (context, index) {
                              final todo = todos[index];
                              return Padding(
                                key: ValueKey(todo.id),
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _TodoCard(
                                  todo: todo,
                                  sprintLabel: todo.sprintId == null
                                      ? null
                                      : projectProvider
                                          .sprintById(todo.sprintId!)
                                          ?.label,
                                  artifactLabel: todo.artifactId == null
                                      ? null
                                      : _artifactLabelForId(
                                          workArtifacts, todo.artifactId!),
                                  parentLabel: todo.parentId == null
                                      ? null
                                      : _todoLabelForId(
                                          allSessionTodos,
                                          todo.parentId!,
                                        ),
                                  readOnly: true,
                                  busy: provider.isTodoMutating(todo.id),
                                  onTap: () {},
                                  dragHandle:
                                      ReorderableDelayedDragStartListener(
                                    index: index,
                                    child: const Icon(Icons.drag_indicator),
                                  ),
                                  onStart: null,
                                  onComplete: null,
                                  onReopen: null,
                                  onCancel: null,
                                  onDelete: () async => false,
                                ),
                              );
                            },
                          )
                        : ListView(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                            children: [
                              _TodoStatsRow(stats: stats),
                              const SizedBox(height: 16),
                              ...todos.map(
                                (todo) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _TodoCard(
                                    todo: todo,
                                    sprintLabel: todo.sprintId == null
                                        ? null
                                        : projectProvider
                                            .sprintById(todo.sprintId!)
                                            ?.label,
                                    artifactLabel: todo.artifactId == null
                                        ? null
                                        : _artifactLabelForId(
                                            workArtifacts, todo.artifactId!),
                                    parentLabel: todo.parentId == null
                                        ? null
                                        : _todoLabelForId(
                                            allSessionTodos,
                                            todo.parentId!,
                                          ),
                                    readOnly:
                                        chatProvider.isCurrentSessionReadOnly,
                                    busy: provider.isTodoMutating(todo.id),
                                    selectionMode: _todoSelectionMode,
                                    selected: selectedVisibleTodoIds
                                        .contains(todo.id),
                                    onSelectionChanged: _todoSelectionMode
                                        ? (_) => _toggleTodoSelection(todo.id)
                                        : null,
                                    onTap: _todoSelectionMode
                                        ? () => _toggleTodoSelection(todo.id)
                                        : () => _openTodoEditor(
                                              sessionId: sessionId,
                                              todo: todo,
                                            ),
                                    onAddSubtask: chatProvider
                                            .isCurrentSessionReadOnly
                                        ? null
                                        : () => _openTodoEditor(
                                              sessionId: sessionId,
                                              initialParentId: todo.id,
                                              initialArtifactId:
                                                  todo.artifactId,
                                              initialSprintId: todo.sprintId,
                                            ),
                                    onStart: todo.isPending
                                        ? () => provider.updateTodo(
                                              sessionId,
                                              todo.id,
                                              status: 'in_progress',
                                            )
                                        : null,
                                    onComplete: todo.canComplete
                                        ? () => provider.completeTodo(
                                              sessionId,
                                              todo.id,
                                            )
                                        : null,
                                    onReopen: todo.canReopen
                                        ? () => provider.reopenTodo(
                                              sessionId,
                                              todo.id,
                                            )
                                        : null,
                                    onCancel: todo.canCancel
                                        ? () => provider.cancelTodo(
                                              sessionId,
                                              todo.id,
                                            )
                                        : null,
                                    onDelete: () =>
                                        provider.deleteTodo(sessionId, todo.id),
                                  ),
                                ),
                              ),
                            ],
                          ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildArtifactsTab() {
    return Consumer3<InstanceProvider, ChatProvider, WorkProvider>(
      builder: (context, instanceProvider, chatProvider, provider, _) {
        final session = chatProvider.currentSession;
        final sessionId = session?.id;

        if (!instanceProvider.hasActiveInstance) {
          return const _EmptyState(
            icon: Icons.description_outlined,
            title: 'Connect to a server',
            message: 'Artifact management needs an active Coqui API server.',
          );
        }

        if (sessionId == null) {
          return const _EmptyState(
            icon: Icons.description_outlined,
            title: 'Open a chat session',
            message:
                'Artifacts are scoped to the current chat session and can also link back to the selected project or sprint.',
          );
        }

        final artifacts = _visibleArtifacts(provider, sessionId);

        if (provider.isArtifactSessionLoading(sessionId) &&
            provider.artifactsForSession(sessionId).isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (provider.error != null &&
            provider.artifactsForSession(sessionId).isEmpty) {
          return _ErrorView(
            title: 'Could not load artifacts',
            error: provider.error!,
            onRetry: () => provider.fetchArtifacts(sessionId, force: true),
          );
        }

        final projectProvider = context.read<ProjectProvider>();

        return Column(
          children: [
            _ScopeSelectorBar(
              projectLabel: _selectedProjectId == null
                  ? 'Choose Project'
                  : projectProvider.projectById(_selectedProjectId!)?.label ??
                      'Project',
              sprintLabel: _selectedSprintId == null
                  ? 'All Sprints'
                  : projectProvider.sprintById(_selectedSprintId!)?.label ??
                      'Sprint',
              onProjectTap: projectProvider.projects.isEmpty
                  ? null
                  : () => _openProjectPicker(projectProvider),
              onSprintTap: _selectedProjectId == null
                  ? null
                  : () => _openSprintPicker(projectProvider),
              onClearSprint: _selectedSprintId == null
                  ? null
                  : () => setState(() => _setSelectedSprintId(null)),
            ),
            _FilterChips(
              selected: _artifactStageFilter,
              filters: _artifactFilters,
              onSelected: (value) {
                setState(() => _setArtifactStageFilter(value as String?));
              },
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () =>
                    provider.fetchArtifacts(sessionId, force: true),
                child: artifacts.isEmpty
                    ? ListView(
                        padding: const EdgeInsets.fromLTRB(24, 48, 24, 100),
                        children: const [
                          _EmptyState(
                            icon: Icons.description_outlined,
                            title: 'No artifacts in this scope',
                            message:
                                'Create a draft artifact for the current chat and attach it to the selected project or sprint when useful.',
                          ),
                        ],
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                        children: artifacts
                            .map(
                              (artifact) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _ArtifactCard(
                                  artifact: artifact,
                                  projectLabel: artifact.projectId == null
                                      ? null
                                      : projectProvider
                                          .projectById(artifact.projectId!)
                                          ?.label,
                                  sprintLabel: artifact.sprintId == null
                                      ? null
                                      : projectProvider
                                          .sprintById(artifact.sprintId!)
                                          ?.label,
                                  readOnly:
                                      chatProvider.isCurrentSessionReadOnly,
                                  busy:
                                      provider.isArtifactMutating(artifact.id),
                                  onTap: () => _openArtifactDetail(
                                    sessionId,
                                    artifact,
                                    chatProvider.isCurrentSessionReadOnly,
                                  ),
                                  onEdit: () => _openArtifactEditor(
                                    sessionId: sessionId,
                                    artifact: artifact,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
              ),
            ),
          ],
        );
      },
    );
  }

  String? _artifactLabelForId(
      List<CoquiArtifact> artifacts, String artifactId) {
    for (final artifact in artifacts) {
      if (artifact.id == artifactId) {
        return artifact.label;
      }
    }
    return null;
  }

  String? _todoLabelForId(List<CoquiTodo> todos, String todoId) {
    for (final todo in todos) {
      if (todo.id == todoId) {
        return todo.label;
      }
    }
    return null;
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _WorkContextCard extends StatelessWidget {
  final String? selectedProjectId;
  final String? selectedSprintId;
  final VoidCallback? onUseChatProject;

  const _WorkContextCard({
    required this.selectedProjectId,
    required this.selectedSprintId,
    required this.onUseChatProject,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer2<ChatProvider, ProjectProvider>(
      builder: (context, chatProvider, projectProvider, _) {
        final session = chatProvider.currentSession;
        final activeProjectLabel = chatProvider.currentSessionProjectLabel;
        final activeProject = session?.activeProjectId == null
            ? null
            : projectProvider.projectById(session!.activeProjectId!);
        final selectedProject = selectedProjectId == null
            ? null
            : projectProvider.projectById(selectedProjectId!);
        final selectedSprint = selectedSprintId == null
            ? null
            : projectProvider.sprintById(selectedSprintId!);
        final canSyncProject = activeProject != null &&
            activeProject.id != selectedProject?.id &&
            onUseChatProject != null;

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Row(
            children: [
              const Icon(Icons.workspaces_outline),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session?.title ?? 'No chat session selected',
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      session == null
                          ? 'Projects and sprints are global. Todos and artifacts will use the current chat session as their scope.'
                          : activeProjectLabel?.isNotEmpty == true
                              ? 'Current chat project: $activeProjectLabel'
                              : 'Current chat has no active project yet.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (chatProvider.lastTurnSummary?.isNotEmpty == true) ...[
                      const SizedBox(height: 8),
                      Text(
                        chatProvider.lastTurnSummary!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    if (selectedProject != null || selectedSprint != null) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (selectedProject != null)
                            _ContextChip(
                                label: 'Scope: ${selectedProject.label}'),
                          if (selectedSprint != null)
                            _ContextChip(label: selectedSprint.label),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (canSyncProject)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilledButton.tonal(
                    onPressed: onUseChatProject,
                    child: const Text('Use Chat Project'),
                  ),
                ),
              if (session?.isReadOnly == true)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Read Only',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        ),
                  ),
                )
              else if (activeProject != null)
                ProjectStatusBadge(project: activeProject),
            ],
          ),
        );
      },
    );
  }
}

class _ContextChip extends StatelessWidget {
  final String label;

  const _ContextChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelSmall),
    );
  }
}

class _ScopeSelectorBar extends StatelessWidget {
  final String projectLabel;
  final String sprintLabel;
  final VoidCallback? onProjectTap;
  final VoidCallback? onSprintTap;
  final VoidCallback? onClearSprint;

  const _ScopeSelectorBar({
    required this.projectLabel,
    required this.sprintLabel,
    required this.onProjectTap,
    required this.onSprintTap,
    required this.onClearSprint,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          OutlinedButton.icon(
            onPressed: onProjectTap,
            icon: const Icon(Icons.folder_open_outlined),
            label: Text(projectLabel),
          ),
          OutlinedButton.icon(
            onPressed: onSprintTap,
            icon: const Icon(Icons.flag_outlined),
            label: Text(sprintLabel),
          ),
          if (onClearSprint != null)
            TextButton.icon(
              onPressed: onClearSprint,
              icon: const Icon(Icons.close),
              label: const Text('Clear Sprint'),
            ),
        ],
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  final Object? selected;
  final List<({String label, Object? value})> filters;
  final ValueChanged<Object?> onSelected;

  const _FilterChips({
    required this.selected,
    required this.filters,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: filters
            .map(
              (filter) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(filter.label),
                  selected: selected == filter.value,
                  onSelected: (_) => onSelected(filter.value),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _ProjectStatsRow extends StatelessWidget {
  final ProjectProvider provider;

  const _ProjectStatsRow({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
              label: 'Active', value: '${provider.activeProjectsCount}'),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
              label: 'Completed', value: '${provider.completedProjectsCount}'),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
              label: 'Archived', value: '${provider.archivedProjectsCount}'),
        ),
      ],
    );
  }
}

class _ProjectCard extends StatelessWidget {
  final CoquiProject project;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onSelect;

  const _ProjectCard({
    required this.project,
    required this.isSelected,
    required this.onTap,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primaryContainer.withValues(alpha: 0.45)
              : theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? theme.colorScheme.primary : theme.dividerColor,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    project.label,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 12),
                ProjectStatusBadge(project: project),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              project.hasDescription
                  ? project.description!
                  : 'No description yet. Open the project to add more structure and assign it to the current chat.',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _InfoChip(label: project.slug),
                _InfoChip(label: '${project.sprintCount} sprints'),
                if (project.hasActiveSprint) _InfoChip(label: 'Active sprint'),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onSelect,
                icon: Icon(isSelected
                    ? Icons.check_circle_outline
                    : Icons.flag_outlined),
                label: Text(
                    isSelected ? 'Selected For Sprints' : 'Use In Sprints'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SprintCard extends StatelessWidget {
  final CoquiSprint sprint;
  final bool isSelected;
  final bool isCurrentSessionSprint;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onSelect;

  const _SprintCard({
    required this.sprint,
    required this.isSelected,
    required this.isCurrentSessionSprint,
    required this.onTap,
    required this.onEdit,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primaryContainer.withValues(alpha: 0.45)
              : theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? theme.colorScheme.primary : theme.dividerColor,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    sprint.label,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 12),
                SprintStatusBadge(sprint: sprint),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              sprint.hasAcceptanceCriteria
                  ? sprint.acceptanceCriteria!
                  : 'No acceptance criteria yet. Open the sprint to tighten the delivery target.',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _InfoChip(label: 'Max reviews ${sprint.maxReviewRounds}'),
                if (sprint.reviewRound > 0)
                  _InfoChip(label: 'Round ${sprint.reviewRound}'),
                if (isCurrentSessionSprint)
                  const _InfoChip(label: 'Current chat session'),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                TextButton.icon(
                  onPressed: onSelect,
                  icon: Icon(
                    isSelected
                        ? Icons.check_circle_outline
                        : Icons.filter_alt_outlined,
                  ),
                  label: Text(isSelected ? 'Scoped' : 'Use In Work'),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Quick Edit'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TodoStatsRow extends StatelessWidget {
  final CoquiTodoStats stats;

  const _TodoStatsRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _StatCard(label: 'Open', value: '${stats.openCount}')),
        const SizedBox(width: 12),
        Expanded(
            child: _StatCard(label: 'Completed', value: '${stats.completed}')),
        const SizedBox(width: 12),
        Expanded(
            child: _StatCard(label: 'Cancelled', value: '${stats.cancelled}')),
      ],
    );
  }
}

class _TodoActionBar extends StatelessWidget {
  final bool readOnly;
  final bool selectionMode;
  final bool reorderMode;
  final int selectedCount;
  final int visibleCount;
  final VoidCallback? onStartSelection;
  final VoidCallback? onStopSelection;
  final VoidCallback? onStartReorder;
  final VoidCallback? onStopReorder;
  final VoidCallback? onSelectAll;
  final VoidCallback? onClearSelection;
  final VoidCallback? onBulkEdit;
  final VoidCallback? onBulkComplete;
  final VoidCallback? onBulkDelete;

  const _TodoActionBar({
    required this.readOnly,
    required this.selectionMode,
    required this.reorderMode,
    required this.selectedCount,
    required this.visibleCount,
    required this.onStartSelection,
    required this.onStopSelection,
    required this.onStartReorder,
    required this.onStopReorder,
    required this.onSelectAll,
    required this.onClearSelection,
    required this.onBulkEdit,
    required this.onBulkComplete,
    required this.onBulkDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (!selectionMode && !reorderMode)
            OutlinedButton.icon(
              onPressed: readOnly ? null : onStartSelection,
              icon: const Icon(Icons.done_all_outlined),
              label: const Text('Select'),
            ),
          if (!selectionMode && !reorderMode)
            OutlinedButton.icon(
              onPressed: readOnly ? null : onStartReorder,
              icon: const Icon(Icons.reorder_outlined),
              label: const Text('Reorder'),
            ),
          if (selectionMode) ...[
            _InfoChip(label: '$selectedCount selected'),
            TextButton.icon(
              onPressed: onSelectAll,
              icon: const Icon(Icons.select_all_outlined),
              label: Text(visibleCount == 0 ? 'Select All' : 'Select Visible'),
            ),
            TextButton.icon(
              onPressed: onClearSelection,
              icon: const Icon(Icons.deselect_outlined),
              label: const Text('Clear'),
            ),
            FilledButton.tonalIcon(
              onPressed: readOnly ? null : onBulkEdit,
              icon: const Icon(Icons.edit_note_outlined),
              label: const Text('Bulk Edit'),
            ),
            FilledButton.tonalIcon(
              onPressed: readOnly ? null : onBulkComplete,
              icon: const Icon(Icons.task_alt_outlined),
              label: const Text('Complete'),
            ),
            OutlinedButton.icon(
              onPressed: readOnly ? null : onBulkDelete,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Delete'),
            ),
            TextButton(
              onPressed: onStopSelection,
              child: const Text('Done'),
            ),
          ],
          if (reorderMode) ...[
            const _InfoChip(label: 'Reorder mode'),
            TextButton(
              onPressed: onStopReorder,
              child: const Text('Done'),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final String message;

  const _InfoBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Text(message, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}

class _TodoCard extends StatelessWidget {
  final CoquiTodo todo;
  final String? sprintLabel;
  final String? artifactLabel;
  final String? parentLabel;
  final bool readOnly;
  final bool busy;
  final VoidCallback onTap;
  final bool selectionMode;
  final bool selected;
  final ValueChanged<bool?>? onSelectionChanged;
  final Widget? dragHandle;
  final VoidCallback? onAddSubtask;
  final VoidCallback? onStart;
  final VoidCallback? onComplete;
  final VoidCallback? onReopen;
  final VoidCallback? onCancel;
  final Future<bool> Function() onDelete;

  const _TodoCard({
    required this.todo,
    required this.sprintLabel,
    required this.artifactLabel,
    required this.parentLabel,
    required this.readOnly,
    required this.busy,
    required this.onTap,
    this.selectionMode = false,
    this.selected = false,
    this.onSelectionChanged,
    this.dragHandle,
    this.onAddSubtask,
    required this.onStart,
    required this.onComplete,
    required this.onReopen,
    required this.onCancel,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (selectionMode) ...[
                  Checkbox.adaptive(
                    value: selected,
                    onChanged: readOnly || busy ? null : onSelectionChanged,
                  ),
                  const SizedBox(width: 4),
                ],
                Expanded(
                  child: Text(
                    todo.label,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                if (dragHandle != null) ...[
                  const SizedBox(width: 8),
                  dragHandle!,
                ],
                const SizedBox(width: 12),
                TodoStatusBadge(todo: todo),
              ],
            ),
            if (todo.hasNotes) ...[
              const SizedBox(height: 10),
              Text(
                todo.notes!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _InfoChip(label: todo.priority.toUpperCase()),
                if (sprintLabel != null) _InfoChip(label: sprintLabel!),
                if (artifactLabel != null) _InfoChip(label: artifactLabel!),
                if (parentLabel != null)
                  _InfoChip(label: 'Parent: $parentLabel'),
                if (todo.hasSubtasks)
                  _InfoChip(label: '${todo.subtasks.length} subtasks'),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (onStart != null)
                  FilledButton.tonal(
                    onPressed: readOnly || busy ? null : onStart,
                    child: const Text('Start'),
                  ),
                if (onComplete != null)
                  FilledButton.tonal(
                    onPressed: readOnly || busy ? null : onComplete,
                    child: const Text('Complete'),
                  ),
                if (onReopen != null)
                  FilledButton.tonal(
                    onPressed: readOnly || busy ? null : onReopen,
                    child: const Text('Reopen'),
                  ),
                if (onCancel != null)
                  OutlinedButton(
                    onPressed: readOnly || busy ? null : onCancel,
                    child: const Text('Cancel'),
                  ),
                if (onAddSubtask != null)
                  OutlinedButton(
                    onPressed: readOnly || busy ? null : onAddSubtask,
                    child: const Text('Add Subtask'),
                  ),
                OutlinedButton(
                  onPressed: readOnly || busy
                      ? null
                      : () async {
                          final deleted = await onDelete();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  deleted
                                      ? 'Todo deleted.'
                                      : 'Unable to delete todo.',
                                ),
                              ),
                            );
                          }
                        },
                  child: const Text('Delete'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ArtifactCard extends StatelessWidget {
  final CoquiArtifact artifact;
  final String? projectLabel;
  final String? sprintLabel;
  final bool readOnly;
  final bool busy;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  const _ArtifactCard({
    required this.artifact,
    required this.projectLabel,
    required this.sprintLabel,
    required this.readOnly,
    required this.busy,
    required this.onTap,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    artifact.label,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 12),
                ArtifactStageBadge(artifact: artifact),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              artifact.summary ?? artifact.content.trim().replaceAll('\n', ' '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _InfoChip(label: artifact.type),
                _InfoChip(label: 'v${artifact.version}'),
                _InfoChip(label: artifact.storageLabel),
                if (projectLabel != null) _InfoChip(label: projectLabel!),
                if (sprintLabel != null) _InfoChip(label: sprintLabel!),
                if (artifact.hasLanguage) _InfoChip(label: artifact.language!),
                if (artifact.persistent) const _InfoChip(label: 'Persistent'),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: readOnly || busy ? null : onEdit,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Quick Edit'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;

  const _InfoChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelSmall),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;

  const _StatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40),
            const SizedBox(height: 12),
            Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String title;
  final String error;
  final Future<void> Function() onRetry;

  const _ErrorView({
    required this.title,
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 40),
            const SizedBox(height: 12),
            Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
