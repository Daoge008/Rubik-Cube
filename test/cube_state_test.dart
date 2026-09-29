import 'package:flutter_test/flutter_test.dart';
import 'package:rubik_cube_solver/models/cube_color.dart';
import 'package:rubik_cube_solver/models/cube_state.dart';

void main() {
  group('CubeState moves and scramble tests', () {
    test('Solved state has 54 facelets and 9 of each color', () {
      final cube = CubeState.solved();
      expect(cube.facelets.length, 54);
      final counts = cube.getColorCounts();
      for (final color in [
        CubeColor.white,
        CubeColor.red,
        CubeColor.green,
        CubeColor.yellow,
        CubeColor.orange,
        CubeColor.blue,
      ]) {
        expect(counts[color], 9);
      }
      expect(cube.isSolved, isTrue);
    });

    test('Single move alters state and 4 moves returns to solved for any face', () {
      final faces = ['U', 'D', 'R', 'L', 'F', 'B'];
      for (final f in faces) {
        final solved = CubeState.solved();
        final moved1 = solved.applyMove(f);
        expect(moved1.isSolved, isFalse, reason: 'Face $f once should not be solved');

        final moved4 = solved.applyMoves('$f $f $f $f');
        expect(moved4.toSingmaster(), solved.toSingmaster(),
            reason: '$f * 4 should equal identity');

        final movedPrime = solved.applyMove("$f'");
        final moved3 = solved.applyMoves('$f $f $f');
        expect(movedPrime.toSingmaster(), moved3.toSingmaster(),
            reason: "$f' should equal $f * 3");

        final moved2 = solved.applyMove('${f}2');
        final movedDouble = solved.applyMoves('$f $f');
        expect(moved2.toSingmaster(), movedDouble.toSingmaster(),
            reason: "${f}2 should equal $f * 2");
      }
    });

    test('Sexy move (R U R\' U\') applied 6 times returns to solved', () {
      var cube = CubeState.solved();
      const sexy = "R U R' U'";
      for (var i = 0; i < 6; i++) {
        cube = cube.applyMoves(sexy);
      }
      expect(cube.isSolved, isTrue);
      expect(cube.toSingmaster(), CubeState.solved().toSingmaster());
    });

    test('Random scramble produces valid cube with 9 of each color and valid parity', () {
      const cornerFacelet = [
        [ 8,  9, 20 ], [ 6, 18, 38 ], [ 0, 36, 47 ], [ 2, 45, 11 ],
        [ 29, 26, 15 ], [ 27, 44, 24 ], [ 33, 53, 42 ], [ 35, 17, 51 ]
      ];
      const edgeFacelet = [
        [ 5, 10 ], [ 7, 19 ], [ 3, 37 ], [ 1, 46 ],
        [ 32, 16 ], [ 28, 25 ], [ 30, 43 ], [ 34, 52 ],
        [ 23, 12 ], [ 21, 41 ], [ 48, 39 ], [ 50, 14 ]
      ];
      const cornerColors = [
        [0, 1, 2], [0, 2, 4], [0, 4, 5], [0, 5, 1],
        [3, 2, 1], [3, 4, 2], [3, 5, 4], [3, 1, 5]
      ];
      const edgeColors = [
        [0, 1], [0, 2], [0, 4], [0, 5],
        [3, 1], [3, 2], [3, 4], [3, 5],
        [2, 1], [2, 4], [5, 4], [5, 1]
      ];
      const charMap = {'U': 0, 'R': 1, 'F': 2, 'D': 3, 'L': 4, 'B': 5};

      int matchCorner(int c1, int c2, int c3) {
        final sorted = [c1, c2, c3]..sort();
        for (var p = 0; p < 8; p++) {
          final target = List<int>.from(cornerColors[p])..sort();
          if (sorted[0] == target[0] && sorted[1] == target[1] && sorted[2] == target[2]) return p;
        }
        return -1;
      }

      int matchEdge(int c1, int c2) {
        for (var p = 0; p < 12; p++) {
          final cols = edgeColors[p];
          if ((c1 == cols[0] && c2 == cols[1]) || (c1 == cols[1] && c2 == cols[0])) return p;
        }
        return -1;
      }

      int getParity(List<int> arr) {
        var inv = 0;
        for (var i = 0; i < arr.length - 1; i++) {
          for (var j = i + 1; j < arr.length; j++) {
            if (arr[i] > arr[j]) inv++;
          }
        }
        return inv % 2;
      }

      for (var i = 0; i < 50; i++) {
        final res = CubeState.generateScramble(moveCount: 22);
        expect(res.scramble.isNotEmpty, isTrue);
        expect(res.state.isSolved, isFalse);

        final s = res.state.toSingmaster();
        final cp = List<int>.filled(8, 0);
        final co = List<int>.filled(8, 0);
        final cornerSeen = List<bool>.filled(8, false);

        for (var c = 0; c < 8; c++) {
          final fac = [charMap[s[cornerFacelet[c][0]]]!, charMap[s[cornerFacelet[c][1]]]!, charMap[s[cornerFacelet[c][2]]]!];
          var ori = 0;
          if (fac[1] == 0 || fac[1] == 3) {
            ori = 1;
          } else if (fac[2] == 0 || fac[2] == 3) {
            ori = 2;
          }
          co[c] = ori;
          final p = matchCorner(fac[0], fac[1], fac[2]);
          expect(p, isNot(-1), reason: 'Corner piece must be valid in scramble ${res.scramble}');
          expect(cornerSeen[p], isFalse, reason: 'No duplicate corner in scramble ${res.scramble}');
          cornerSeen[p] = true;
          cp[c] = p;
        }

        final ep = List<int>.filled(12, 0);
        final eo = List<int>.filled(12, 0);
        final edgeSeen = List<bool>.filled(12, false);

        for (var e = 0; e < 12; e++) {
          final c1 = charMap[s[edgeFacelet[e][0]]]!;
          final c2 = charMap[s[edgeFacelet[e][1]]]!;
          var ori = 0;
          if (c1 == 0 || c1 == 3) {
            ori = 0;
          } else if (c2 == 0 || c2 == 3) {
            ori = 1;
          } else if (c1 == 2 || c1 == 5) {
            ori = 0;
          } else {
            ori = 1;
          }
          eo[e] = ori;
          final p = matchEdge(c1, c2);
          expect(p, isNot(-1), reason: 'Edge piece must be valid in scramble ${res.scramble}');
          expect(edgeSeen[p], isFalse, reason: 'No duplicate edge in scramble ${res.scramble}');
          edgeSeen[p] = true;
          ep[e] = p;
        }

        // Parity invariants
        final twistSum = co.reduce((a, b) => a + b);
        expect(twistSum % 3, 0, reason: 'Twist parity must be 0 in scramble ${res.scramble}');

        final flipSum = eo.reduce((a, b) => a + b);
        expect(flipSum % 2, 0, reason: 'Flip parity must be 0 in scramble ${res.scramble}');

        expect(getParity(cp), getParity(ep), reason: 'Corner and edge parity must match in scramble ${res.scramble}');
      }
    });


    test('Middle slice moves (M, E, S) alter state and 4 turns return to solved', () {
      for (final slice in ['M', 'E', 'S']) {
        final solved = CubeState.solved();
        final moved1 = solved.applyMove(slice);
        expect(moved1.isSolved, isFalse, reason: 'Slice $slice once should alter state');

        final moved4 = solved.applyMoves('$slice $slice $slice $slice');
        expect(moved4.toSingmaster(), solved.toSingmaster(),
            reason: '$slice * 4 should equal identity');

        final movedPrime = solved.applyMove("$slice'");
        final moved3 = solved.applyMoves('$slice $slice $slice');
        expect(movedPrime.toSingmaster(), moved3.toSingmaster(),
            reason: "$slice' should equal $slice * 3");
      }
    });
  });
}
