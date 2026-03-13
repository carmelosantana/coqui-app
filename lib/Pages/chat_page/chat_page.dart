import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:responsive_framework/responsive_framework.dart';

import 'package:coqui_app/Constants/constants.dart';
import 'package:coqui_app/Models/chat_preset.dart';
import 'package:coqui_app/Models/coqui_exception.dart';
import 'package:coqui_app/Models/coqui_role.dart';
import 'package:coqui_app/Providers/chat_provider.dart';
import 'package:coqui_app/Providers/instance_provider.dart';
import 'package:coqui_app/Services/analytics_service.dart';
import 'package:coqui_app/Widgets/chat_app_bar.dart';
import 'package:coqui_app/Widgets/role_list_tile.dart';
import 'package:coqui_app/Widgets/bottom_sheet_header.dart';
import 'package:coqui_app/Widgets/selection_bottom_sheet.dart';

import 'subwidgets/subwidgets.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  // Selected role for new session creation
  CoquiRole? _selectedRole;

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
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: ChatTextField(
                key: ValueKey(chatProvider.currentSession?.id),
                controller: _textFieldController,
                focusNode: _textFieldFocusNode,
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
            child: ChatSelectRoleButton(
              currentRoleName: _selectedRole?.name,
              onPressed: () => _showRoleSelectionBottomSheet(context),
            ),
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
            onPressed: () async {
              _textFieldController.text = preset.prompt;
              _hasText.value = preset.prompt.trim().isNotEmpty;
              await _handleSendButton(chatProvider);
            },
          );
        },
      );
    } else {
      return const SizedBox();
    }
  }

  Widget _buildTextFieldSuffixIcon(ChatProvider chatProvider) {
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
    final hasSession = chatProvider.currentSession != null;
    return IconButton(
      icon: const Icon(Icons.attach_file),
      tooltip: hasSession ? 'Attach file' : 'Start a session to attach files',
      color: hasSession
          ? Theme.of(context).colorScheme.onSurface
          : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
      onPressed: hasSession ? () => _handleAttachButton(chatProvider) : null,
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
    } else if (chatProvider.currentSession == null) {
      // Use selected role, or resolve from default preference
      CoquiRole? roleToUse = _selectedRole;

      if (roleToUse == null) {
        final defaultRoleName = Hive.box('settings')
            .get('default_role', defaultValue: 'orchestrator') as String;

        // Use the default role without showing the picker
        roleToUse = CoquiRole(
          name: defaultRoleName,
          model: '', // Server resolves the model
        );
      }

      try {
        await chatProvider.createNewSession(roleToUse);
      } on CoquiException catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.message),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
        return;
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(CoquiException.friendly(e).message),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
        return;
      }

      chatProvider.sendPrompt(_textFieldController.text);
      _textFieldController.clear();
      _hasText.value = false;
    } else {
      chatProvider.sendPrompt(_textFieldController.text);
      _textFieldController.clear();
      _hasText.value = false;
    }
  }

  Future<void> _handleOnEditingComplete(ChatProvider chatProvider) async {
    if (_hasText.value && !chatProvider.isCurrentSessionStreaming) {
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
}
