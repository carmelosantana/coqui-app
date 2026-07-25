import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:coqui_app/Models/coqui_loop.dart';
import 'package:coqui_app/Pages/shell/shell_controller.dart';
import 'package:coqui_app/Providers/loop_provider.dart';
import 'package:coqui_app/Theme/coqui_tokens.dart';
import 'package:coqui_app/Theme/coqui_typography.dart';

/// The 300px slide-in right panel monitoring a single agent [CoquiLoop].
///
/// Opened by tapping a loop card ([ShellController.openLoopPanel]); reads the
/// active loop from [LoopProvider] by [ShellController.activeLoopId]. On first
/// build it kicks off a one-time [LoopProvider.loadLoopDetail] to populate the
/// iteration/stage detail, then renders header, TOKENS/ELAPSED stat tiles, a
/// per-iteration timeline, and Pause/Resume + Stop controls.
///
/// NOTE: This panel binds to the existing [LoopProvider] snapshot, which is
/// refreshed by the app's normal loop fetches (list + detail + transition
/// re-fetch). Live SSE streaming of stage updates (a `/loops/{id}/events`
/// endpoint) is a deferred follow-up and is intentionally not wired here.
class LoopMonitor extends StatefulWidget {
  const LoopMonitor({super.key});

  @override
  State<LoopMonitor> createState() => _LoopMonitorState();
}

class _LoopMonitorState extends State<LoopMonitor> {
  @override
  void initState() {
    super.initState();
    // Populate the loop detail exactly once for the life of this State. Tied to
    // initState (not build), a null/empty result cannot re-trigger a refetch.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final loopId = context.read<ShellController>().activeLoopId;
      if (loopId != null) {
        context.read<LoopProvider>().loadLoopDetail(loopId);
      }
    });
  }

  String _formatDuration(Duration d) {
    if (d.isNegative) {
      return '—';
    }
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    }
    return '${seconds}s';
  }

  String _elapsedLabel(CoquiLoop loop) {
    final start = loop.startedAt;
    if (start == null) {
      return '—';
    }
    final end = loop.completedAt ?? loop.lastActivityAt ?? start;
    return _formatDuration(end.difference(start));
  }

  Color _iterationColor(String status) {
    switch (status) {
      case 'done':
      case 'complete':
      case 'completed':
        return CoquiTokens.status.online;
      case 'running':
        return CoquiTokens.brand.primaryLime;
      case 'failed':
      case 'error':
        return CoquiTokens.status.error;
      default:
        return CoquiTokens.text.muted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeLoopId = context.watch<ShellController>().activeLoopId;
    final loopProvider = context.watch<LoopProvider>();
    final loop =
        activeLoopId == null ? null : loopProvider.loopById(activeLoopId);

    return Container(
      width: CoquiTokens.loopPanelWidth,
      color: CoquiTokens.surface.sessionRail,
      child: loop == null
          ? _buildEmpty(context)
          : _buildMonitor(context, loopProvider, loop),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(context, 'Loop monitor'),
        Expanded(
          child: Center(
            child: Text(
              'No loop selected',
              style: TextStyle(color: CoquiTokens.text.muted),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMonitor(
    BuildContext context,
    LoopProvider loopProvider,
    CoquiLoop loop,
  ) {
    final iterations =
        loopProvider.iterationsForLoop(loop.id);
    final tokens =
        loop.metadata['tokens'] ?? loop.metadata['token_count'] ?? '—';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(
          context,
          loop.definitionName.isNotEmpty ? loop.definitionName : 'Loop',
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: _StatTile(label: 'TOKENS', value: '$tokens'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatTile(
                  label: 'ELAPSED',
                  value: _elapsedLabel(loop),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: iterations.isEmpty
              ? Center(
                  child: Text(
                    'No iterations yet',
                    style: TextStyle(color: CoquiTokens.text.muted),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: iterations.length,
                  itemBuilder: (context, index) =>
                      _IterationRow(iteration: iterations[index], color: _iterationColor(iterations[index].status)),
                ),
        ),
        _controls(context, loopProvider, loop),
      ],
    );
  }

  Widget _header(BuildContext context, String title) {
    return Container(
      height: CoquiTokens.channelHeader,
      padding: const EdgeInsets.only(left: 14, right: 6),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: CoquiTokens.border.hairline),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: CoquiTokens.text.high,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            key: const ValueKey('loop-monitor-close'),
            icon: Icon(Icons.close, size: 18, color: CoquiTokens.text.muted),
            onPressed: () => context.read<ShellController>().closeLoopPanel(),
          ),
        ],
      ),
    );
  }

  Widget _controls(
    BuildContext context,
    LoopProvider loopProvider,
    CoquiLoop loop,
  ) {
    final disabled = loop.isFinished;
    final isPaused = loop.isPaused;
    final pauseLabel = isPaused ? 'Resume' : 'Pause';

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              key: const ValueKey('loop-pause'),
              onPressed: disabled
                  ? null
                  : () {
                      if (isPaused) {
                        loopProvider.resumeLoop(loop.id);
                      } else {
                        loopProvider.pauseLoop(loop.id);
                      }
                    },
              child: Text(pauseLabel),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton(
              key: const ValueKey('loop-stop'),
              style: OutlinedButton.styleFrom(
                foregroundColor: CoquiTokens.status.error,
              ),
              onPressed: disabled ? null : () => loopProvider.stopLoop(loop.id),
              child: const Text('Stop'),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: CoquiTokens.surface.card,
        border: Border.all(color: CoquiTokens.border.normal),
        borderRadius: BorderRadius.circular(CoquiTokens.radii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: CoquiTypography.mono(
              size: 9.5,
              color: CoquiTokens.text.muted,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: CoquiTokens.text.high,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _IterationRow extends StatelessWidget {
  const _IterationRow({required this.iteration, required this.color});

  final CoquiLoopIteration iteration;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 3),
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ITER ${iteration.iterationNumber}',
                  style: CoquiTypography.mono(
                    size: 11,
                    color: CoquiTokens.text.secondary,
                    letterSpacing: 0.4,
                  ),
                ),
                if (iteration.outcomeSummary != null &&
                    iteration.outcomeSummary!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    iteration.outcomeSummary!,
                    style: TextStyle(
                      color: CoquiTokens.text.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
