import 'package:flutter/material.dart';
import '../../models/solution_step.dart';

class StepGuideCard extends StatelessWidget {
  final SolutionStep step;
  final int totalSteps;
  final VoidCallback onNext;
  final VoidCallback onPrev;
  final bool isAutoAdvance;
  final ValueChanged<bool> onToggleAutoAdvance;

  const StepGuideCard({
    Key? key,
    required this.step,
    required this.totalSteps,
    required this.onNext,
    required this.onPrev,
    required this.isAutoAdvance,
    required this.onToggleAutoAdvance,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2C).withOpacity(0.92),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12, width: 1),
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
                  color: const Color(0xFF3F51B5).withOpacity(0.4),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  step.stageName,
                  style: const TextStyle(
                    color: Color(0xFF8C9EFF),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
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
            style: const TextStyle(
              color: Color(0xFFFFD600),
              fontSize: 32,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Switch(
                value: isAutoAdvance,
                onChanged: onToggleAutoAdvance,
                activeColor: const Color(0xFF00E676),
              ),
              const Text('自动核对跳步', style: TextStyle(color: Colors.white70, fontSize: 12)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
                onPressed: step.stepIndex > 1 ? onPrev : null,
              ),
              IconButton(
                icon: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white),
                onPressed: step.stepIndex < totalSteps ? onNext : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
