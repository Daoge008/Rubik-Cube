import 'dart:convert';
import '../../models/cube_state.dart';
import '../../models/solution_step.dart';
import '../native_bridge/rubik_ffi_bridge.dart';

class SolverService {
  final RubikFfiBridge _bridge = RubikFfiBridge.instance;

  String? validateState(CubeState state) {
    return _bridge.validate(state.toSingmaster());
  }

  List<SolutionStep> solve(CubeState state, SolveMode mode) {
    final singmaster = state.toSingmaster();

    if (mode == SolveMode.kociemba) {
      final solutionString = _bridge.solveKociemba(singmaster);
      if (solutionString.startsWith("ERROR")) {
        throw Exception(solutionString);
      }
      if (solutionString == "SOLVED") {
        return [];
      }

      final moveTokens = solutionString.split(' ').where((s) => s.isNotEmpty).toList();
      return List.generate(moveTokens.length, (i) {
        final m = moveTokens[i];
        return SolutionStep(
          stepIndex: i + 1,
          moveNotation: m,
          stageName: "最少步最优解",
          visualHint: "执行标准单步转动: $m",
          explanation: "根据两阶段算法优化的核心复原步骤",
        );
      });
    } else {
      final jsonString = _bridge.generateCfopJson(singmaster);
      final List<dynamic> rawList = jsonDecode(jsonString);
      return List.generate(rawList.length, (i) {
        return SolutionStep.fromJson(i + 1, rawList[i]);
      });
    }
  }
}
