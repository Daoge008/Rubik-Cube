import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import '../../models/cube_state.dart';
import '../native_bridge/rubik_ffi_bridge.dart';

/// Dart-side view over the native multi-frame scan pipeline.
///
/// The native engine owns the sliding window vote and the face locking logic;
/// this class only mirrors what it currently reports so widgets can rebuild.
/// Every handle based call is a silent no-op while the engine is not ready,
/// hence [isEngineReady] and [engineError] are exposed for the UI to surface.
class ScannerService extends ChangeNotifier {
  final RubikFfiBridge _bridge = RubikFfiBridge.instance;

  int _scannedFacesCount = 0;
  int get scannedFacesCount => _scannedFacesCount;

  bool _isComplete = false;
  bool get isComplete => _isComplete;

  CubeState? _scannedState;
  CubeState? get scannedState => _scannedState;

  /// True when `librubik_core.so` is loaded and the pipeline context exists.
  bool get isEngineReady => _bridge.isPipelineInitialized;

  /// Human readable reason why scanning cannot make progress, if any.
  String? get engineError => _bridge.pipelineError ?? _bridge.loadError;

  void startScanning() {
    _bridge.resetScanner();
    _scannedFacesCount = 0;
    _isComplete = false;
    _scannedState = null;
    notifyListeners();
  }

  /// Feeds one raw camera frame into the native vision pipeline.
  ///
  /// [bytes] is a `bytesPerRow * height` buffer in the given [format]
  /// (0 = RGBA8888). Returns the per-frame detection, or `null` when the
  /// engine is not ready.
  FaceDetection? processFrame(
    Uint8List bytes, {
    required int width,
    required int height,
    int? bytesPerRow,
    int format = 0,
  }) {
    final detection = _bridge.processFrame(
      bytes,
      width: width,
      height: height,
      bytesPerRow: bytesPerRow,
      format: format,
    );
    if (detection != null) {
      syncFromNative();
    }
    return detection;
  }

  /// Pulls the latest face count and assembled cube state out of the engine.
  void syncFromNative() {
    if (!isEngineReady) return;

    final faces = _bridge.getScannedFacesCount();
    final cubeString = _bridge.getScannedCubeString();

    var changed = false;
    if (faces != _scannedFacesCount) {
      _scannedFacesCount = faces;
      changed = true;
    }

    final complete = cubeString != null;
    if (complete != _isComplete) {
      _isComplete = complete;
      changed = true;
    }
    if (complete && _scannedState?.toSingmaster() != cubeString) {
      _scannedState = CubeState.fromSingmaster(cubeString);
      changed = true;
    }

    if (changed) notifyListeners();
  }
}
