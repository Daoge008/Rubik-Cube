import 'package:flutter/material.dart';
import '../../models/solution_step.dart';

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

  const StepGuideCard({
    Key? key,
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
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isLastStep = step.stepIndex >= totalSteps;
    final canPrev = !isAnimating && !isAutoPlaying && step.stepIndex > 1;
    final canNext = !isAnimating && !isAutoPlaying;
    final canReplay = !isAnimating && !isAutoPlaying && onReplay != null;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2C).withOpacity(0.92),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isLastStep ? const Color(0xFF00E676).withOpacity(0.5) : Colors.white12,
          width: isLastStep ? 1.5 : 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
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
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (isAutoPlaying)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
                      SizedBox(width: 6),
                      Text(
                        '自动播放中',
                        style: TextStyle(color: Color(0xFF00E676), fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                )
              else if (isAnimating)
                const Text(
                  '转动中...',
                  style: TextStyle(color: Color(0xFFFFD600), fontSize: 12, fontWeight: FontWeight.bold),
                ),
              Text(
                '第 ${step.stepIndex} / $totalSteps 步',
                style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            step.moveNotation,
            style: TextStyle(
              color: isAnimating ? const Color(0xFFFFAB00) : const Color(0xFFFFD600),
              fontSize: 32,
              fontWeight: FontWeight.w900,
              letterSpacing: 2.0,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Switch(
                value: isAutoAdvance,
                onChanged: isAutoPlaying ? null : onToggleAutoAdvance,
                activeColor: const Color(0xFF00E676),
              ),
              const Text('自动核对', style: TextStyle(color: Colors.white70, fontSize: 12)),
              const Spacer(),
              // Prev step
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
                color: canPrev ? Colors.white : Colors.white24,
                tooltip: '上一步',
                onPressed: canPrev ? onPrev : null,
              ),
              // Replay button
              if (onReplay != null)
                IconButton(
                  icon: const Icon(Icons.replay_rounded, size: 22),
                  color: canReplay ? const Color(0xFF40C4FF) : Colors.white24,
                  tooltip: '重播本步',
                  onPressed: canReplay ? onReplay : null,
                ),
              // Auto-play button
              if (onToggleAutoPlay != null)
                IconButton(
                  icon: Icon(
                    isAutoPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
                    size: 26,
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
                  icon: const Icon(Icons.arrow_forward_ios_rounded, size: 20),
                  color: canNext ? Colors.white : Colors.white24,
                  tooltip: '下一步',
                  onPressed: canNext ? onNext : null,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
