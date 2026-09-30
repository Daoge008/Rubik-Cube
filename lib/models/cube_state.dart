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
    for (var f = 0; f < 6; f++) {
      final centerColor = facelets[f * 9 + 4];
      for (var i = 0; i < 9; i++) {
        if (facelets[f * 9 + i] != centerColor) return false;
      }
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

  /// Cycles 4 strips of 3 facelets each: a -> b -> c -> d -> a.
  static void _cycleStrips(
    List<CubeColor> list,
    List<int> a,
    List<int> b,
    List<int> c,
    List<int> d,
  ) {
    final temp = [list[d[0]], list[d[1]], list[d[2]]];
    list[d[0]] = list[c[0]];
    list[d[1]] = list[c[1]];
    list[d[2]] = list[c[2]];

    list[c[0]] = list[b[0]];
    list[c[1]] = list[b[1]];
    list[c[2]] = list[b[2]];

    list[b[0]] = list[a[0]];
    list[b[1]] = list[a[1]];
    list[b[2]] = list[a[2]];

    list[a[0]] = temp[0];
    list[a[1]] = temp[1];
    list[a[2]] = temp[2];
  }

  /// Exact 54-facelet permutation maps derived directly from Kociemba C++ move engine:
  /// new_facelets[i] = old_facelets[map[i]]
  static const List<int> _moveMapU = [
    6, 3, 0, 7, 4, 1, 8, 5, 2,
    45, 46, 47, 12, 13, 14, 15, 16, 17,
    9, 10, 11, 21, 22, 23, 24, 25, 26,
    27, 28, 29, 30, 31, 32, 33, 34, 35,
    18, 19, 20, 39, 40, 41, 42, 43, 44,
    36, 37, 38, 48, 49, 50, 51, 52, 53
  ];

  static const List<int> _moveMapR = [
    0, 1, 20, 3, 4, 23, 6, 7, 26,
    15, 12, 9, 16, 13, 10, 17, 14, 11,
    18, 19, 29, 21, 22, 32, 24, 25, 35,
    27, 28, 51, 30, 31, 50, 33, 34, 45,
    36, 37, 38, 39, 40, 41, 42, 43, 44,
    8, 46, 47, 48, 49, 5, 2, 52, 53
  ];

  static const List<int> _moveMapF = [
    0, 1, 2, 3, 4, 5, 44, 41, 38,
    6, 10, 11, 7, 13, 14, 8, 16, 17,
    24, 21, 18, 25, 22, 19, 26, 23, 20,
    15, 12, 9, 30, 31, 32, 33, 34, 35,
    36, 37, 27, 39, 40, 28, 42, 43, 29,
    45, 46, 47, 48, 49, 50, 51, 52, 53
  ];

  static const List<int> _moveMapD = [
    0, 1, 2, 3, 4, 5, 6, 7, 8,
    9, 10, 11, 12, 13, 14, 24, 25, 26,
    18, 19, 20, 21, 22, 23, 42, 43, 44,
    33, 30, 27, 34, 31, 28, 35, 32, 29,
    36, 37, 38, 39, 40, 41, 51, 52, 53,
    45, 46, 47, 48, 49, 50, 15, 16, 17
  ];

  static const List<int> _moveMapL = [
    53, 1, 2, 48, 4, 5, 47, 7, 8,
    9, 10, 11, 12, 13, 14, 15, 16, 17,
    0, 19, 20, 3, 22, 23, 6, 25, 26,
    18, 28, 29, 21, 31, 32, 24, 34, 35,
    42, 39, 36, 43, 40, 37, 44, 41, 38,
    45, 46, 33, 30, 49, 50, 51, 52, 27
  ];

  static const List<int> _moveMapB = [
    11, 14, 17, 3, 4, 5, 6, 7, 8,
    9, 10, 35, 12, 13, 34, 15, 16, 33,
    18, 19, 20, 21, 22, 23, 24, 25, 26,
    27, 28, 29, 30, 31, 32, 36, 39, 42,
    2, 37, 38, 1, 40, 41, 0, 43, 44,
    51, 50, 45, 46, 49, 52, 53, 48, 47
  ];

  /// Applies one single-layer clockwise 90° turn for face 'U', 'D', 'R', 'L', 'F', 'B'.
  static void _applyBaseMoveCW(List<CubeColor> list, String face) {
    final List<int>? map;
    switch (face) {
      case 'U': map = _moveMapU; break;
      case 'R': map = _moveMapR; break;
      case 'F': map = _moveMapF; break;
      case 'D': map = _moveMapD; break;
      case 'L': map = _moveMapL; break;
      case 'B': map = _moveMapB; break;
      default: map = null;
    }
    if (map != null) {
      final copy = List<CubeColor>.from(list);
      for (var i = 0; i < 54; i++) {
        list[i] = copy[map[i]];
      }
    }
  }


  /// Applies a single move notation (e.g. "R", "R'", "R2", "M", "E'", etc.)
  /// and returns a new [CubeState].
  CubeState applyMove(String move) {
    final m = move.trim();
    if (m.isEmpty) return this;

    final face = m[0].toUpperCase();

    int turns = 1;
    if (m.length > 1) {
      if (m.contains('2')) {
        turns = 2;
      } else if (m.contains("'") || m.contains('3')) {
        turns = 3;
      }
    }

    // Middle-layer slice moves: M, E, S
    if (['M', 'E', 'S'].contains(face)) {
      final newList = List<CubeColor>.from(facelets);
      for (var i = 0; i < turns; i++) {
        _applySliceMoveCW(newList, face);
      }
      return CubeState(newList);
    }

    if (!['U', 'D', 'R', 'L', 'F', 'B'].contains(face)) {
      return this;
    }

    final newList = List<CubeColor>.from(facelets);
    for (var i = 0; i < turns; i++) {
      _applyBaseMoveCW(newList, face);
    }
    return CubeState(newList);
  }

  /// Middle-layer slice moves (no face rotation, only the inner 3 cells).
  ///
  /// M  – middle column, moves like L (L direction = up on front face)
  /// E  – equatorial row, moves like D (D direction = right on front face)
  /// S  – standing slice, moves like F
  static void _applySliceMoveCW(List<CubeColor> list, String slice) {
    switch (slice) {
      case 'M':
        // Middle column (col=1), same direction as L clockwise:
        //   U col1 → F col1 → D col1 → B col1(reversed) → U col1
        _cycleStrips(
          list,
          [1, 4, 7],     // U middle col (top to bot)
          [18 + 1, 18 + 4, 18 + 7], // F middle col
          [27 + 1, 27 + 4, 27 + 7], // D middle col (top to bot, parallel to L)
          [45 + 7, 45 + 4, 45 + 1], // B middle col (reversed)
        );
        break;

      case 'E':
        // Equatorial row (row=1), same direction as D clockwise:
        //   R gets F, B gets R (reversed), L gets B (reversed), F gets L
        final copyE = List<CubeColor>.from(list);
        list[12] = copyE[21];
        list[13] = copyE[22];
        list[14] = copyE[23];

        list[50] = copyE[12];
        list[49] = copyE[13];
        list[48] = copyE[14];

        list[39] = copyE[50];
        list[40] = copyE[49];
        list[41] = copyE[48];

        list[21] = copyE[39];
        list[22] = copyE[40];
        list[23] = copyE[41];
        break;

      case 'S':
        // Standing slice (between F and B), same direction as F clockwise:
        //   U row1 → R col1 → D row1(rev) → L col1(rev) → U row1
        _cycleStrips(
          list,
          [3, 4, 5],               // U middle row
          [9 + 1, 9 + 4, 9 + 7],  // R middle col (top to bot)
          [27 + 5, 27 + 4, 27 + 3], // D middle row (reversed)
          [36 + 7, 36 + 4, 36 + 1], // L middle col (reversed)
        );
        break;
    }
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

  /// Whole-cube rotation around the X axis (like R, R-L axis).
  CubeState rotateCubeX() => applyMoves("R M' L'");

  /// Whole-cube rotation around the X axis counter-clockwise (like R').
  CubeState rotateCubeXPrime() => applyMoves("R' M L");

  /// Whole-cube rotation around the Y axis (like U, U-D axis).
  CubeState rotateCubeY() => applyMoves("U E' D'");

  /// Whole-cube rotation around the Y axis counter-clockwise (like U').
  CubeState rotateCubeYPrime() => applyMoves("U' E D");

  /// Whole-cube rotation around the Z axis (like F, F-B axis).
  CubeState rotateCubeZ() => applyMoves("F S B'");

  /// Whole-cube rotation around the Z axis counter-clockwise (like F').
  CubeState rotateCubeZPrime() => applyMoves("F' S' B");

  /// Normalizes this cube's 3D orientation so that the White center is on U (facet 4)
  /// and Green center is on F (facet 22).
  ///
  /// This enables the solver to solve cubes with any center orientation (including
  /// cubes scrambled with middle-slice moves M, E, S or rotated in 3D space).
  ///
  /// Returns both the canonical [CubeState] and a function to map moves from
  /// the canonical orientation back to this cube's current orientation.
  ({CubeState normalized, String Function(String) mapMove}) normalizeOrientation() {
    final centerColors = {
      facelets[4],
      facelets[13],
      facelets[22],
      facelets[31],
      facelets[40],
      facelets[49],
    };
    if (centerColors.length != 6 ||
        !centerColors.contains(CubeColor.white) ||
        !centerColors.contains(CubeColor.green)) {
      return (normalized: this, mapMove: (String m) => m);
    }

    var cur = this;
    // Step 1: bring White center to U (facet 4)
    if (cur.facelets[31] == CubeColor.white) {
      cur = cur.rotateCubeX().rotateCubeX();
    } else if (cur.facelets[22] == CubeColor.white) {
      cur = cur.rotateCubeX();
    } else if (cur.facelets[49] == CubeColor.white) {
      cur = cur.rotateCubeXPrime();
    } else if (cur.facelets[40] == CubeColor.white) {
      cur = cur.rotateCubeZ();
    } else if (cur.facelets[13] == CubeColor.white) {
      cur = cur.rotateCubeZPrime();
    }

    // Step 2: bring Green center to F (facet 22)
    if (cur.facelets[13] == CubeColor.green) {
      cur = cur.rotateCubeY();
    } else if (cur.facelets[49] == CubeColor.green) {
      cur = cur.rotateCubeY().rotateCubeY();
    } else if (cur.facelets[40] == CubeColor.green) {
      cur = cur.rotateCubeYPrime();
    }

    // Map canonical face -> original face
    const standardFaceToColor = {
      'U': CubeColor.white,
      'R': CubeColor.red,
      'F': CubeColor.green,
      'D': CubeColor.yellow,
      'L': CubeColor.orange,
      'B': CubeColor.blue,
    };
    final colorToOrigFace = <CubeColor, String>{
      facelets[4]: 'U',
      facelets[13]: 'R',
      facelets[22]: 'F',
      facelets[31]: 'D',
      facelets[40]: 'L',
      facelets[49]: 'B',
    };

    String mapMove(String move) {
      final trimmed = move.trim();
      if (trimmed.isEmpty) return trimmed;
      final baseFace = trimmed[0].toUpperCase();
      final modifier = trimmed.substring(1);
      final color = standardFaceToColor[baseFace];
      if (color == null) return move;
      final mappedFace = colorToOrigFace[color] ?? baseFace;
      return '$mappedFace$modifier';
    }

    return (normalized: cur, mapMove: mapMove);
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
