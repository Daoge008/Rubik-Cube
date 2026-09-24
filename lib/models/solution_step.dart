enum SolveMode {
  kociemba,
  cfop,
}

class SolutionStep {
  final int stepIndex;
  final String moveNotation;
  final String stageName;
  final String visualHint;
  final String explanation;
  bool isCompleted;

  SolutionStep({
    required this.stepIndex,
    required this.moveNotation,
    required this.stageName,
    required this.visualHint,
    required this.explanation,
    this.isCompleted = false,
  });

  factory SolutionStep.fromJson(int index, Map<String, dynamic> json) {
    return SolutionStep(
      stepIndex: index,
      moveNotation: json['formula'] ?? '',
      stageName: json['stageName'] ?? '还原步骤',
      visualHint: json['visualHint'] ?? '',
      explanation: json['explanation'] ?? '',
    );
  }
}
