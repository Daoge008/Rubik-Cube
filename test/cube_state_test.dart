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

    test('Random scramble produces valid cube with 9 of each color', () {
      for (var i = 0; i < 10; i++) {
        final res = CubeState.generateScramble(moveCount: 22);
        expect(res.scramble.isNotEmpty, isTrue);
        expect(res.state.isSolved, isFalse);
        final counts = res.state.getColorCounts();
        for (final c in [
          CubeColor.white,
          CubeColor.red,
          CubeColor.green,
          CubeColor.yellow,
          CubeColor.orange,
          CubeColor.blue,
        ]) {
          expect(counts[c], 9);
        }
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
