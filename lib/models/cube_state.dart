import 'dart:math' as math;
import 'cube_color.dart';

class CubeState {
  final List<CubeColor> facelets;

  CubeState(this.facelets) {
    assert(facelets.length == 54, 'Cube state must contain exactly 54 facelets');
  }

  factory CubeState.solved() {
    return CubeState(List.generate(54, (i) {
      if (i < 9) return CubeColor.white;
      if (i < 18) return CubeColor.red;
      if (i < 27) return CubeColor.green;
      if (i < 36) return CubeColor.yellow;
      if (i < 45) return CubeColor.orange;
      return CubeColor.blue;
    }));
  }

  factory CubeState.fromSingmaster(String s) {
    if (s.length != 54) {
      throw ArgumentError('Singmaster string must be 54 chars');
    }
    return CubeState(s.split('').map((c) => CubeColor.fromNotation(c)).toList());
  }

  String toSingmaster() {
    return facelets.map((c) => c.notation).join();
  }

  CubeState copyWithFacet(int index, CubeColor color) {
    final newList = List<CubeColor>.from(facelets);
    newList[index] = color;
    return CubeState(newList);
  }

  bool get isSolved {
    final solved = CubeState.solved();
    for (var i = 0; i < 54; i++) {
      if (facelets[i] != solved.facelets[i]) return false;
    }
    return true;
  }

  Map<CubeColor, int> getColorCounts() {
    final counts = <CubeColor, int>{};
    for (var c in CubeColor.values) {
      counts[c] = 0;
    }
    for (var c in facelets) {
      counts[c] = (counts[c] ?? 0) + 1;
    }
    return counts;
  }

  /// Canonical 54-element permutation maps for standard Rubik's cube face and slice moves.
  /// Exactly matches C++ CubeModel, ensuring every move produces a valid, solvable state.
  static const Map<String, List<int>> _movePermutations = {
    'U': [6, 3, 0, 7, 4, 1, 8, 5, 2, 45, 46, 47, 12, 13, 14, 15, 16, 17, 9, 10, 11, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 18, 19, 20, 39, 40, 41, 42, 43, 44, 36, 37, 38, 48, 49, 50, 51, 52, 53],
    'R': [0, 1, 20, 3, 4, 23, 6, 7, 26, 15, 12, 9, 16, 13, 10, 17, 14, 11, 18, 19, 29, 21, 22, 32, 24, 25, 35, 27, 28, 51, 30, 31, 50, 33, 34, 45, 36, 37, 38, 39, 40, 41, 42, 43, 44, 8, 46, 47, 48, 49, 5, 2, 52, 53],
    'F': [0, 1, 2, 3, 4, 5, 44, 41, 38, 6, 10, 11, 7, 13, 14, 8, 16, 17, 24, 21, 18, 25, 22, 19, 26, 23, 20, 15, 12, 9, 30, 31, 32, 33, 34, 35, 36, 37, 27, 39, 40, 28, 42, 43, 29, 45, 46, 47, 48, 49, 50, 51, 52, 53],
    'D': [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 24, 25, 26, 18, 19, 20, 21, 22, 23, 42, 43, 44, 33, 30, 27, 34, 31, 28, 35, 32, 29, 36, 37, 38, 39, 40, 41, 51, 52, 53, 45, 46, 47, 48, 49, 50, 15, 16, 17],
    'L': [53, 1, 2, 48, 4, 5, 47, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 0, 19, 20, 3, 22, 23, 6, 25, 26, 18, 28, 29, 21, 31, 32, 24, 34, 35, 42, 39, 36, 43, 40, 37, 44, 41, 38, 45, 46, 33, 30, 49, 50, 51, 52, 27],
    'B': [11, 14, 17, 3, 4, 5, 6, 7, 8, 9, 10, 35, 12, 13, 34, 15, 16, 33, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 36, 39, 42, 2, 37, 38, 1, 40, 41, 0, 43, 44, 51, 50, 45, 46, 49, 52, 53, 48, 47],
    'M': [0, 52, 2, 3, 49, 5, 6, 46, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 1, 20, 21, 4, 23, 24, 7, 26, 27, 19, 29, 30, 22, 32, 33, 25, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 34, 47, 48, 31, 50, 51, 28, 53],
    'E': [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 21, 22, 23, 15, 16, 17, 18, 19, 20, 39, 40, 41, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 48, 49, 50, 42, 43, 44, 45, 46, 47, 12, 13, 14, 51, 52, 53],
    'S': [0, 1, 2, 43, 40, 37, 6, 7, 8, 9, 3, 11, 12, 4, 14, 15, 5, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 16, 13, 10, 33, 34, 35, 36, 30, 38, 39, 31, 41, 42, 32, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53],
  };

  /// Applies a single move notation (e.g. "R", "R'", "R2", "M", "E'", etc.)
  /// and returns a new [CubeState].
  CubeState applyMove(String move) {
    final m = move.trim();
    if (m.isEmpty) return this;

    final face = m[0].toUpperCase();
    final perm = _movePermutations[face];
    if (perm == null) return this;

    int turns = 1;
    if (m.length > 1) {
      if (m.contains('2')) {
        turns = 2;
      } else if (m.contains("'") || m.contains('3')) {
        turns = 3;
      }
    }

    var cur = facelets;
    for (var i = 0; i < turns; i++) {
      cur = List<CubeColor>.generate(54, (idx) => cur[perm[idx]]);
    }
    return CubeState(cur);
  }

  /// Applies a sequence of space-separated moves (e.g. "R U R' U'").
  CubeState applyMoves(String movesSequence) {
    var cur = this;
    final tokens = movesSequence.trim().split(RegExp(r'\s+'));
    for (final token in tokens) {
      if (token.isNotEmpty) {
        cur = cur.applyMove(token);
      }
    }
    return cur;
  }

  /// Generates a randomized scramble and applies it, returning both
  /// the scrambled state and the move sequence string.
  static ({CubeState state, String scramble}) generateScramble({
    int moveCount = 22,
    math.Random? random,
  }) {
    final rng = random ?? math.Random();
    const faces = ['U', 'D', 'R', 'L', 'F', 'B'];
    const modifiers = ['', "'", '2'];

    final moves = <String>[];
    String? lastFace;
    String? secondLastFace;

    const opposites = {
      'U': 'D', 'D': 'U',
      'R': 'L', 'L': 'R',
      'F': 'B', 'B': 'F',
    };

    while (moves.length < moveCount) {
      final face = faces[rng.nextInt(faces.length)];
      if (face == lastFace) continue;
      if (face == secondLastFace && lastFace == opposites[face]) continue;

      final mod = modifiers[rng.nextInt(modifiers.length)];
      moves.add('$face$mod');
      secondLastFace = lastFace;
      lastFace = face;
    }

    final formula = moves.join(' ');
    final scrambled = CubeState.solved().applyMoves(formula);
    return (state: scrambled, scramble: formula);
  }

  /// Convenience helper to directly get a randomly scrambled [CubeState].
  static CubeState randomScramble({int moveCount = 22}) {
    return generateScramble(moveCount: moveCount).state;
  }
}
