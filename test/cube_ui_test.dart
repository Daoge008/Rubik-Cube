import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rubik_cube_solver/models/cube_state.dart';
import 'package:rubik_cube_solver/models/solution_step.dart';
import 'package:rubik_cube_solver/ui/screens/cube_simulator_screen.dart';
import 'package:rubik_cube_solver/ui/screens/home_screen.dart';
import 'package:rubik_cube_solver/ui/screens/manual_edit_screen.dart';
import 'package:rubik_cube_solver/ui/widgets/cube_3d.dart';

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
  });
}
