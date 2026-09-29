import 'package:flutter/material.dart';
import '../../models/cube_state.dart';
import '../../models/solution_step.dart';
import '../../core/solver/solver_service.dart';
import '../../core/ar/step_validator.dart';
import '../widgets/cube_3d.dart';
import '../widgets/step_guide_card.dart';

class SolverScreen extends StatefulWidget {
  final CubeState initialState;
  final SolveMode mode;

  const SolverScreen({Key? key, required this.initialState, required this.mode}) : super(key: key);

  @override
  State<SolverScreen> createState() => _SolverScreenState();
}

class _SolverScreenState extends State<SolverScreen> {
  final SolverService _solverService = SolverService();
  final StepValidatorController _validator = StepValidatorController();
  List<SolutionStep> _steps = [];
  List<CubeState> _stepStates = [];
  bool _isLoading = true;
  String? _solveError;

  @override
  void initState() {
    super.initState();
    try {
      _steps = _solverService.solve(widget.initialState, widget.mode);
      _validator.initialize(widget.initialState.toSingmaster(), _steps);

      // Precompute cube state at each step
      _stepStates = [widget.initialState];
      var cur = widget.initialState;
      for (final step in _steps) {
        cur = cur.applyMoves(step.moveNotation);
        _stepStates.add(cur);
      }

      _validator.addListener(() {
        if (mounted) setState(() {});
      });
    } catch (e) {
      // Solving happens synchronously over FFI; an unsolvable or malformed
      // state used to crash the first frame instead of reporting the problem.
      _solveError = e.toString();
    }
    _isLoading = false;
  }

  CubeState get _currentCubeState {
    final idx = _validator.currentStepIndex;
    if (idx >= 0 && idx < _stepStates.length) {
      return _stepStates[idx];
    }
    return _stepStates.isNotEmpty ? _stepStates.last : widget.initialState;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF12121E),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF00E676))),
      );
    }

    if (_solveError != null) {
      return Scaffold(
        backgroundColor: const Color(0xFF12121E),
        appBar: AppBar(
          title: const Text('求解失败'),
          backgroundColor: Colors.transparent,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded,
                    color: Colors.redAccent, size: 56),
                const SizedBox(height: 16),
                const Text(
                  '无法求解当前状态',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
                const SizedBox(height: 8),
                Text(
                  _solveError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('返回'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final current = _validator.currentStep;
    final isSolved = _validator.isSolved;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.mode == SolveMode.kociemba ? '最少步求解' : 'CFOP 教学'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 3D Cube representation at current step
            Expanded(
              child: Center(
                child: InteractiveCube3D(
                  state: _currentCubeState,
                  size: 260,
                  interactive: true,
                  allowFaceTurns: false,
                  highlightMove: current?.moveNotation,
                ),
              ),
            ),

            if (isSolved)
              Container(
                margin: const EdgeInsets.all(20),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E2C),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF00E676), width: 1.5),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle, color: Color(0xFF00E676), size: 54),
                    const SizedBox(height: 12),
                    const Text('魔方已成功复原！', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00E676),
                        foregroundColor: Colors.black,
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('返回主页'),
                    ),
                  ],
                ),
              )
            else if (current != null)
              StepGuideCard(
                step: current,
                totalSteps: _steps.length,
                onNext: _validator.manualNext,
                onPrev: _validator.manualPrevious,
                isAutoAdvance: _validator.autoAdvanceEnabled,
                onToggleAutoAdvance: _validator.toggleAutoAdvance,
              ),
          ],
        ),
      ),
    );
  }
}
