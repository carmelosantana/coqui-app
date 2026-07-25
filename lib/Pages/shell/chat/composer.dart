import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:coqui_app/Providers/chat_provider.dart';
import 'package:coqui_app/Theme/coqui_tokens.dart';

/// Discord-style message composer mounted at the bottom of the chat column.
///
/// Left-to-right: a `+` attach button, a `ϟ` loop-launcher toggle, the text
/// input, and an `↑` send button. The send button fills with
/// [CoquiTokens.brand.primaryLime] only while the trimmed input is non-empty;
/// otherwise it rests at [CoquiTokens.surface.sendResting].
class Composer extends StatefulWidget {
  const Composer({super.key});

  @override
  State<Composer> createState() => _ComposerState();
}

class _ComposerState extends State<Composer> {
  final TextEditingController _controller = TextEditingController();

  /// Whether the loop-launcher popover is toggled open. Drives the lime fill
  /// on the `ϟ` button. Task 10 anchors the actual popover to this flag.
  bool _launcherOpen = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onInputChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onInputChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onInputChanged() {
    // Rebuild so the send button reflects the empty/non-empty state.
    setState(() {});
  }

  bool get _canSend => _controller.text.trim().isNotEmpty;

  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(allowMultiple: true);
      if (result == null || result.files.isEmpty) return;
      if (!mounted) return;
      await context.read<ChatProvider>().attachFiles(result.files);
    } catch (_) {
      // Swallow picker cancellation / platform errors; nothing to send.
    }
  }

  void _toggleLauncher() {
    setState(() => _launcherOpen = !_launcherOpen);
    // Task 10 mounts the LoopLauncher popover anchored here when _launcherOpen.
  }

  void _send() {
    if (!_canSend) return;
    final text = _controller.text.trim();
    context.read<ChatProvider>().sendPrompt(text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final sendActive = _canSend;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Container(
        decoration: BoxDecoration(
          color: CoquiTokens.surface.input,
          borderRadius: BorderRadius.circular(CoquiTokens.radii.input),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            _IconButton(
              buttonKey: const ValueKey('composer-attach'),
              icon: Icons.add,
              foreground: CoquiTokens.text.high,
              onTap: _pickFiles,
              tooltip: 'Attach files',
            ),
            const SizedBox(width: 4),
            _IconButton(
              buttonKey: const ValueKey('composer-loop'),
              icon: Icons.bolt,
              foreground: _launcherOpen
                  ? CoquiTokens.brand.onPrimary
                  : CoquiTokens.text.high,
              background:
                  _launcherOpen ? CoquiTokens.brand.primaryLime : null,
              onTap: _toggleLauncher,
              tooltip: 'Loop launcher',
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                key: const ValueKey('composer-input'),
                controller: _controller,
                minLines: 1,
                maxLines: 6,
                textInputAction: TextInputAction.newline,
                style: TextStyle(color: CoquiTokens.text.high),
                cursorColor: CoquiTokens.brand.primaryLime,
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: 'Message…',
                  hintStyle: TextStyle(color: CoquiTokens.text.muted),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _IconButton(
              buttonKey: const ValueKey('composer-send'),
              icon: Icons.arrow_upward,
              foreground: sendActive
                  ? CoquiTokens.brand.onPrimary
                  : CoquiTokens.text.muted,
              background: sendActive
                  ? CoquiTokens.brand.primaryLime
                  : CoquiTokens.surface.sendResting,
              onTap: sendActive ? _send : null,
              tooltip: 'Send',
            ),
          ],
        ),
      ),
    );
  }
}

/// A compact rounded control button. Its own [Container] carries the
/// [BoxDecoration] whose `color` a test can read for the send-enable state.
class _IconButton extends StatelessWidget {
  const _IconButton({
    required this.buttonKey,
    required this.icon,
    required this.foreground,
    required this.onTap,
    this.background,
    this.tooltip,
  });

  final Key buttonKey;
  final IconData icon;
  final Color foreground;
  final Color? background;
  final VoidCallback? onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: buttonKey,
      child: Semantics(
        button: true,
        label: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(CoquiTokens.radii.sm),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: background ?? Colors.transparent,
              borderRadius: BorderRadius.circular(CoquiTokens.radii.sm),
            ),
            child: Icon(icon, size: 18, color: foreground),
          ),
        ),
      ),
    );
  }
}
