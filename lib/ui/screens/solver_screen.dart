import 'package:flutter/material.dart';
import '../../models/cube_state.dart';
import '../../models/solution_step.dart';
import '../../core/solver/solver_service.dart';
import '../../core/ar/step_validator.dart';
import '../widgets/cube_3d.dart';
import '../widgets/step_guide_card.dart';
import '../widgets/beginner_guide_sheet.dart';

class SolverScreen extends StatefulWidget {
  final CubeState initialState;
  final SolveMode mode;

  const SolverScreen({super.key, required this.initialState, required this.mode});

  @override
  State<SolverScreen> createState() => _SolverScreenState();
}

class _SolverScreenState extends State<SolverScreen> {
  final SolverService _solverService = SolverService();
  final StepValidatorController _validator = StepValidatorController();
  final GlobalKey<InteractiveCube3DState> _cubeKey = GlobalKey<InteractiveCube3DState>();

  List<SolutionStep> _steps = [];
  List<CubeState> _stepStates = [];
  bool _isLoading = true;
  String? _solveError;

  late CubeState _displayedState;
  bool _isAnimating = false;
  bool _isAutoPlaying = false;

  @override
  void initState() {
    super.initState();
    _displayedState = widget.initialState;
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
        if (mounted && !_isAnimating) {
          setState(() {
            _displayedState = _currentCubeState;
          });
        }
      });
    } catch (e, stack) {
      debugPrint('SolverScreen solve error: $e\n$stack');
      _solveError = e.toString();
    }
    _isLoading = false;
  }

  @override
  void dispose() {
    _isAutoPlaying = false;
    super.dispose();
  }

  CubeState get _currentCubeState {
    final idx = _validator.currentStepIndex;
    if (idx >= 0 && idx < _stepStates.length) {
      return _stepStates[idx];
    }
    return _stepStates.isNotEmpty ? _stepStates.last : widget.initialState;
  }

  List<String> _parseMoves(String notation) {
    return notation.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
  }

  List<String> _invertMoves(List<String> moves) {
    return moves.reversed.map((m) {
      if (m.contains('2')) return m;
      if (m.contains("'")) return m.replaceAll("'", "");
      return "$m'";
    }).toList();
  }

  Future<void> _onNextStep() async {
    if (_isAnimating || _validator.isSolved) return;
    final current = _validator.currentStep;
    if (current == null) return;

    final moves = _parseMoves(current.moveNotation);
    if (moves.isEmpty) {
      _validator.manualNext();
      setState(() {
        _displayedState = _currentCubeState;
      });
      return;
    }

    setState(() => _isAnimating = true);

    try {
      await _cubeKey.currentState?.animateMoves(moves);
    } catch (_) {}

    if (mounted) {
      _validator.manualNext();
      setState(() {
        _displayedState = _currentCubeState;
        _isAnimating = false;
      });
    }
  }

  Future<void> _onPrevStep() async {
    if (_isAnimating || _validator.currentStepIndex <= 0) return;

    final prevStepIndex = _validator.currentStepIndex - 1;
    if (prevStepIndex < 0 || prevStepIndex >= _steps.length) return;

    final prevStep = _steps[prevStepIndex];
    final reverseMoves = _invertMoves(_parseMoves(prevStep.moveNotation));

    setState(() => _isAnimating = true);

    try {
      await _cubeKey.currentState?.animateMoves(reverseMoves);
    } catch (_) {}

    if (mounted) {
      _validator.manualPrevious();
      setState(() {
        _displayedState = _currentCubeState;
        _isAnimating = false;
      });
    }
  }

  Future<void> _onReplayStep() async {
    if (_isAnimating || _validator.isSolved) return;
    final current = _validator.currentStep;
    if (current == null) return;

    final moves = _parseMoves(current.moveNotation);
    if (moves.isEmpty) return;

    setState(() => _isAnimating = true);

    try {
      // 1. Animate forward the current move(s)
      await _cubeKey.currentState?.animateMoves(moves);
      await Future.delayed(const Duration(milliseconds: 350));

      // 2. Animate backward to return to start of this step
      final reverseMoves = _invertMoves(moves);
      await _cubeKey.currentState?.animateMoves(reverseMoves);
    } catch (_) {}

    if (mounted) {
      setState(() {
        _displayedState = _currentCubeState;
        _isAnimating = false;
      });
    }
  }

  void _toggleAutoPlay() {
    setState(() {
      _isAutoPlaying = !_isAutoPlaying;
    });
    if (_isAutoPlaying) {
      _runAutoPlay();
    }
  }

  Future<void> _runAutoPlay() async {
    while (_isAutoPlaying && mounted && !_validator.isSolved) {
      await _onNextStep();
      if (!_isAutoPlaying || !mounted || _validator.isSolved) break;
      await Future.delayed(const Duration(milliseconds: 400));
    }
    if (mounted) {
      setState(() => _isAutoPlaying = false);
    }
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
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline_rounded, color: Color(0xFF40C4FF)),
            tooltip: '新手入门指南',
            onPressed: () => BeginnerGuideSheet.show(context),
          ),
        ],
      ),

      body: SafeArea(
        child: Column(
          children: [
            // 3D Cube representation at current step
            Expanded(
              child: Center(
                child: InteractiveCube3D(
                  key: _cubeKey,
                  state: _displayedState,
                  size: 260,
                  interactive: true,
                  allowFaceTurns: false,
                  onMoveApplied: (move) {
                    setState(() {
                      _displayedState = _displayedState.applyMove(move);
                    });
                  },
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
                onNext: _onNextStep,
                onPrev: _onPrevStep,
                onReplay: _onReplayStep,
                isAnimating: _isAnimating,
                isAutoPlaying: _isAutoPlaying,
                onToggleAutoPlay: _toggleAutoPlay,
                isAutoAdvance: _validator.autoAdvanceEnabled,
                onToggleAutoAdvance: _validator.toggleAutoAdvance,
              ),
          ],
        ),
      ),
    );
  }
}
