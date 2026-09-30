import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/services/shake_detector_service.dart';
import '../../core/sound_service.dart';
import '../../models/cube_state.dart';
import '../../models/solution_step.dart';
import '../widgets/cube_3d.dart';
import '../widgets/beginner_guide_sheet.dart';
import 'challenge_screen.dart';
import 'scan_screen.dart';
import 'manual_edit_screen.dart';
import 'solver_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey<InteractiveCube3DState> _cube3DKey = GlobalKey<InteractiveCube3DState>();

  CubeState _cubeState = CubeState.solved();
  final List<String> _moveHistory = [];
  String? _lastScramble;
  SolveMode _selectedMode = SolveMode.kociemba;

  late final ShakeDetectorService _shakeDetector;

  @override
  void initState() {
    super.initState();
    _shakeDetector = ShakeDetectorService(
      onShake: _onShakeScramble,
      shakeThreshold: 17.0,
    );
    _shakeDetector.startListening();
  }

  @override
  void dispose() {
    _shakeDetector.dispose();
    super.dispose();
  }

  void _onShakeScramble() {
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    CubeSoundService.instance.playTurn();
    _scramble(isShake: true);
  }

  void _onMoveApplied(String move) {
    setState(() {
      _cubeState = _cubeState.applyMove(move);
      _moveHistory.add(move);
    });
  }

  void _scramble({bool isShake = false}) {
    final res = CubeState.generateScramble(moveCount: 22);
    setState(() {
      _cubeState = res.state;
      _lastScramble = res.scramble;
      _moveHistory.clear();
    });
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Text(isShake ? '📱 摇一摇已重新打乱魔方！' : '🎲 已生成随机打乱 (22步)'),
          ],
        ),
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
    _cube3DKey.currentState?.resetCamera();
    HapticFeedback.lightImpact();
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
    HapticFeedback.lightImpact();
  }

  void _goToSolver() {
    if (_cubeState.isSolved) {
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('魔方已处于复原状态，无需求解。请先摇一摇或点击打乱。'),
          duration: Duration(seconds: 2),
          backgroundColor: Color(0xFF1E1E2C),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SolverScreen(
          initialState: _cubeState,
          mode: _selectedMode,
        ),
      ),
    );
  }

  void _openToolboxSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E2C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '🛠️ 魔方工具箱 & 设置',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white54),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Tool 1: Camera Scanner
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00E676).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.camera_alt_rounded, color: Color(0xFF00E676)),
                  ),
                  title: const Text('拍照识别真实魔方', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: const Text('自由连续扫描六面，高精度姿态匹配', style: TextStyle(color: Colors.white54, fontSize: 12)),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white30, size: 16),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => ScanScreen(mode: _selectedMode)));
                  },
                ),
                const Divider(color: Colors.white10),

                // Tool 2: Manual Edit
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF40C4FF).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.palette_rounded, color: Color(0xFF40C4FF)),
                  ),
                  title: const Text('手动涂色校准求解', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: const Text('2D 展开图与 3D 预览联动输入', style: TextStyle(color: Colors.white54, fontSize: 12)),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white30, size: 16),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => ManualEditScreen(mode: _selectedMode)));
                  },
                ),
                const Divider(color: Colors.white10),

                // Tool 3: Beginner Formula Guide
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD600).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.menu_book_rounded, color: Color(0xFFFFD600)),
                  ),
                  title: const Text('新手公式与口诀速查', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: const Text('勾上回下、上左下右、小鱼与双角口诀', style: TextStyle(color: Colors.white54, fontSize: 12)),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white30, size: 16),
                  onTap: () {
                    Navigator.pop(ctx);
                    BeginnerGuideSheet.show(context);
                  },
                ),
                const Divider(color: Colors.white10),

                // Solver Mode Selection
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('求解算法偏好', style: TextStyle(color: Colors.white70, fontSize: 14)),
                      SegmentedButton<SolveMode>(
                        segments: const [
                          ButtonSegment(
                            value: SolveMode.kociemba,
                            label: Text('最少步', style: TextStyle(fontSize: 12)),
                          ),
                          ButtonSegment(
                            value: SolveMode.cfop,
                            label: Text('CFOP教学', style: TextStyle(fontSize: 12)),
                          ),
                        ],
                        selected: {_selectedMode},
                        onSelectionChanged: (set) {
                          setState(() => _selectedMode = set.first);
                          Navigator.pop(ctx);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSolved = _cubeState.isSolved;

    return Scaffold(
      backgroundColor: const Color(0xFF12121E),
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isSolved
                    ? const Color(0xFF00E676).withValues(alpha: 0.2)
                    : const Color(0xFFFF9100).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSolved ? const Color(0xFF00E676) : const Color(0xFFFF9100),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isSolved ? Icons.check_circle_rounded : Icons.extension_rounded,
                    color: isSolved ? const Color(0xFF00E676) : const Color(0xFFFF9100),
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isSolved ? '已复原' : '已打乱 · ${_moveHistory.length}步',
                    style: TextStyle(
                      color: isSolved ? const Color(0xFF00E676) : const Color(0xFFFF9100),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: '重置视角与复原',
            onPressed: _resetToSolved,
          ),
          IconButton(
            icon: const Icon(Icons.widgets_rounded),
            tooltip: '工具箱 & 模式',
            onPressed: _openToolboxSheet,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Center Stage: Full 3D Rubik's Cube
            Expanded(
              child: Center(
                child: InteractiveCube3D(
                  key: _cube3DKey,
                  state: _cubeState,
                  size: 310,
                  interactive: true,
                  allowFaceTurns: true,
                  onMoveApplied: _onMoveApplied,
                ),
              ),
            ),

            if (_lastScramble != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 2),
                child: Text(
                  '打乱: $_lastScramble',
                  style: const TextStyle(color: Colors.amberAccent, fontSize: 10),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 2),
            ],

            // Subtle Hint Capsule
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white10),
              ),
              child: const Text(
                '👆 单指转动魔方  ·  ✌️ 双指调整视角  ·  📱 摇一摇重新打乱',
                style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
              ),
            ),

            const SizedBox(height: 8),

            // Bottom Glassmorphic Floating Control Dock
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E2C).withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white10),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black45,
                    blurRadius: 16,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Row 1: Primary Action Buttons
                  Row(
                    children: [
                      // Challenge Button
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.bolt_rounded, color: Colors.black, size: 22),
                          label: const Text(
                            '复原挑战',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFFD600),
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 2,
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const ChallengeScreen()),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Solve Button
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.auto_awesome_rounded, size: 20),
                          label: const Text(
                            '求解此魔方',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isSolved
                                ? Colors.white12
                                : const Color(0xFF00E676),
                            foregroundColor: isSolved ? Colors.white38 : Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: isSolved ? 0 : 2,
                          ),
                          onPressed: _goToSolver,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Row 2: Secondary Quick Controls
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      TextButton.icon(
                        icon: const Icon(Icons.shuffle_rounded, size: 18),
                        label: const Text('随机打乱'),
                        style: TextButton.styleFrom(foregroundColor: Colors.white70),
                        onPressed: () => _scramble(isShake: false),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.undo_rounded, size: 18),
                        label: const Text('撤销'),
                        style: TextButton.styleFrom(
                          foregroundColor: _moveHistory.isNotEmpty ? Colors.white70 : Colors.white24,
                        ),
                        onPressed: _moveHistory.isNotEmpty ? _undoMove : null,
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.restart_alt_rounded, size: 18),
                        label: const Text('重置'),
                        style: TextButton.styleFrom(foregroundColor: Colors.white70),
                        onPressed: _resetToSolved,
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.more_horiz_rounded, size: 18),
                        label: const Text('更多'),
                        style: TextButton.styleFrom(foregroundColor: const Color(0xFF40C4FF)),
                        onPressed: _openToolboxSheet,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
