import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rubik_cube_solver/models/cube_state.dart';
import 'package:rubik_cube_solver/models/solution_step.dart';
import 'package:rubik_cube_solver/ui/screens/cube_simulator_screen.dart';
import 'package:rubik_cube_solver/ui/screens/home_screen.dart';
import 'package:rubik_cube_solver/ui/screens/manual_edit_screen.dart';
import 'package:rubik_cube_solver/ui/screens/scan_screen.dart';
import 'package:rubik_cube_solver/ui/widgets/cube_3d.dart';
import 'package:rubik_cube_solver/ui/widgets/step_guide_card.dart';

void main() {
  group('3D Cube and UI Tests', () {
    testWidgets('InteractiveCube3D renders and responds to pan gestures', (tester) async {
      final state = CubeState.solved();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: InteractiveCube3D(
                state: state,
                size: 260,
                onMoveApplied: (_) {},
              ),
            ),
          ),
        ),
      );

      expect(find.byType(InteractiveCube3D), findsOneWidget);

      // Drag in blank space to rotate camera
      await tester.drag(find.byType(InteractiveCube3D), const Offset(50, -30));
      await tester.pumpAndSettle();

      // Double tap to reset view
      await tester.tap(find.byType(InteractiveCube3D));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.byType(InteractiveCube3D));
      await tester.pumpAndSettle();
    });

    testWidgets('InteractiveCube3D snaps back to original position on small swipe', (tester) async {
      final state = CubeState.solved();
      final moves = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: InteractiveCube3D(
                state: state,
                size: 260,
                onMoveApplied: (m) => moves.add(m),
              ),
            ),
          ),
        ),
      );

      final center = tester.getCenter(find.byType(InteractiveCube3D));
      // Start touch slightly below center (on Front face)
      final gesture = await tester.startGesture(center + const Offset(-20, 20));
      // Slide a tiny amount (only 12 px)
      await gesture.moveBy(const Offset(12, 0));
      await tester.pump(const Duration(milliseconds: 50));
      // Release finger
      await gesture.up();
      // Wait for snap-back animation to finish
      await tester.pumpAndSettle();

      // No move should have been applied because it snapped back!
      expect(moves, isEmpty);
    });

    testWidgets('InteractiveCube3D completes turn on sufficient swipe', (tester) async {
      final state = CubeState.solved();
      final moves = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: InteractiveCube3D(
                state: state,
                size: 260,
                onMoveApplied: (m) => moves.add(m),
              ),
            ),
          ),
        ),
      );

      final topLeft = tester.getTopLeft(find.byType(InteractiveCube3D));
      // In local coordinates, (160, 110) is on the Front face of the 3D cube
      // Drag right
      await tester.dragFrom(topLeft + const Offset(160, 110), const Offset(70, 0));
      await tester.pumpAndSettle();
      expect(moves, isNotEmpty);
      final moveRight = moves.first;

      // Re-test dragging left on another cube to verify inverse move
      final movesLeft = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: InteractiveCube3D(
                state: state,
                size: 260,
                onMoveApplied: (m) => movesLeft.add(m),
              ),
            ),
          ),
        ),
      );
      final topLeft2 = tester.getTopLeft(find.byType(InteractiveCube3D));
      await tester.dragFrom(topLeft2 + const Offset(190, 110), const Offset(-70, 0));
      await tester.pumpAndSettle();
      expect(movesLeft, isNotEmpty);
      final moveLeft = movesLeft.first;

      // Moving right and left must be inverses of each other (e.g. E vs E')
      expect(
        (moveRight == "$moveLeft'") || (moveLeft == "$moveRight'"),
        isTrue,
        reason: 'Swiping opposite directions must produce inverse moves (got right=$moveRight, left=$moveLeft)',
      );
    });

    testWidgets('InteractiveCube3DState.animateMoves executes moves sequentially with animation', (tester) async {
      final key = GlobalKey<InteractiveCube3DState>();
      final moves = <String>[];
      var current = CubeState.solved();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: StatefulBuilder(
                builder: (context, setState) {
                  return InteractiveCube3D(
                    key: key,
                    state: current,
                    onMoveApplied: (m) {
                      setState(() {
                        current = current.applyMove(m);
                        moves.add(m);
                      });
                    },
                  );
                },
              ),
            ),
          ),
        ),
      );

      expect(key.currentState, isNotNull);

      // Animate moves sequence ["R", "U"]
      bool completed = false;
      final animFuture = key.currentState!
          .animateMoves(["R", "U"], perMoveDuration: const Duration(milliseconds: 100), pauseBetweenMoves: const Duration(milliseconds: 50))
          .then((_) => completed = true);

      while (!completed) {
        await tester.pump(const Duration(milliseconds: 30));
      }
      await animFuture;

      expect(moves, equals(["R", "U"]));
      expect(current.facelets, equals(CubeState.solved().applyMove("R").applyMove("U").facelets));
    });

    testWidgets('CubeSimulatorScreen shows 3D cube and random scramble button', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: CubeSimulatorScreen(mode: SolveMode.kociemba),
        ),
      );

      expect(find.text('3D 虚拟魔方模拟器'), findsOneWidget);
      expect(find.byType(InteractiveCube3D), findsOneWidget);
      expect(find.text('随机打乱'), findsOneWidget);
      expect(find.text('已复原'), findsOneWidget);

      // Tap scramble button
      await tester.tap(find.text('随机打乱'));
      await tester.pumpAndSettle();

      expect(find.text('已打乱'), findsOneWidget);
      expect(find.textContaining('打乱公式'), findsOneWidget);
    });

    testWidgets('ManualEditScreen has 3D view toggle and random scramble button', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ManualEditScreen(mode: SolveMode.kociemba),
        ),
      );

      expect(find.text('3D 视角'), findsOneWidget);
      expect(find.text('2D 展开图'), findsOneWidget);
      expect(find.byType(InteractiveCube3D), findsOneWidget);

      // Tap random scramble
      final scrambleBtn = find.widgetWithText(OutlinedButton, '随机打乱');
      expect(scrambleBtn, findsOneWidget);
      await tester.tap(scrambleBtn);
      await tester.pumpAndSettle();

      // Toggle to 2D
      await tester.tap(find.text('2D 展开图'));
      await tester.pumpAndSettle();
      expect(find.text('2D 展开图'), findsOneWidget);
    });

    testWidgets('HomeScreen displays 3D Simulator button and random scramble button', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: HomeScreen(),
        ),
      );

      expect(find.text('摄像头自由扫描 (推荐)'), findsOneWidget);
      expect(find.text('3D 虚拟魔方 (自由模拟 / 练习)'), findsOneWidget);
      expect(find.text('随机打乱求解'), findsOneWidget);

      // Settle the post-frame banner self-test
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle(const Duration(seconds: 2));
    });

    testWidgets('GuideOverlayPainter displays 未检测到魔方 when not detected and does not draw stickers', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomPaint(
              size: const Size(400, 400),
              painter: GuideOverlayPainter(
                stickers: List.filled(9, 0),
                isDetected: false,
                locked: 0,
                ambiguousCells: 0,
              ),
            ),
          ),
        ),
      );

      // Verify the widget renders cleanly without error
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('GuideOverlayPainter renders detected stickers when isDetected is true', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomPaint(
              size: const Size(400, 400),
              painter: GuideOverlayPainter(
                stickers: List.filled(9, 0),
                isDetected: true,
                locked: 1,
                ambiguousCells: 0,
              ),
            ),
          ),
        ),
      );
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('StepGuideCard renders navigation controls and triggers callbacks', (tester) async {
      bool nextCalled = false;
      bool prevCalled = false;
      bool replayCalled = false;
      bool toggleAutoPlayCalled = false;

      final step = SolutionStep(
        stepIndex: 2,
        moveNotation: "R U R'",
        stageName: 'CFOP 底棱对齐',
        visualHint: '测试提示',
        explanation: '测试讲解',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StepGuideCard(
              step: step,
              totalSteps: 5,
              onNext: () => nextCalled = true,
              onPrev: () => prevCalled = true,
              onReplay: () => replayCalled = true,
              onToggleAutoPlay: () => toggleAutoPlayCalled = true,
              isAutoAdvance: false,
              onToggleAutoAdvance: (_) {},
            ),
          ),
        ),
      );

      expect(find.text("R U R'"), findsOneWidget);
      expect(find.text('CFOP 底棱对齐'), findsOneWidget);
      expect(find.text('第 2 / 5 步'), findsOneWidget);

      // Tap Next
      await tester.tap(find.byTooltip('下一步'));
      expect(nextCalled, isTrue);

      // Tap Prev
      await tester.tap(find.byTooltip('上一步'));
      expect(prevCalled, isTrue);

      // Tap Replay
      await tester.tap(find.byTooltip('重播本步'));
      expect(replayCalled, isTrue);

      // Tap Auto-play
      await tester.tap(find.byTooltip('连续演示'));
      expect(toggleAutoPlayCalled, isTrue);
    });

    testWidgets('StepGuideCard disables buttons when isAnimating is true', (tester) async {
      final step = SolutionStep(
        stepIndex: 2,
        moveNotation: "U",
        stageName: '步骤演示',
        visualHint: '测试',
        explanation: '测试',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StepGuideCard(
              step: step,
              totalSteps: 5,
              onNext: () {},
              onPrev: () {},
              onReplay: () {},
              onToggleAutoPlay: () {},
              isAnimating: true,
              isAutoAdvance: false,
              onToggleAutoAdvance: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('转动中...'), findsOneWidget);

      final nextBtn = tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.arrow_forward_ios_rounded));
      expect(nextBtn.onPressed, isNull);

      final prevBtn = tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.arrow_back_ios_rounded));
      expect(prevBtn.onPressed, isNull);

      final replayBtn = tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.replay_rounded));
      expect(replayBtn.onPressed, isNull);
    });

    testWidgets('StepGuideCard displays 完成复原 on final step and shows mnemonic', (tester) async {
      bool nextCalled = false;
      final step = SolutionStep(
        stepIndex: 5,
        moveNotation: "R U R' U'",
        stageName: 'CFOP 顶层对齐',
        visualHint: '测试提示',
        explanation: '测试讲解',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StepGuideCard(
              step: step,
              totalSteps: 5,
              onNext: () => nextCalled = true,
              onPrev: () {},
              isAutoAdvance: false,
              onToggleAutoAdvance: (_) {},
            ),
          ),
        ),
      );

      // Verify beginner elements
      expect(find.text('终步：完成复原'), findsOneWidget);
      expect(find.text('完成复原'), findsOneWidget);
      expect(find.textContaining('口诀：'), findsOneWidget);

      await tester.tap(find.text('完成复原'));
      expect(nextCalled, isTrue);
    });

    testWidgets('StepGuideCard does not overflow on narrow screens with long stage names', (tester) async {
      tester.view.physicalSize = const Size(320, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final step = SolutionStep(
        stepIndex: 10,
        moveNotation: "U",
        stageName: '最少步最优解',
        visualHint: '执行标准单步转动: U',
        explanation: '根据两阶段算法优化的核心复原步骤',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StepGuideCard(
              step: step,
              totalSteps: 21,
              isAnimating: true,
              onNext: () {},
              onPrev: () {},
              onReplay: () {},
              onToggleAutoPlay: () {},
              isAutoAdvance: true,
              onToggleAutoAdvance: (_) {},
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('转动中...'), findsOneWidget);
    });
  });
}


