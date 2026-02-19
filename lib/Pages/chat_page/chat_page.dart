import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:responsive_framework/responsive_framework.dart';

import 'package:coqui_app/Constants/constants.dart';
import 'package:coqui_app/Models/chat_preset.dart';
import 'package:coqui_app/Models/coqui_exception.dart';
import 'package:coqui_app/Models/coqui_role.dart';
import 'package:coqui_app/Providers/chat_provider.dart';
import 'package:coqui_app/Providers/instance_provider.dart';
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
  List<ChatPreset> _presets = ChatPresets.randomPresets;

  // Text field controller for the chat prompt
  final _textFieldController = TextEditingController();
  bool get _isTextFieldHasText => _textFieldController.text.trim().isNotEmpty;

  // Welcome screen animation state
  var _crossFadeState = CrossFadeState.showFirst;
  double _scale = 1.0;

  @override
  void initState() {
    super.initState();

    // Refresh sessions on launch
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      chatProvider.refreshSessions();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatProvider>(
      builder: (BuildContext context, ChatProvider chatProvider, _) {
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
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: ChatTextField(
                key: ValueKey(chatProvider.currentSession?.id),
                controller: _textFieldController,
                onChanged: (_) => setState(() {}),
                onEditingComplete: () => _handleOnEditingComplete(chatProvider),
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
              setState(() => _textFieldController.text = preset.prompt);
              await _handleSendButton(chatProvider);
            },
          );
        },
      );
    } else {
      return const SizedBox();
    }
  }

  Widget? _buildTextFieldSuffixIcon(ChatProvider chatProvider) {
    if (chatProvider.isCurrentSessionStreaming) {
      return IconButton(
        icon: const Icon(Icons.stop_rounded),
        color: Theme.of(context).colorScheme.onSurface,
        onPressed: () {
          chatProvider.cancelCurrentStreaming();
        },
      );
    } else if (_isTextFieldHasText) {
      return IconButton(
        icon: const Icon(Icons.arrow_upward_rounded),
        color: Theme.of(context).colorScheme.onSurface,
        onPressed: () async {
          await _handleSendButton(chatProvider);
        },
      );
    } else {
      return null;
    }
  }

  void _resetChat() {
    _selectedRole = null;
    _presets = ChatPresets.randomPresets;
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
              content: Text('Failed to create session: $e'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
        return;
      }

      chatProvider.sendPrompt(_textFieldController.text);

      setState(() {
        _textFieldController.clear();
      });
    } else {
      chatProvider.sendPrompt(_textFieldController.text);

      setState(() {
        _textFieldController.clear();
      });
    }
  }

  Future<void> _handleOnEditingComplete(ChatProvider chatProvider) async {
    if (_isTextFieldHasText && !chatProvider.isCurrentSessionStreaming) {
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
      setState(() {
        _selectedRole = selectedRole;
      });
    }
  }
}
