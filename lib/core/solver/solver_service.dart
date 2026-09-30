import 'dart:convert';
import '../../models/cube_state.dart';
import '../../models/solution_step.dart';
import '../native_bridge/rubik_ffi_bridge.dart';

class SolverService {
  final RubikFfiBridge _bridge = RubikFfiBridge.instance;

  String? validateState(CubeState state) {
    final norm = state.normalizeOrientation().normalized;
    return _bridge.validate(norm.toSingmaster());
  }

  List<SolutionStep> solve(CubeState state, SolveMode mode) {
    final normRes = state.normalizeOrientation();
    final norm = normRes.normalized;
    final mapMove = normRes.mapMove;

    final singmaster = norm.toSingmaster();

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
        final normMove = moveTokens[i];
        final mappedMove = mapMove(normMove);
        return SolutionStep(
          stepIndex: i + 1,
          moveNotation: mappedMove,
          stageName: "最少步最优解 (Kociemba)",
          visualHint: "执行标准单步转动: $mappedMove",
          explanation: "根据两阶段算法优化的核心复原步骤",
        );
      });
    } else {
      final jsonString = _bridge.generateCfopJson(singmaster);
      final List<dynamic> rawList = jsonDecode(jsonString);
      return List.generate(rawList.length, (i) {
        final raw = rawList[i];
        final normMoves = (raw['formula'] ?? raw['moves'] ?? '') as String;
        final mappedFormula = normMoves
            .trim()
            .split(RegExp(r'\s+'))
            .where((s) => s.isNotEmpty)
            .map(mapMove)
            .join(' ');
        final updatedJson = Map<String, dynamic>.from(raw);
        updatedJson['formula'] = mappedFormula;
        return SolutionStep.fromJson(i + 1, updatedJson);
      });
    }
  }
}
