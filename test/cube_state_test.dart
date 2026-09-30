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

    test('Whole cube rotations x, y, z preserve solid faces on solved cube', () {
      final solved = CubeState.solved();

      // x rotation = R M' L'
      final rotX = solved.applyMove("R").applyMove("M'").applyMove("L'");
      // Under x rotation, every face must be uniform color
      for (var f = 0; f < 6; f++) {
        final color0 = rotX.facelets[f * 9];
        for (var i = 0; i < 9; i++) {
          expect(rotX.facelets[f * 9 + i], equals(color0),
              reason: 'Face $f must remain uniform after x rotation');
        }
      }

      // y rotation = U E' D'
      final rotY = solved.applyMove("U").applyMove("E'").applyMove("D'");
      for (var f = 0; f < 6; f++) {
        final color0 = rotY.facelets[f * 9];
        for (var i = 0; i < 9; i++) {
          expect(rotY.facelets[f * 9 + i], equals(color0),
              reason: 'Face $f must remain uniform after y rotation');
        }
      }

      // z rotation = F S B'
      final rotZ = solved.applyMove("F").applyMove("S").applyMove("B'");
      for (var f = 0; f < 6; f++) {
        final color0 = rotZ.facelets[f * 9];
        for (var i = 0; i < 9; i++) {
          expect(rotZ.facelets[f * 9 + i], equals(color0),
              reason: 'Face $f must remain uniform after z rotation');
        }
      }
    });

    test('CubeState.normalizeOrientation restores canonical centers for any middle slice move', () {
      for (final slice in ['M', "M'", 'M2', 'E', "E'", 'E2', 'S', "S'", 'S2']) {
        final scrambled = CubeState.generateScramble(moveCount: 15).state;
        final moved = scrambled.applyMove(slice);

        final res = moved.normalizeOrientation();
        final norm = res.normalized;

        expect(norm.facelets[4], equals(CubeColor.white), reason: 'U center must be White');
        expect(norm.facelets[13], equals(CubeColor.red), reason: 'R center must be Red');
        expect(norm.facelets[22], equals(CubeColor.green), reason: 'F center must be Green');
        expect(norm.facelets[31], equals(CubeColor.yellow), reason: 'D center must be Yellow');
        expect(norm.facelets[40], equals(CubeColor.orange), reason: 'L center must be Orange');
        expect(norm.facelets[49], equals(CubeColor.blue), reason: 'B center must be Blue');
      }
    });

    test('Mapped solution moves completely restore scrambled cube with middle slice moves', () {
      for (final slice in ['E', 'M', 'S', "E'", "M'", "S'"]) {
        // Solved cube with slice move
        var orig = CubeState.solved().applyMove(slice);

        // Normalize
        final res = orig.normalizeOrientation();
        final norm = res.normalized;
        expect(norm.facelets[4], equals(CubeColor.white));
        expect(norm.facelets[22], equals(CubeColor.green));

        // Solution on norm: on norm, White is U and Green is F.
        // Let's find solution moves on norm:
        // For slice E: norm is solved().applyMoves("U' D") or similar.
        // If we apply inverse of norm's transformation:
        // Verify that applying the mapped moves to orig results in isSolved == true!
        final invMoves = <String>[];
        if (slice == 'E') {
          invMoves.addAll(["U'", 'D']);
        } else if (slice == "E'") {
          invMoves.addAll(['U', "D'"]);
        } else if (slice == 'M') {
          invMoves.addAll(["R'", 'L']);
        } else if (slice == "M'") {
          invMoves.addAll(['R', "L'"]);
        } else if (slice == 'S') {
          invMoves.addAll(['F', "B'"]);
        } else if (slice == "S'") {
          invMoves.addAll(["F'", 'B']);
        }

        // Apply mapped moves to orig
        var current = orig;
        for (final m in invMoves) {
          final mapped = res.mapMove(m);
          current = current.applyMove(mapped);
        }

        expect(current.isSolved, isTrue,
            reason: 'Applying mapped solution moves must restore cube for slice $slice');
      }
    });
  });
}
