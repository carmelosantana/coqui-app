import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:responsive_framework/responsive_framework.dart';

import 'package:coqui_app/Constants/constants.dart';
import 'package:coqui_app/Models/chat_preset.dart';
import 'package:coqui_app/Models/coqui_exception.dart';
import 'package:coqui_app/Models/coqui_role.dart';
import 'package:coqui_app/Models/coqui_session.dart';
import 'package:coqui_app/Pages/work_page/work_navigation.dart';
import 'package:coqui_app/Providers/chat_provider.dart';
import 'package:coqui_app/Providers/instance_provider.dart';
import 'package:coqui_app/Services/analytics_service.dart';
import 'package:coqui_app/Widgets/chat_app_bar.dart';
import 'package:coqui_app/Widgets/role_list_tile.dart';
import 'package:coqui_app/Widgets/bottom_sheet_header.dart';
import 'package:coqui_app/Widgets/profile_picker_dialog.dart';
import 'package:coqui_app/Widgets/selection_bottom_sheet.dart';

import 'subwidgets/subwidgets.dart';

enum _SessionContinuationChoice { resume, startNew }

enum _SessionCreationMode { single, group }

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  // Selected role for new session creation
  CoquiRole? _selectedRole;
  String? _selectedProfile;
  var _sessionCreationMode = _SessionCreationMode.single;
  List<String> _selectedGroupProfiles = const [];
  final _groupRoundsController = TextEditingController(text: '3');

  // Cached preset suggestions — only regenerated on new conversation
  final List<ChatPreset> _presets = ChatPresets.randomPresets;

  // Text field controller for the chat prompt
  final _textFieldController = TextEditingController();
  final _textFieldFocusNode = FocusNode();
  bool _hadInputFocus = false;

  /// Tracks whether the text field has non-empty content. Used by the suffix
  /// icon builder so we can avoid calling setState on every keystroke.
  final _hasText = ValueNotifier<bool>(false);

  // Welcome screen animation state
  var _crossFadeState = CrossFadeState.showFirst;
  double _scale = 1.0;

  @override
  void initState() {
    super.initState();

    _textFieldFocusNode.addListener(() {
      _hadInputFocus = _textFieldFocusNode.hasFocus;
    });

    // Refresh sessions on launch
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      chatProvider.refreshSessions();
    });
  }

  @override
  void dispose() {
    _groupRoundsController.dispose();
    _textFieldFocusNode.dispose();
    _textFieldController.dispose();
    _hasText.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatProvider>(
      builder: (BuildContext context, ChatProvider chatProvider, _) {
        // Restore focus if user was typing and focus got lost due to rebuilds
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_hadInputFocus && !_textFieldFocusNode.hasFocus) {
            _textFieldFocusNode.requestFocus();
          }
        });
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            if (!ResponsiveBreakpoints.of(context).isMobile) const ChatAppBar(),
            Expanded(
              child: Stack(
                alignment: Alignment.bottomLeft,
                children: [
                  _buildChatBody(chatProvider),
                  _buildChatFooter(chatProvider),
                ],
              ),
            ),
            _buildFileChipsRow(chatProvider),
            if (chatProvider.isCurrentSessionReadOnly)
              _buildClosedSessionNotice(chatProvider),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: ChatTextField(
                key: ValueKey(chatProvider.currentSession?.id),
                controller: _textFieldController,
                focusNode: _textFieldFocusNode,
                enabled: !chatProvider.isCurrentSessionReadOnly,
                labelText: chatProvider.isCurrentSessionReadOnly
                    ? 'Conversation closed'
                    : 'Prompt',
                hintText: chatProvider.isCurrentSessionReadOnly
                    ? 'Resume the active session or start a new one to continue.'
                    : null,
                onChanged: (text) => _hasText.value = text.trim().isNotEmpty,
                onEditingComplete: () => _handleOnEditingComplete(chatProvider),
                prefixIcon: _buildAttachButton(chatProvider),
                suffixIcon: _buildTextFieldSuffixIcon(chatProvider),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildChatBody(ChatProvider chatProvider) {
    if (chatProvider.displayMessages.isEmpty) {
      if (chatProvider.currentSession == null) {
        final instanceProvider =
            Provider.of<InstanceProvider>(context, listen: false);

        if (instanceProvider.activeInstance == null) {
          return ChatEmpty(
            child: ChatWelcome(
              showingState: _crossFadeState,
              onFirstChildFinished: () =>
                  setState(() => _crossFadeState = CrossFadeState.showSecond),
              secondChildScale: _scale,
              onSecondChildScaleEnd: () => setState(() => _scale = 1.0),
            ),
          );
        } else {
          return ChatEmpty(
            child: _buildSessionSetupControls(chatProvider),
          );
        }
      } else {
        return const ChatEmpty(
          child: Text('No messages yet!'),
        );
      }
    } else {
      return ChatListView(
        key: PageStorageKey<String>(chatProvider.currentSession?.id ?? 'empty'),
        messages: chatProvider.displayMessages,
        allMessages: chatProvider.messages,
        isAwaitingReply: chatProvider.isCurrentSessionThinking,
        error: chatProvider.currentSessionError != null
            ? ChatError(
                error: chatProvider.currentSessionError!,
                onRetry: () => chatProvider.retryLastPrompt(),
              )
            : null,
        agentActivity: chatProvider.currentTurnActivity,
        turnData: chatProvider.lastCompletedTurn,
        turnSummary: chatProvider.lastTurnSummary,
        isStreaming: chatProvider.isCurrentSessionStreaming,
      );
    }
  }

  Widget _buildChatFooter(ChatProvider chatProvider) {
    if (chatProvider.displayMessages.isEmpty &&
        chatProvider.currentSession == null) {
      return ChatAttachmentRow(
        itemCount: _presets.length,
        itemBuilder: (context, index) {
          final preset = _presets[index];
          return ChatAttachmentPreset(
            preset: preset,
            onPressed: () {
              _textFieldController.text = preset.prompt;
              _hasText.value = preset.prompt.trim().isNotEmpty;
              if (preset.role != null) {
                setState(() {
                  _selectedRole = CoquiRole(name: preset.role!, model: '');
                });
              }
              _textFieldFocusNode.requestFocus();
            },
          );
        },
      );
    } else {
      return const SizedBox();
    }
  }

  Widget _buildSessionSetupControls(ChatProvider chatProvider) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 720),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SegmentedButton<_SessionCreationMode>(
            segments: const [
              ButtonSegment<_SessionCreationMode>(
                value: _SessionCreationMode.single,
                icon: Icon(Icons.person_outline),
                label: Text('Single'),
              ),
              ButtonSegment<_SessionCreationMode>(
                value: _SessionCreationMode.group,
                icon: Icon(Icons.groups_2_outlined),
                label: Text('Group'),
              ),
            ],
            selected: {_sessionCreationMode},
            onSelectionChanged: (selection) {
              if (selection.isEmpty) return;
              setState(() {
                _sessionCreationMode = selection.first;
              });
            },
          ),
          const SizedBox(height: 16),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: _sessionCreationMode == _SessionCreationMode.single
                ? _buildSingleSessionControls()
                : _buildGroupSessionControls(chatProvider),
          ),
        ],
      ),
    );
  }

  Widget _buildSingleSessionControls() {
    return Wrap(
      key: const ValueKey<String>('single-session-controls'),
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: [
        SizedBox(
          width: 220,
          child: ChatSelectRoleButton(
            currentRoleName: _selectedRole?.name,
            onPressed: () => _showRoleSelectionBottomSheet(context),
          ),
        ),
        SizedBox(
          width: 220,
          child: OutlinedButton.icon(
            onPressed: () => _showProfileSelectionDialog(context),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 16,
              ),
            ),
            icon: const Icon(Icons.person_outline),
            label: Text(
              _selectedProfile == null || _selectedProfile!.isEmpty
                  ? 'Select a profile'
                  : 'Profile: $_selectedProfile',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGroupSessionControls(ChatProvider chatProvider) {
    final hasEnoughProfiles = _selectedGroupProfiles.length >= 2;

    return Column(
      key: const ValueKey<String>('group-session-controls'),
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 320,
          child: OutlinedButton.icon(
            onPressed: () => _showGroupProfileSelectionDialog(context),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 16,
              ),
            ),
            icon: const Icon(Icons.groups_2_outlined),
            label: Text(_groupSelectionLabel),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: 220,
          child: TextField(
            controller: _groupRoundsController,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Number of rounds',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        if (_selectedGroupProfiles.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            hasEnoughProfiles
                ? 'Selected: ${_selectedGroupProfiles.join(', ')}'
                : 'Select at least two profiles for a group session.',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  Widget _buildTextFieldSuffixIcon(ChatProvider chatProvider) {
    if (chatProvider.isCurrentSessionReadOnly) {
      return const SizedBox.shrink();
    }

    // Stop button during streaming doesn't depend on _hasText, but we
    // still wrap the block in ValueListenableBuilder so the send button
    // appears/disappears without calling setState on every keystroke.
    if (chatProvider.isCurrentSessionStreaming) {
      return IconButton(
        icon: const Icon(Icons.stop_rounded),
        color: Theme.of(context).colorScheme.onSurface,
        onPressed: () {
          chatProvider.cancelCurrentStreaming();
        },
      );
    }

    return ValueListenableBuilder<bool>(
      valueListenable: _hasText,
      builder: (context, hasText, _) {
        if (hasText) {
          return IconButton(
            icon: const Icon(Icons.arrow_upward_rounded),
            color: Theme.of(context).colorScheme.onSurface,
            onPressed: () async {
              await _handleSendButton(chatProvider);
            },
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  /// Horizontal row of file chips shown above the text field when files are
  /// pending. Smoothly animates in and out as files are added or cleared.
  Widget _buildFileChipsRow(ChatProvider chatProvider) {
    if (chatProvider.pendingFiles.isEmpty) return const SizedBox.shrink();

    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: chatProvider.pendingFiles
                .map(
                  (file) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChatFileChip(
                      file: file,
                      onRemove: () =>
                          chatProvider.removeAttachment(file.localId),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }

  /// Paperclip button injected as the text field prefix icon.
  /// Disabled (grey) when no session is active.
  Widget _buildAttachButton(ChatProvider chatProvider) {
    final hasWritableSession = chatProvider.currentSession != null &&
        !chatProvider.isCurrentSessionReadOnly;
    return IconButton(
      icon: const Icon(Icons.attach_file),
      tooltip: hasWritableSession
          ? 'Attach file'
          : chatProvider.currentSession != null
              ? 'Closed sessions are read-only'
              : 'Start a session to attach files',
      color: hasWritableSession
          ? Theme.of(context).colorScheme.onSurface
          : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
      onPressed:
          hasWritableSession ? () => _handleAttachButton(chatProvider) : null,
    );
  }

  Future<void> _handleAttachButton(ChatProvider chatProvider) async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
    );
    if (result == null || result.files.isEmpty) return;
    await chatProvider.attachFiles(result.files);
  }

  Future<void> _handleSendButton(ChatProvider chatProvider) async {
    final instanceProvider =
        Provider.of<InstanceProvider>(context, listen: false);

    if (instanceProvider.activeInstance == null) {
      setState(() => _crossFadeState = CrossFadeState.showSecond);
      setState(() => _scale = _scale == 1.0 ? 1.05 : 1.0);
    } else if (chatProvider.isCurrentSessionReadOnly) {
      return;
    } else if (chatProvider.currentSession == null) {
      final roleToUse = _resolveRoleForNewSession();

      final messenger = ScaffoldMessenger.of(context);
      final errorColor = Theme.of(context).colorScheme.error;

      try {
        if (_sessionCreationMode == _SessionCreationMode.group) {
          final groupMaxRounds = _parsedGroupMaxRounds;
          if (_selectedGroupProfiles.length < 2) {
            messenger.showSnackBar(
              SnackBar(
                content: const Text(
                  'Select at least two profiles for a group session.',
                ),
                backgroundColor: errorColor,
              ),
            );
            return;
          }
          if (groupMaxRounds == null || groupMaxRounds < 1) {
            messenger.showSnackBar(
              SnackBar(
                content: const Text('Number of rounds must be at least 1.'),
                backgroundColor: errorColor,
              ),
            );
            return;
          }

          await chatProvider.refreshSessions();
          final choice = await _resolveGroupSessionChoice(
            chatProvider,
            _selectedGroupProfiles,
          );
          if (choice == null) return;

          final existingSession =
              chatProvider.latestActiveSessionForGroupMembers(
            _selectedGroupProfiles,
          );

          if (choice == _SessionContinuationChoice.resume &&
              existingSession != null) {
            chatProvider.openSession(existingSession.id);
          } else {
            await chatProvider.createNewSession(
              _groupSessionRole,
              groupProfiles: _selectedGroupProfiles,
              groupMaxRounds: groupMaxRounds,
              confirmCloseActiveGroupSession: existingSession != null,
            );
          }
        } else if (_selectedProfile != null && _selectedProfile!.isNotEmpty) {
          await chatProvider.refreshSessions();
          final choice = await _resolveProfileSessionChoice(
            chatProvider,
            _selectedProfile!,
          );
          if (choice == null) return;

          final existingSession = chatProvider.latestActiveSessionForProfile(
            _selectedProfile,
          );

          if (choice == _SessionContinuationChoice.resume &&
              existingSession != null) {
            chatProvider.openSession(existingSession.id);
          } else {
            await chatProvider.createNewSession(
              roleToUse,
              profile: _selectedProfile,
              confirmCloseActiveProfileSession: existingSession != null,
            );
          }
        } else {
          await chatProvider.createNewSession(roleToUse);
        }
      } on CoquiException catch (e) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: errorColor,
          ),
        );
        return;
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(CoquiException.friendly(e).message),
            backgroundColor: errorColor,
          ),
        );
        return;
      }

      await chatProvider.sendPrompt(_textFieldController.text);
      _clearComposer();
    } else {
      await chatProvider.sendPrompt(_textFieldController.text);
      _clearComposer();
    }
  }

  Future<void> _handleOnEditingComplete(ChatProvider chatProvider) async {
    if (_hasText.value &&
        !chatProvider.isCurrentSessionStreaming &&
        !chatProvider.isCurrentSessionReadOnly) {
      await _handleSendButton(chatProvider);
    }
  }

  Future<void> _showRoleSelectionBottomSheet(BuildContext context) async {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);

    final selectedRole = await showSelectionBottomSheet<CoquiRole>(
      context: context,
      header: const BottomSheetHeader(title: "Select a Role"),
      fetchItems: chatProvider.fetchAvailableRoles,
      currentSelection: _selectedRole,
      itemBuilder: (role, selected, onSelected) {
        return RoleListTile(
          role: role,
          selected: selected,
          onSelected: onSelected,
        );
      },
    );

    if (selectedRole != null) {
      AnalyticsService.trackEvent('role_selected', {'role': selectedRole.name});
      setState(() {
        _selectedRole = selectedRole;
      });
    }
  }

  Future<void> _showProfileSelectionDialog(BuildContext context) async {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);

    final selectedProfile = await showProfilePickerDialog(
      context: context,
      title: 'Select a Profile',
      fetchProfiles: chatProvider.fetchAvailableProfiles,
      initialValue: _selectedProfile,
    );

    if (!context.mounted) return;

    if (selectedProfile != null && mounted) {
      final nextProfile = selectedProfile.isEmpty ? null : selectedProfile;

      setState(() {
        _selectedProfile = nextProfile;
      });

      if (nextProfile == null || nextProfile.isEmpty) {
        return;
      }

      await chatProvider.refreshSessions();
      if (!context.mounted) return;

      final existingSession =
          chatProvider.latestActiveSessionForProfile(nextProfile);
      if (existingSession == null || !mounted) {
        return;
      }

      final choice = await _showExistingProfileSessionDialog(
        context,
        profileName: nextProfile,
      );
      if (!context.mounted) return;

      if (choice == null || !mounted) {
        return;
      }

      if (choice == _SessionContinuationChoice.resume) {
        chatProvider.openSession(existingSession.id);
        return;
      }

      await _createSessionForProfileSelection(
        chatProvider,
        nextProfile,
        confirmCloseActiveProfileSession: true,
      );
    }
  }

  Future<void> _showGroupProfileSelectionDialog(BuildContext context) async {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);

    final selectedProfiles = await showMultiProfilePickerDialog(
      context: context,
      title: 'Select Profiles',
      fetchProfiles: chatProvider.fetchAvailableProfiles,
      initialValues: _selectedGroupProfiles,
    );

    if (!context.mounted || selectedProfiles == null) return;

    setState(() {
      _selectedGroupProfiles = selectedProfiles;
    });

    if (selectedProfiles.length < 2) {
      return;
    }

    await chatProvider.refreshSessions();
    if (!context.mounted) return;

    final existingSession = chatProvider.latestActiveSessionForGroupMembers(
      selectedProfiles,
    );
    if (existingSession == null || !mounted) {
      return;
    }

    final choice = await _showExistingGroupSessionDialog(
      context,
      profiles: selectedProfiles,
    );
    if (!context.mounted || choice == null || !mounted) {
      return;
    }

    if (choice == _SessionContinuationChoice.resume) {
      chatProvider.openSession(existingSession.id);
      return;
    }

    await _createSessionForGroupSelection(
      chatProvider,
      groupProfiles: selectedProfiles,
      groupMaxRounds: _parsedGroupMaxRounds ?? 3,
      confirmCloseActiveGroupSession: true,
    );
  }

  Widget _buildClosedSessionNotice(ChatProvider chatProvider) {
    final session = chatProvider.currentSession;
    if (session == null) return const SizedBox.shrink();

    final resumeTarget = session.isGroupSession
        ? chatProvider.latestActiveSessionForGroupMembers(
            session.groupProfileNames,
            excludingSessionId: session.id,
          )
        : chatProvider.latestActiveSessionForProfile(
            session.profile,
            excludingSessionId: session.id,
          );

    final projectLabel =
        chatProvider.currentSessionProjectLabel ?? session.activeProjectId;
    final statusLabel = session.isArchived ? 'archived' : 'closed';
    final scopeDescription = session.isGroupSession
        ? 'It includes ${session.compactParticipantSummary}. '
        : session.profileLabel != null
            ? 'It belongs to the ${session.profileLabel} profile. '
            : '';
    final resumeScopeLabel =
        session.isGroupSession ? 'for this group' : 'for this profile';

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context)
              .colorScheme
              .surfaceContainerHighest
              .withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This conversation is $statusLabel. $scopeDescription${projectLabel != null ? 'Project context: $projectLabel. ' : ''}Resume an active session${resumeTarget != null ? ' $resumeScopeLabel' : ''} or start a new one to continue writing.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (session.closureReason?.isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Text(
                'Reason: ${session.closureReason}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (resumeTarget != null)
                  TextButton.icon(
                    onPressed: () => chatProvider.openSession(resumeTarget.id),
                    icon: const Icon(Icons.history_toggle_off),
                    label: Text(
                      resumeTarget.title?.isNotEmpty == true
                          ? 'Resume ${resumeTarget.title!}'
                          : 'Resume previous session',
                    ),
                  ),
                FilledButton.icon(
                  onPressed: () => _startNewSessionFromClosedNotice(
                    chatProvider,
                    session,
                    confirmCloseActiveProfileSession: resumeTarget != null,
                  ),
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('Start new session'),
                ),
                OutlinedButton.icon(
                  onPressed: () => openWorkPage(
                    context,
                    arguments: workArgumentsForCurrentSession(
                      context,
                      initialTab: WorkPageTab.todos,
                    ),
                  ),
                  icon: const Icon(Icons.workspaces_outline),
                  label: const Text('Open Work'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  CoquiRole _resolveRoleForNewSession() {
    final selectedRole = _selectedRole;
    if (selectedRole != null) {
      return selectedRole;
    }

    final defaultRoleName = Hive.box('settings')
        .get('default_role', defaultValue: 'orchestrator') as String;

    return CoquiRole(
      name: defaultRoleName,
      model: '',
    );
  }

  CoquiRole get _groupSessionRole => CoquiRole(
        name: 'orchestrator',
        model: '',
      );

  String get _groupSelectionLabel {
    if (_selectedGroupProfiles.isEmpty) {
      return 'Select profiles';
    }

    if (_selectedGroupProfiles.length <= 3) {
      return _selectedGroupProfiles.join(', ');
    }

    return '${_selectedGroupProfiles.take(2).join(', ')} +${_selectedGroupProfiles.length - 2}';
  }

  int? get _parsedGroupMaxRounds {
    final text = _groupRoundsController.text.trim();
    if (text.isEmpty) {
      return null;
    }

    return int.tryParse(text);
  }

  void _clearComposer() {
    _textFieldController.clear();
    _hasText.value = false;
  }

  Future<_SessionContinuationChoice?> _resolveProfileSessionChoice(
    ChatProvider chatProvider,
    String profileName,
  ) async {
    final existingSession =
        chatProvider.latestActiveSessionForProfile(profileName);
    if (existingSession == null || !mounted) {
      return _SessionContinuationChoice.startNew;
    }

    return _showExistingProfileSessionDialog(
      context,
      profileName: profileName,
    );
  }

  Future<_SessionContinuationChoice?> _resolveGroupSessionChoice(
    ChatProvider chatProvider,
    List<String> groupProfiles,
  ) async {
    final existingSession =
        chatProvider.latestActiveSessionForGroupMembers(groupProfiles);
    if (existingSession == null || !mounted) {
      return _SessionContinuationChoice.startNew;
    }

    return _showExistingGroupSessionDialog(
      context,
      profiles: groupProfiles,
    );
  }

  Future<_SessionContinuationChoice?> _showExistingProfileSessionDialog(
    BuildContext context, {
    required String profileName,
  }) {
    return showDialog<_SessionContinuationChoice>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Resume or Start New'),
        content: Text(
          'A conversation already exists for this profile. Would you like to resume your previous session or start a new session? Resuming will load the previous conversation and all its messages. Starting a new session will archive the previous conversation and start a new one. The data from the previous conversation will still be available in the database but it will be marked as archived and closed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          OutlinedButton(
            onPressed: () =>
                Navigator.pop(context, _SessionContinuationChoice.resume),
            child: const Text('Resume previous session'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, _SessionContinuationChoice.startNew),
            child: Text('Start new $profileName session'),
          ),
        ],
      ),
    );
  }

  Future<_SessionContinuationChoice?> _showExistingGroupSessionDialog(
    BuildContext context, {
    required List<String> profiles,
  }) {
    final summary = profiles.join(', ');
    return showDialog<_SessionContinuationChoice>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Resume or Start New'),
        content: Text(
          'A group conversation already exists for $summary. Would you like to resume that session or start a new group session? Starting a new session will archive and close the previous group conversation.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          OutlinedButton(
            onPressed: () =>
                Navigator.pop(context, _SessionContinuationChoice.resume),
            child: const Text('Resume previous session'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, _SessionContinuationChoice.startNew),
            child: const Text('Start new group session'),
          ),
        ],
      ),
    );
  }

  Future<void> _createSessionForProfileSelection(
    ChatProvider chatProvider,
    String profileName, {
    required bool confirmCloseActiveProfileSession,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final errorColor = Theme.of(context).colorScheme.error;

    try {
      await chatProvider.createNewSession(
        _resolveRoleForNewSession(),
        profile: profileName,
        confirmCloseActiveProfileSession: confirmCloseActiveProfileSession,
      );
    } on CoquiException catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: errorColor,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(CoquiException.friendly(e).message),
          backgroundColor: errorColor,
        ),
      );
    }
  }

  Future<void> _createSessionForGroupSelection(
    ChatProvider chatProvider, {
    required List<String> groupProfiles,
    required int groupMaxRounds,
    required bool confirmCloseActiveGroupSession,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final errorColor = Theme.of(context).colorScheme.error;

    try {
      await chatProvider.createNewSession(
        _groupSessionRole,
        groupProfiles: groupProfiles,
        groupMaxRounds: groupMaxRounds,
        confirmCloseActiveGroupSession: confirmCloseActiveGroupSession,
      );
    } on CoquiException catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: errorColor,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(CoquiException.friendly(e).message),
          backgroundColor: errorColor,
        ),
      );
    }
  }

  Future<void> _startNewSessionFromClosedNotice(
    ChatProvider chatProvider,
    CoquiSession session, {
    required bool confirmCloseActiveProfileSession,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final errorColor = Theme.of(context).colorScheme.error;

    try {
      if (session.isGroupSession) {
        await chatProvider.createNewSession(
          _groupSessionRole,
          groupProfiles: session.groupProfileNames,
          groupMaxRounds: session.groupMaxRounds,
          confirmCloseActiveGroupSession: confirmCloseActiveProfileSession,
        );
      } else {
        await chatProvider.createNewSession(
          CoquiRole(name: session.modelRole, model: session.model),
          profile: session.profile,
          confirmCloseActiveProfileSession: confirmCloseActiveProfileSession,
        );
      }
      _clearComposer();
    } on CoquiException catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: errorColor,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(CoquiException.friendly(e).message),
          backgroundColor: errorColor,
        ),
      );
    }
  }
}
