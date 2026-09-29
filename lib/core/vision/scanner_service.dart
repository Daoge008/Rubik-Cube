import 'dart:typed_data';

import '../../models/cube_state.dart';
import '../native_bridge/rubik_ffi_bridge.dart';

/// Dart-side view over the native multi-frame scan pipeline.
///
/// The native engine owns the sampling, the colour classification, the sliding
/// window vote and the recovery of each face's rotation; this class only mirrors
/// what it currently reports so widgets can rebuild.
///
/// Every handle based call is a silent no-op while the engine is not ready,
/// hence [isEngineReady] and [engineError] are exposed for the UI to surface.
class ScannerService {
  final RubikFfiBridge _bridge = RubikFfiBridge.instance;

  FaceDetection? _lastDetection;

  /// Most recent per-frame detection, for the live overlay.
  FaceDetection? get lastDetection => _lastDetection;

  int _scannedFacesCount = 0;
  int get scannedFacesCount => _scannedFacesCount;

  bool _isComplete = false;

  /// True once six faces have been locked in *and* stitched into a solvable
  /// state. Six locked faces are not enough on their own: the stitched cube can
  /// still be illegal, which is why [assemblyState] is surfaced separately.
  bool get isComplete => _isComplete;

  CubeState? _scannedState;
  CubeState? get scannedState => _scannedState;

  /// Progress of the six-face stitch, as reported by the native side.
  ScanAssemblyState get assemblyState =>
      _lastDetection?.assembly ?? ScanAssemblyState.scanning;

  /// Legal pieces found while stitching, out of 20.
  int get assemblyScore => _lastDetection?.assemblyScore ?? 0;

  bool get isEngineReady => _bridge.isPipelineInitialized;

  /// Human readable reason why scanning cannot make progress, if any.
  String? get engineError => _bridge.pipelineError ?? _bridge.loadError;

  void startScanning() {
    _bridge.resetScanner();
    _scannedFacesCount = 0;
    _isComplete = false;
    _scannedState = null;
    _lastDetection = null;
  }

  /// Feeds one YUV_420_888 frame straight from the camera's image stream.
  ///
  /// The camera already produces this layout, so nothing is converted in Dart:
  /// a 720p RGB conversion done per pixel would cost more than the entire
  /// recognition pipeline it feeds.
  void processYuvFrame({
    required Uint8List yPlane,
    required int yStride,
    required int yPixelStride,
    required Uint8List uPlane,
    required int uStride,
    required int uPixelStride,
    required Uint8List vPlane,
    required int vStride,
    required int vPixelStride,
    required int width,
    required int height,
    required int rotationDegrees,
  }) {
    if (!isEngineReady) return;

    _lastDetection = _bridge.processFrameYuv(
      yPlane: yPlane,
      yStride: yStride,
      yPixelStride: yPixelStride,
      uPlane: uPlane,
      uStride: uStride,
      uPixelStride: uPixelStride,
      vPlane: vPlane,
      vStride: vStride,
      vPixelStride: vPixelStride,
      width: width,
      height: height,
      rotationDegrees: rotationDegrees,
    ) ?? _lastDetection;

    syncFromNative();
  }

  void syncFromNative() {
    if (!isEngineReady) return;

    _scannedFacesCount = _bridge.getScannedFacesCount();

    if (_scannedFacesCount < 6) {
      _scannedState = null;
      _isComplete = false;
      return;
    }

    final cubeString = _bridge.getScannedCubeString();
    if (cubeString != null) {
      if (_scannedState?.toSingmaster() != cubeString) {
        _scannedState = CubeState.fromSingmaster(cubeString);
      }
      _isComplete = true;
    } else {
      _isComplete = false;
      _scannedState = null;
    }
  }
}
