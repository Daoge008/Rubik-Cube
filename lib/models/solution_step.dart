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

  /// Named algorithms this stage is built from, in the order they are
  /// performed (for the CFOP guide). Empty for the cross / F2L stages - those
  /// are searched rather than taught as a fixed formula - and for a last layer
  /// stage that only needs the top layer rotated into place.
  final List<String> algorithms;

  bool isCompleted;

  SolutionStep({
    required this.stepIndex,
    required this.moveNotation,
    required this.stageName,
    required this.visualHint,
    required this.explanation,
    this.algorithms = const [],
    this.isCompleted = false,
  });

  factory SolutionStep.fromJson(int index, Map<String, dynamic> json) {
    final rawAlgorithms = json['algorithms'];
    return SolutionStep(
      stepIndex: index,
      moveNotation: json['formula'] ?? '',
      stageName: json['stageName'] ?? '还原步骤',
      visualHint: json['visualHint'] ?? '',
      explanation: json['explanation'] ?? '',
      algorithms: rawAlgorithms is List
          ? rawAlgorithms.map((e) => e.toString()).toList(growable: false)
          : const [],
    );
  }
}
