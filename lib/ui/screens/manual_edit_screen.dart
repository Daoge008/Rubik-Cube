import 'package:flutter/material.dart';
import '../../models/cube_color.dart';
import '../../models/cube_state.dart';
import '../../models/solution_step.dart';
import '../../core/solver/solver_service.dart';
import '../widgets/cube_2d_net.dart';
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
      appBar: AppBar(title: const Text('手动校准'), backgroundColor: Colors.transparent),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Cube2DNet(state: _cubeState, onFacetTap: _onTapFacet),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: CubeColor.values.where((c) => c != CubeColor.unknown).map((c) {
                return GestureDetector(
                  onTap: () => setState(() => _palette = c),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: c.displayColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: _palette == c ? Colors.cyanAccent : Colors.black, width: 2),
                    ),
                  ),
                );
              }).toList(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.redAccent)),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E676),
                foregroundColor: Colors.black,
              ),
              onPressed: _solve,
              child: const Text('开始求解'),
            ),
          ],
        ),
      ),
    );
  }
}
