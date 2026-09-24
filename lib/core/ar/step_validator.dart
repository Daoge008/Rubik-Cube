import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/solution_step.dart';
import '../native_bridge/rubik_ffi_bridge.dart';

class StepValidatorController extends ChangeNotifier {
  final RubikFfiBridge _bridge = RubikFfiBridge.instance;

  List<SolutionStep> _steps = [];
  int _currentStepIndex = 0;
  bool _autoAdvanceEnabled = true;

  List<SolutionStep> get steps => _steps;
  int get currentStepIndex => _currentStepIndex;
  bool get autoAdvanceEnabled => _autoAdvanceEnabled;
  bool get isSolved => _currentStepIndex >= _steps.length;

  SolutionStep? get currentStep =>
      (!isSolved && _steps.isNotEmpty) ? _steps[_currentStepIndex] : null;

  void initialize(String initial54, List<SolutionStep> solutionSteps) {
    _steps = solutionSteps;
    _currentStepIndex = 0;
    final movesStr = _steps.map((s) => s.moveNotation).join(' ');
    _bridge.setValidationSolution(initial54, movesStr);
    notifyListeners();
  }

  void toggleAutoAdvance(bool enabled) {
    _autoAdvanceEnabled = enabled;
    notifyListeners();
  }

  void manualNext() {
    if (_currentStepIndex < _steps.length) {
      _currentStepIndex++;
      _bridge.stepNavigate(1);
      HapticFeedback.lightImpact();
      notifyListeners();
    }
  }

  void manualPrevious() {
    if (_currentStepIndex > 0) {
      _currentStepIndex--;
      _bridge.stepNavigate(-1);
      HapticFeedback.lightImpact();
      notifyListeners();
    }
  }
}
