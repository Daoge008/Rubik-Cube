import 'package:flutter/material.dart';
import '../../models/solution_step.dart';
import '../../core/solver/move_explainer.dart';
import 'beginner_guide_sheet.dart';

class StepGuideCard extends StatelessWidget {
  final SolutionStep step;
  final int totalSteps;
  final VoidCallback onNext;
  final VoidCallback onPrev;
  final VoidCallback? onReplay;
  final bool isAnimating;
  final bool isAutoPlaying;
  final VoidCallback? onToggleAutoPlay;
  final bool isAutoAdvance;
  final ValueChanged<bool> onToggleAutoAdvance;
  final VoidCallback? onHelp;

  const StepGuideCard({
    super.key,
    required this.step,
    required this.totalSteps,
    required this.onNext,
    required this.onPrev,
    this.onReplay,
    this.isAnimating = false,
    this.isAutoPlaying = false,
    this.onToggleAutoPlay,
    required this.isAutoAdvance,
    required this.onToggleAutoAdvance,
    this.onHelp,
  });

  @override
  Widget build(BuildContext context) {
    final isLastStep = step.stepIndex >= totalSteps;
    final canPrev = !isAnimating && !isAutoPlaying && step.stepIndex > 1;
    final canNext = !isAnimating && !isAutoPlaying;
    final canReplay = !isAnimating && !isAutoPlaying && onReplay != null;

    final mnemonic = MoveExplainer.translateSequence(step.moveNotation);
    final explanations = MoveExplainer.explainSequence(step.moveNotation);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2C).withOpacity(0.95),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isLastStep ? const Color(0xFF00E676).withOpacity(0.5) : Colors.white12,
          width: isLastStep ? 1.5 : 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: Stage badge + status / step counter
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isLastStep
                        ? const Color(0xFF00E676).withOpacity(0.2)
                        : const Color(0xFF3F51B5).withOpacity(0.4),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isLastStep ? '终步：完成复原' : step.stageName,
                    style: TextStyle(
                      color: isLastStep ? const Color(0xFF00E676) : const Color(0xFF8C9EFF),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isAutoPlaying)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00E676).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF00E676), width: 0.8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 8,
                            height: 8,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              valueColor: AlwaysStoppedAnimation(Color(0xFF00E676)),
                            ),
                          ),
                          SizedBox(width: 4),
                          Text(
                            '演示中',
                            style: TextStyle(color: Color(0xFF00E676), fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    )
                  else if (isAnimating)
                    const Text(
                      '转动中...',
                      style: TextStyle(color: Color(0xFFFFD600), fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  const SizedBox(width: 6),
                  Text(
                    '第 ${step.stepIndex} / $totalSteps 步',
                    style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Big Move Notation
          Center(
            child: Text(
              step.moveNotation,
              style: TextStyle(
                color: isAnimating ? const Color(0xFFFFAB00) : const Color(0xFFFFD600),
                fontSize: 32,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.0,
              ),
            ),
          ),

          // Beginner Mnemonic / Plain Chinese translation + Beginner Help
          if (mnemonic.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.record_voice_over_rounded, color: Color(0xFF8C9EFF), size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '口诀：$mnemonic',
                      style: const TextStyle(
                        color: Color(0xFFE0E0E0),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: () {
                      if (onHelp != null) {
                        onHelp!();
                      } else {
                        BeginnerGuideSheet.show(context);
                      }
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white24, width: 0.8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.help_outline_rounded, color: Color(0xFF40C4FF), size: 13),
                          SizedBox(width: 3),
                          Text(
                            '新手帮助',
                            style: TextStyle(color: Color(0xFF40C4FF), fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: InkWell(
                onTap: () {
                  if (onHelp != null) {
                    onHelp!();
                  } else {
                    BeginnerGuideSheet.show(context);
                  }
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white24, width: 0.8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.help_outline_rounded, color: Color(0xFF40C4FF), size: 13),
                      SizedBox(width: 4),
                      Text(
                        '新手帮助',
                        style: TextStyle(color: Color(0xFF40C4FF), fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],

          // Visual move tokens breakdown (chips)
          if (explanations.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              alignment: WrapAlignment.center,
              children: explanations.map((e) {
                return Tooltip(
                  message: e.detail,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF28283C),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: e.faceColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '${e.token}: ${e.action}',
                          style: const TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],

          // Stage Hint / Explanation if available
          if (step.visualHint.isNotEmpty && !step.visualHint.startsWith('执行标准单步转动:')) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF263238),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lightbulb_outline_rounded, color: Color(0xFFFFD54F), size: 15),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      step.visualHint,
                      style: const TextStyle(color: Color(0xFFFFECB3), fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),

          // Bottom Control Row
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                Switch(
                  value: isAutoAdvance,
                  onChanged: isAutoPlaying ? null : onToggleAutoAdvance,
                  activeColor: const Color(0xFF00E676),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                const SizedBox(width: 4),
                const Text('自动核对', style: TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(width: 12),
                // Prev step
                IconButton(
                  padding: const EdgeInsets.all(6),
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  icon: const Icon(Icons.arrow_back_ios_rounded, size: 18),
                  color: canPrev ? Colors.white : Colors.white24,
                  tooltip: '上一步',
                  onPressed: canPrev ? onPrev : null,
                ),
                // Replay button
                if (onReplay != null)
                  IconButton(
                    padding: const EdgeInsets.all(6),
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    icon: const Icon(Icons.replay_rounded, size: 20),
                    color: canReplay ? const Color(0xFF40C4FF) : Colors.white24,
                    tooltip: '重播本步',
                    onPressed: canReplay ? onReplay : null,
                  ),
                // Auto-play button
                if (onToggleAutoPlay != null)
                  IconButton(
                    padding: const EdgeInsets.all(6),
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    icon: Icon(
                      isAutoPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
                      size: 24,
                    ),
                    color: isAutoPlaying ? const Color(0xFFFF5252) : const Color(0xFF00E676),
                    tooltip: isAutoPlaying ? '暂停演示' : '连续演示',
                    onPressed: isAnimating && !isAutoPlaying ? null : onToggleAutoPlay,
                  ),
                // Next step or Finish
                if (isLastStep)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00E676),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: const Size(80, 36),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.check_circle_rounded, size: 18),
                    label: const Text(
                      '完成复原',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    onPressed: canNext ? onNext : null,
                  )
                else
                  IconButton(
                    padding: const EdgeInsets.all(6),
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    icon: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
                    color: canNext ? Colors.white : Colors.white24,
                    tooltip: '下一步',
                    onPressed: canNext ? onNext : null,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
