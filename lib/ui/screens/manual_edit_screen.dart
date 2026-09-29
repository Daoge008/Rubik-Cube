import 'package:flutter/material.dart';
import '../../models/cube_color.dart';
import '../../models/cube_state.dart';
import '../../models/solution_step.dart';
import '../../core/solver/solver_service.dart';
import '../widgets/cube_2d_net.dart';
import '../widgets/cube_3d.dart';
import 'solver_screen.dart';

class ManualEditScreen extends StatefulWidget {
  final SolveMode mode;
  const ManualEditScreen({Key? key, required this.mode}) : super(key: key);

  @override
  State<ManualEditScreen> createState() => _ManualEditScreenState();
}

class _ManualEditScreenState extends State<ManualEditScreen> {
  late CubeState _cubeState;
  CubeColor _palette = CubeColor.white;
  final SolverService _solver = SolverService();
  String? _error;
  bool _use3DView = true;

  @override
  void initState() {
    super.initState();
    _cubeState = CubeState.solved();
  }

  void _onTapFacet(int idx) {
    setState(() {
      _cubeState = _cubeState.copyWithFacet(idx, _palette);
      _error = null;
    });
  }

  void _scramble() {
    final res = CubeState.generateScramble(moveCount: 22);
    setState(() {
      _cubeState = res.state;
      _error = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已随机打乱: ${res.scramble}'),
        duration: const Duration(seconds: 2),
        backgroundColor: const Color(0xFF1E1E2C),
      ),
    );
  }

  void _resetSolved() {
    setState(() {
      _cubeState = CubeState.solved();
      _error = null;
    });
  }

  void _solve() {
    final err = _solver.validateState(_cubeState);
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SolverScreen(initialState: _cubeState, mode: widget.mode)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF12121E),
      appBar: AppBar(
        title: const Text('手动涂色校准'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.shuffle_rounded),
            tooltip: '随机打乱',
            onPressed: _scramble,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: '重置为复原',
            onPressed: _resetSolved,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            // Mode toggle (3D / 2D)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ChoiceChip(
                  label: const Text('3D 视角'),
                  selected: _use3DView,
                  selectedColor: const Color(0xFF00E676),
                  labelStyle: TextStyle(
                    color: _use3DView ? Colors.black : Colors.white70,
                    fontWeight: FontWeight.bold,
                  ),
                  onSelected: (val) => setState(() => _use3DView = true),
                ),
                const SizedBox(width: 12),
                ChoiceChip(
                  label: const Text('2D 展开图'),
                  selected: !_use3DView,
                  selectedColor: const Color(0xFF00E676),
                  labelStyle: TextStyle(
                    color: !_use3DView ? Colors.black : Colors.white70,
                    fontWeight: FontWeight.bold,
                  ),
                  onSelected: (val) => setState(() => _use3DView = false),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Hint
            Text(
              _use3DView
                  ? '拖拽空白处旋转视角 · 点击魔方小块涂上选中的颜色'
                  : '点击 2D 展开图中的格子进行涂色',
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
            const SizedBox(height: 12),

            // Cube View (3D or 2D)
            if (_use3DView)
              InteractiveCube3D(
                state: _cubeState,
                size: 260,
                interactive: true,
                allowFaceTurns: false,
                onFacetTap: _onTapFacet,
              )
            else
              Cube2DNet(state: _cubeState, onFacetTap: _onTapFacet),

            const SizedBox(height: 16),

            // Color Palette
            const Text(
              '选择要涂的颜色：',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              children: CubeColor.values.where((c) => c != CubeColor.unknown).map((c) {
                final isSelected = _palette == c;
                return GestureDetector(
                  onTap: () => setState(() => _palette = c),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: c.displayColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? const Color(0xFF00E676) : Colors.black45,
                        width: isSelected ? 3 : 1.5,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: const Color(0xFF00E676).withValues(alpha: 0.5),
                                blurRadius: 8,
                                spreadRadius: 1,
                              )
                            ]
                          : null,
                    ),
                  ),
                );
              }).toList(),
            ),

            if (_error != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
            ],

            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.shuffle_rounded),
                    label: const Text('随机打乱'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: _scramble,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00E676),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _solve,
                    child: const Text('开始求解', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
