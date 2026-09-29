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

  /// Permutation map for a 90° clockwise rotation of 9 facelets on one face.
  static const List<int> _faceRotCW = [6, 3, 0, 7, 4, 1, 8, 5, 2];

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

  /// Rotates a single face clockwise 90 degrees.
  static void _rotateFaceCW(List<CubeColor> list, int faceIndex) {
    final base = faceIndex * 9;
    final old = [for (var i = 0; i < 9; i++) list[base + i]];
    for (var i = 0; i < 9; i++) {
      list[base + i] = old[_faceRotCW[i]];
    }
  }

  /// Applies one single-layer clockwise 90° turn for face 'U', 'D', 'R', 'L', 'F', 'B'.
  static void _applyBaseMoveCW(List<CubeColor> list, String face) {
    switch (face) {
      case 'U':
        _rotateFaceCW(list, 0);
        _cycleStrips(
          list,
          [45, 46, 47], // B top
          [9, 10, 11],  // R top
          [18, 19, 20], // F top
          [36, 37, 38], // L top
        );
        break;

      case 'D':
        _rotateFaceCW(list, 3);
        _cycleStrips(
          list,
          [24, 25, 26], // F bot
          [15, 16, 17], // R bot
          [51, 52, 53], // B bot
          [42, 43, 44], // L bot
        );
        break;

      case 'F':
        _rotateFaceCW(list, 2);
        _cycleStrips(
          list,
          [6, 7, 8],     // U bot
          [9, 12, 15],   // R left
          [29, 28, 27],  // D top (reverse)
          [44, 41, 38],  // L right (reverse)
        );
        break;

      case 'B':
        _rotateFaceCW(list, 5);
        _cycleStrips(
          list,
          [0, 1, 2],     // U top
          [42, 39, 36],  // L left (reverse)
          [35, 34, 33],  // D bot (reverse)
          [11, 14, 17],  // R right
        );
        break;

      case 'R':
        _rotateFaceCW(list, 1);
        _cycleStrips(
          list,
          [2, 5, 8],     // U right
          [51, 48, 45],  // B left (reverse)
          [29, 32, 35],  // D right
          [20, 23, 26],  // F right
        );
        break;

      case 'L':
        _rotateFaceCW(list, 4);
        _cycleStrips(
          list,
          [0, 3, 6],     // U left
          [18, 21, 24],  // F left
          [27, 30, 33],  // D left
          [53, 50, 47],  // B right (reverse)
        );
        break;
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
        //   F row1 → R row1 → B row1 → L row1 → F row1
        _cycleStrips(
          list,
          [18 + 3, 18 + 4, 18 + 5], // F middle row
          [9 + 3,  9 + 4,  9 + 5],  // R middle row
          [45 + 3, 45 + 4, 45 + 5], // B middle row
          [36 + 3, 36 + 4, 36 + 5], // L middle row
        );
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
