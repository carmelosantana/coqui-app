import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:coqui_app/Models/coqui_loop.dart';
import 'package:coqui_app/Providers/loop_provider.dart';
import 'package:coqui_app/Theme/coqui_tokens.dart';
import 'package:coqui_app/Theme/coqui_typography.dart';

/// Loop-launcher popover surfaced by the composer's `ϟ` toggle (Task 8).
///
/// A ~400px card, meant to be anchored above the composer by the caller (via an
/// Overlay/`showMenu`, wired in a later integration step). This widget only
/// builds the panel: a selectable list of loop definitions, a goal field, and a
/// Run button that starts a loop through [LoopProvider.createLoop].
///
/// Definitions are fetched exactly once, on first mount, when the provider's
/// list is empty — mirroring the Task 5 persona-rail initState pattern so an
/// empty/error result cannot re-trigger the fetch on rebuild.
class LoopLauncher extends StatefulWidget {
  const LoopLauncher({super.key, this.onClose});

  /// Invoked after a loop is started so the caller can dismiss the popover.
  final VoidCallback? onClose;

  @override
  State<LoopLauncher> createState() => _LoopLauncherState();
}

class _LoopLauncherState extends State<LoopLauncher> {
  final TextEditingController _goalController = TextEditingController();

  /// The selected definition name, or null before one is chosen. Defaults to
  /// the first definition once the list is available.
  String? _selected;

  @override
  void initState() {
    super.initState();
    _goalController.addListener(_onGoalChanged);
    // Fetch definitions exactly once for the life of this State. Tied to
    // initState (not build) so an empty result cannot re-trigger the fetch.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final provider = context.read<LoopProvider>();
      if (provider.definitions.isEmpty) {
        provider.fetchDefinitions();
      }
    });
  }

  @override
  void dispose() {
    _goalController.removeListener(_onGoalChanged);
    _goalController.dispose();
    super.dispose();
  }

  void _onGoalChanged() {
    // Rebuild so the Run button reflects the empty/non-empty goal state.
    setState(() {});
  }

  String get _goalText => _goalController.text.trim();

  bool get _canRun => _selected != null && _goalText.isNotEmpty;

  void _run() {
    if (!_canRun) {
      return;
    }
    context.read<LoopProvider>().createLoop(
          definition: _selected!,
          goal: _goalText,
        );
    widget.onClose?.call();
  }

  @override
  Widget build(BuildContext context) {
    final definitions = context.watch<LoopProvider>().definitions;

    // Default the selection to the first definition once the list is available.
    if (_selected == null && definitions.isNotEmpty) {
      _selected = definitions.first.name;
    }

    return Container(
      width: 400,
      decoration: BoxDecoration(
        color: CoquiTokens.surface.card,
        border: Border.all(color: CoquiTokens.border.normal),
        borderRadius: BorderRadius.circular(CoquiTokens.radii.card),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8, left: 2),
            child: Text(
              'Start a loop',
              style: TextStyle(
                color: CoquiTokens.text.high,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (definitions.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'No loop definitions available.',
                style: TextStyle(color: CoquiTokens.text.muted, fontSize: 12),
              ),
            )
          else
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final def in definitions)
                      _DefinitionRow(
                        key: ValueKey('loop-def-${def.name}'),
                        definition: def,
                        selected: def.name == _selected,
                        onTap: () => setState(() => _selected = def.name),
                      ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 10),
          TextField(
            key: const ValueKey('loop-goal-input'),
            controller: _goalController,
            minLines: 1,
            maxLines: 3,
            style: TextStyle(color: CoquiTokens.text.high, fontSize: 13),
            cursorColor: CoquiTokens.brand.primaryLime,
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: CoquiTokens.surface.input,
              hintText: 'What should this loop accomplish?',
              hintStyle: TextStyle(color: CoquiTokens.text.muted, fontSize: 13),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(CoquiTokens.radii.input),
                borderSide: BorderSide(color: CoquiTokens.border.normal),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(CoquiTokens.radii.input),
                borderSide: BorderSide(color: CoquiTokens.border.normal),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(CoquiTokens.radii.input),
                borderSide: BorderSide(color: CoquiTokens.brand.primaryLime),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _RunButton(
            key: const ValueKey('loop-run'),
            enabled: _canRun,
            onTap: _run,
          ),
        ],
      ),
    );
  }
}

/// One selectable definition row: a leading glyph, the name, and the role chain
/// rendered in mono. The selected row shows a lime accent ring.
class _DefinitionRow extends StatelessWidget {
  const _DefinitionRow({
    super.key,
    required this.definition,
    required this.selected,
    required this.onTap,
  });

  final CoquiLoopDefinition definition;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final roleChain = definition.roles.map((r) => r.role).join(' → ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(CoquiTokens.radii.md),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? CoquiTokens.surface.hover
                : Colors.transparent,
            borderRadius: BorderRadius.circular(CoquiTokens.radii.md),
            border: Border.all(
              color: selected
                  ? CoquiTokens.brand.primaryLime
                  : CoquiTokens.border.hairline,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.all_inclusive,
                size: 16,
                color: selected
                    ? CoquiTokens.brand.primaryLime
                    : CoquiTokens.text.muted,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      definition.name,
                      style: TextStyle(
                        color: CoquiTokens.text.high,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (roleChain.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        roleChain,
                        style: CoquiTypography.mono(
                          color: CoquiTokens.text.muted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The Run button. Fills with [CoquiTokens.brand.primaryLime] when [enabled];
/// otherwise it rests dimmed and ignores taps.
class _RunButton extends StatelessWidget {
  const _RunButton({
    super.key,
    required this.enabled,
    required this.onTap,
  });

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Run loop',
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(CoquiTokens.radii.input),
        child: Container(
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: enabled
                ? CoquiTokens.brand.primaryLime
                : CoquiTokens.surface.sendResting,
            borderRadius: BorderRadius.circular(CoquiTokens.radii.input),
          ),
          child: Text(
            'Run',
            style: TextStyle(
              color: enabled
                  ? CoquiTokens.brand.onPrimary
                  : CoquiTokens.text.muted,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
