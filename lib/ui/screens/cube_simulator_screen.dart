import 'package:flutter/material.dart';
import '../../models/cube_state.dart';
import '../../models/solution_step.dart';
import '../widgets/cube_3d.dart';
import 'solver_screen.dart';

class CubeSimulatorScreen extends StatefulWidget {
  final SolveMode mode;

  const CubeSimulatorScreen({super.key, required this.mode});

  @override
  State<CubeSimulatorScreen> createState() => _CubeSimulatorScreenState();
}

class _CubeSimulatorScreenState extends State<CubeSimulatorScreen> {
  CubeState _cubeState = CubeState.solved();
  final List<String> _moveHistory = [];
  final GlobalKey<State<InteractiveCube3D>> _cube3DKey = GlobalKey();
  String? _lastScramble;

  void _onMoveApplied(String move) {
    setState(() {
      _cubeState = _cubeState.applyMove(move);
      _moveHistory.add(move);
    });
  }

  void _scramble() {
    final res = CubeState.generateScramble(moveCount: 22);
    setState(() {
      _cubeState = res.state;
      _lastScramble = res.scramble;
      _moveHistory.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已随机打乱 (22步): ${res.scramble}'),
        duration: const Duration(seconds: 2),
        backgroundColor: const Color(0xFF1E1E2C),
      ),
    );
  }

  void _resetToSolved() {
    setState(() {
      _cubeState = CubeState.solved();
      _moveHistory.clear();
      _lastScramble = null;
    });
  }

  void _undoMove() {
    if (_moveHistory.isEmpty) return;
    final last = _moveHistory.removeLast();
    String inv;
    if (last.contains('2')) {
      inv = last;
    } else if (last.contains("'")) {
      inv = last[0];
    } else {
      inv = "${last[0]}'";
    }
    setState(() {
      _cubeState = _cubeState.applyMove(inv);
    });
  }

  void _goToSolver() {
    if (_cubeState.isSolved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('魔方已处于复原状态，无需求解。请先打乱。'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SolverScreen(
          initialState: _cubeState,
          mode: widget.mode,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSolved = _cubeState.isSolved;

    return Scaffold(
      backgroundColor: const Color(0xFF12121E),
      appBar: AppBar(
        title: const Text('3D 虚拟魔方模拟器'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: '重置为复原状态',
            onPressed: _resetToSolved,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isSolved
                          ? const Color(0xFF00E676).withValues(alpha: 0.2)
                          : const Color(0xFFFF9100).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSolved
                            ? const Color(0xFF00E676)
                            : const Color(0xFFFF9100),
                      ),
                    ),
                    child: Text(
                      isSolved ? '已复原' : '已打乱',
                      style: TextStyle(
                        color: isSolved
                            ? const Color(0xFF00E676)
                            : const Color(0xFFFF9100),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Text(
                    '操作步数: ${_moveHistory.length}',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),

            const Text(
              '空白处拖拽旋转视角 · 面的区域滑动转动魔方 · 双击空白重置视角',
              style: TextStyle(color: Colors.white38, fontSize: 11),
            ),

            Expanded(
              child: Center(
                child: InteractiveCube3D(
                  key: _cube3DKey,
                  state: _cubeState,
                  size: 300,
                  onMoveApplied: _onMoveApplied,
                ),
              ),
            ),

            if (_lastScramble != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  '打乱公式: $_lastScramble',
                  style: const TextStyle(color: Colors.amberAccent, fontSize: 11),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 6),
            ],

            _buildQuickMoveBar(),

            const SizedBox(height: 10),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.shuffle_rounded),
                      label: const Text('随机打乱'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white24),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: _scramble,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_moveHistory.isNotEmpty) ...[
                    IconButton(
                      icon: const Icon(Icons.undo_rounded, color: Colors.white70),
                      tooltip: '撤销上一步',
                      onPressed: _undoMove,
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('求解此魔方'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00E676),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: _goToSolver,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickMoveBar() {
    const moves = ['U', "U'", 'D', "D'", 'L', "L'", 'R', "R'", 'F', "F'", 'B', "B'"];
    return Container(
      height: 40,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: moves.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final m = moves[index];
          return ActionChip(
            label: Text(
              m,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            backgroundColor: const Color(0xFF1E1E2C),
            labelStyle: const TextStyle(color: Colors.cyanAccent),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            onPressed: () => _onMoveApplied(m),
          );
        },
      ),
    );
  }
}
