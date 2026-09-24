import 'package:flutter/material.dart';
import '../../models/cube_state.dart';
import '../../models/solution_step.dart';
import '../../core/solver/solver_service.dart';
import '../../core/ar/step_validator.dart';
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
  bool _isLoading = true;
  String? _solveError;

  @override
  void initState() {
    super.initState();
    try {
      _steps = _solverService.solve(widget.initialState, widget.mode);
      _validator.initialize(widget.initialState.toSingmaster(), _steps);
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF12121E),
        body: Center(child: CircularProgressIndicator()),
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
      ),
      body: Center(
        child: isSolved
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle, color: Color(0xFF00E676), size: 64),
                  const SizedBox(height: 16),
                  const Text('魔方已成功复原！', style: TextStyle(color: Colors.white, fontSize: 20)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('返回主页'),
                  ),
                ],
              )
            : (current != null
                ? StepGuideCard(
                    step: current,
                    totalSteps: _steps.length,
                    onNext: _validator.manualNext,
                    onPrev: _validator.manualPrevious,
                    isAutoAdvance: _validator.autoAdvanceEnabled,
                    onToggleAutoAdvance: _validator.toggleAutoAdvance,
                  )
                : const SizedBox.shrink()),
      ),
    );
  }
}
