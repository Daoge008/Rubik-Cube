import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';

final class NativePoint2D extends ffi.Struct {
  @ffi.Float()
  external double x;

  @ffi.Float()
  external double y;
}

final class NativeDetectionResult extends ffi.Struct {
  @ffi.Int32()
  external int isDetected;

  @ffi.Array(4)
  external ffi.Array<NativePoint2D> corners;

  @ffi.Array(9)
  external ffi.Array<ffi.Int32> stickers;

  @ffi.Int32()
  external int centerColor;

  @ffi.Int32()
  external int stepAdvanced;

  @ffi.Int32()
  external int currentStepIndex;

  @ffi.Int32()
  external int totalSteps;

  /// Frames accumulated for the face currently in view (0..[windowSize]).
  @ffi.Int32()
  external int faceFrameCount;

  /// Frames a face needs in the majority vote before it is locked.
  @ffi.Int32()
  external int windowSize;

  /// Cells of the current frame whose colour was ambiguous.
  @ffi.Int32()
  external int ambiguousCells;

  /// 0 = still scanning, 1 = six faces aligned and solvable, 2 = alignment failed.
  @ffi.Int32()
  external int assemblyState;

  /// Legal pieces found while aligning the six faces, out of 20.
  @ffi.Int32()
  external int assemblyScore;
}

typedef _NativeValidate = ffi.Int32 Function(
    ffi.Pointer<Utf8> facelets, ffi.Pointer<Utf8> errBuf, ffi.Int32 maxLen);
typedef _DartValidate = int Function(
    ffi.Pointer<Utf8> facelets, ffi.Pointer<Utf8> errBuf, int maxLen);

typedef _NativeSolveKociemba = ffi.Pointer<Utf8> Function(
    ffi.Pointer<Utf8> facelets, ffi.Int32 maxDepth);
typedef _DartSolveKociemba = ffi.Pointer<Utf8> Function(
    ffi.Pointer<Utf8> facelets, int maxDepth);

typedef _NativeGenerateCfop = ffi.Pointer<Utf8> Function(
    ffi.Pointer<Utf8> facelets);
typedef _DartGenerateCfop = ffi.Pointer<Utf8> Function(
    ffi.Pointer<Utf8> facelets);

typedef _NativeFreeString = ffi.Void Function(ffi.Pointer<Utf8> ptr);
typedef _DartFreeString = void Function(ffi.Pointer<Utf8> ptr);

typedef _NativeInitPipeline = ffi.Pointer<ffi.Void> Function(
    ffi.Float fx, ffi.Float fy, ffi.Float cx, ffi.Float cy);
typedef _DartInitPipeline = ffi.Pointer<ffi.Void> Function(
    double fx, double fy, double cx, double cy);

typedef _NativeDestroyPipeline = ffi.Void Function(ffi.Pointer<ffi.Void> handle);
typedef _DartDestroyPipeline = void Function(ffi.Pointer<ffi.Void> handle);

typedef _NativeResetScanner = ffi.Void Function(ffi.Pointer<ffi.Void> handle);
typedef _DartResetScanner = void Function(ffi.Pointer<ffi.Void> handle);

typedef _NativeGetScannedFacesCount = ffi.Int32 Function(ffi.Pointer<ffi.Void> handle);
typedef _DartGetScannedFacesCount = int Function(ffi.Pointer<ffi.Void> handle);

typedef _NativeGetScannedCubeString = ffi.Int32 Function(
    ffi.Pointer<ffi.Void> handle, ffi.Pointer<Utf8> outBuf, ffi.Int32 maxLen);
typedef _DartGetScannedCubeString = int Function(
    ffi.Pointer<ffi.Void> handle, ffi.Pointer<Utf8> outBuf, int maxLen);

typedef _NativeProcessCameraFrame = ffi.Void Function(
    ffi.Pointer<ffi.Void> handle,
    ffi.Pointer<ffi.Uint8> buffer,
    ffi.Int32 width,
    ffi.Int32 height,
    ffi.Int32 bytesPerRow,
    ffi.Int32 format,
    ffi.Int32 rotationDegrees,
    ffi.Pointer<NativeDetectionResult> outResult);
typedef _DartProcessCameraFrame = void Function(
    ffi.Pointer<ffi.Void> handle,
    ffi.Pointer<ffi.Uint8> buffer,
    int width,
    int height,
    int bytesPerRow,
    int format,
    int rotationDegrees,
    ffi.Pointer<NativeDetectionResult> outResult);

typedef _NativeProcessCameraFrameYuv = ffi.Void Function(
    ffi.Pointer<ffi.Void> handle,
    ffi.Pointer<ffi.Uint8> yPlane,
    ffi.Int32 yStride,
    ffi.Int32 yPixelStride,
    ffi.Pointer<ffi.Uint8> uPlane,
    ffi.Int32 uStride,
    ffi.Int32 uPixelStride,
    ffi.Pointer<ffi.Uint8> vPlane,
    ffi.Int32 vStride,
    ffi.Int32 vPixelStride,
    ffi.Int32 width,
    ffi.Int32 height,
    ffi.Int32 rotationDegrees,
    ffi.Pointer<NativeDetectionResult> outResult);
typedef _DartProcessCameraFrameYuv = void Function(
    ffi.Pointer<ffi.Void> handle,
    ffi.Pointer<ffi.Uint8> yPlane,
    int yStride,
    int yPixelStride,
    ffi.Pointer<ffi.Uint8> uPlane,
    int uStride,
    int uPixelStride,
    ffi.Pointer<ffi.Uint8> vPlane,
    int vStride,
    int vPixelStride,
    int width,
    int height,
    int rotationDegrees,
    ffi.Pointer<NativeDetectionResult> outResult);

typedef _NativeSetValidationSolution = ffi.Void Function(
    ffi.Pointer<ffi.Void> handle, ffi.Pointer<Utf8> init54, ffi.Pointer<Utf8> moves);
typedef _DartSetValidationSolution = void Function(
    ffi.Pointer<ffi.Void> handle, ffi.Pointer<Utf8> init54, ffi.Pointer<Utf8> moves);

typedef _NativeManualStepNavigate = ffi.Void Function(
    ffi.Pointer<ffi.Void> handle, ffi.Int32 dir);
typedef _DartManualStepNavigate = void Function(
    ffi.Pointer<ffi.Void> handle, int dir);

/// A plain-Dart snapshot of one native [NativeDetectionResult].
///
/// Deliberately free of `dart:ui` types so the bridge stays usable outside of
/// widgets.
class FaceDetection {
  const FaceDetection({
    required this.isDetected,
    required this.corners,
    required this.stickers,
    required this.centerColor,
    required this.stepAdvanced,
    required this.currentStepIndex,
    required this.totalSteps,
    required this.faceFrameCount,
    required this.windowSize,
    required this.ambiguousCells,
    required this.assemblyState,
    required this.assemblyScore,
  });

  final bool isDetected;

  /// Four ordered corners in pixel coordinates.
  final List<({double x, double y})> corners;

  /// Nine sticker color indices (row-major) of the detected face.
  final List<int> stickers;

  final int centerColor;
  final bool stepAdvanced;
  final int currentStepIndex;
  final int totalSteps;

  /// Frames accumulated for the face currently in view.
  final int faceFrameCount;

  /// Frames a face needs before the native side locks it in.
  final int windowSize;

  /// Cells whose runner-up colour was nearly as close, i.e. "probably, but
  /// check the lighting".
  final int ambiguousCells;

  /// [ScanAssemblyState] as a raw int, for cheap comparison.
  final int assemblyState;

  /// Legal pieces found when aligning the six faces, out of 20.
  final int assemblyScore;

  ScanAssemblyState get assembly => ScanAssemblyState.fromValue(assemblyState);

  /// Fraction of the vote window filled for the face in view, 0..1.
  double get faceProgress =>
      windowSize <= 0 ? 0 : (faceFrameCount / windowSize).clamp(0.0, 1.0);
}

/// Whether the six scanned faces could be stitched into a solvable cube.
enum ScanAssemblyState {
  /// Fewer than six faces have been locked in yet.
  scanning,

  /// All six faces aligned into a legal, solvable state.
  assembled,

  /// Six faces are in, but they do not describe a legal cube.
  failed;

  static ScanAssemblyState fromValue(int value) {
    switch (value) {
      case 1:
        return ScanAssemblyState.assembled;
      case 2:
        return ScanAssemblyState.failed;
      default:
        return ScanAssemblyState.scanning;
    }
  }
}

const String _androidLibraryName = 'librubik_core.so';

class RubikFfiBridge {
  static final RubikFfiBridge instance = RubikFfiBridge._internal();

  ffi.DynamicLibrary? _lib;

  String? _loadError;
  String? _pipelineError;

  late _DartValidate _validate;
  late _DartSolveKociemba _solveKociemba;
  late _DartGenerateCfop _generateCfop;
  late _DartFreeString _freeString;
  late _DartInitPipeline _initPipeline;
  late _DartDestroyPipeline _destroyPipeline;
  late _DartResetScanner _resetScanner;
  late _DartGetScannedFacesCount _getScannedFacesCount;
  late _DartGetScannedCubeString _getScannedCubeString;
  late _DartProcessCameraFrame _processCameraFrame;
  late _DartProcessCameraFrameYuv _processCameraFrameYuv;
  late _DartSetValidationSolution _setValidationSolution;
  late _DartManualStepNavigate _manualStepNavigate;

  ffi.Pointer<ffi.Void>? _pipelineHandle;
  ffi.Pointer<NativeDetectionResult>? _resultPtr;
  bool _disposed = false;

  RubikFfiBridge._internal() {
    try {
      _lib = _openLibrary();
      _bindSymbols();
    } catch (e) {
      // Without the native library the solver cannot run, but the app must
      // still start so the failure is visible instead of crashing.
      _loadError = e.toString();
    }
  }

  static ffi.DynamicLibrary _openLibrary() {
    if (Platform.isAndroid || Platform.isLinux) {
      return ffi.DynamicLibrary.open(_androidLibraryName);
    }
    if (Platform.isWindows) {
      return ffi.DynamicLibrary.open('rubik_core.dll');
    }
    if (Platform.isMacOS) {
      return ffi.DynamicLibrary.open('librubik_core.dylib');
    }
    return ffi.DynamicLibrary.process();
  }

  void _bindSymbols() {
    final lib = _lib!;
    _validate = lib
        .lookup<ffi.NativeFunction<_NativeValidate>>('validate_cube_state')
        .asFunction();
    _solveKociemba = lib
        .lookup<ffi.NativeFunction<_NativeSolveKociemba>>('solve_kociemba')
        .asFunction();
    _generateCfop = lib
        .lookup<ffi.NativeFunction<_NativeGenerateCfop>>('generate_cfop_guide_json')
        .asFunction();
    _freeString = lib
        .lookup<ffi.NativeFunction<_NativeFreeString>>('free_c_string')
        .asFunction();
    _initPipeline = lib
        .lookup<ffi.NativeFunction<_NativeInitPipeline>>('init_cube_pipeline')
        .asFunction();
    _destroyPipeline = lib
        .lookup<ffi.NativeFunction<_NativeDestroyPipeline>>('destroy_cube_pipeline')
        .asFunction();
    _resetScanner = lib
        .lookup<ffi.NativeFunction<_NativeResetScanner>>('reset_cube_scanner')
        .asFunction();
    _getScannedFacesCount = lib
        .lookup<ffi.NativeFunction<_NativeGetScannedFacesCount>>('get_scanned_faces_count')
        .asFunction();
    _getScannedCubeString = lib
        .lookup<ffi.NativeFunction<_NativeGetScannedCubeString>>('get_scanned_cube_string')
        .asFunction();
    _processCameraFrame = lib
        .lookup<ffi.NativeFunction<_NativeProcessCameraFrame>>('process_camera_frame')
        .asFunction();
    _processCameraFrameYuv = lib
        .lookup<ffi.NativeFunction<_NativeProcessCameraFrameYuv>>(
            'process_camera_frame_yuv')
        .asFunction();
    _setValidationSolution = lib
        .lookup<ffi.NativeFunction<_NativeSetValidationSolution>>('set_validation_solution')
        .asFunction();
    _manualStepNavigate = lib
        .lookup<ffi.NativeFunction<_NativeManualStepNavigate>>('manual_step_navigate')
        .asFunction();

    _resultPtr = calloc<NativeDetectionResult>();
  }

  /// True when `librubik_core.so` was found and every FFI symbol resolved.
  bool get isLoaded => _lib != null;

  /// Human readable reason why the native library could not be loaded.
  String? get loadError => _loadError;

  /// True once [initPipeline] has created a native pipeline context.
  bool get isPipelineInitialized => _pipelineHandle != null;

  /// Reason why [initPipeline] failed, if it did.
  String? get pipelineError => _pipelineError;

  /// Creates the native pipeline context.
  ///
  /// Every handle based FFI entry point ([resetScanner],
  /// [getScannedFacesCount], [processFrame], [setValidationSolution],
  /// [stepNavigate]) silently does nothing until this succeeds, which is why
  /// it is called during app start-up.
  ///
  /// [fx], [fy], [cx], [cy] are camera intrinsics used by the pose estimation
  /// stage; they may be supplied later once the camera is configured.
  bool initPipeline({
    double fx = 0,
    double fy = 0,
    double cx = 0,
    double cy = 0,
  }) {
    if (!isLoaded || _disposed) {
      _pipelineError = _loadError ?? 'Native library is not loaded.';
      return false;
    }
    if (_pipelineHandle != null) return true;

    try {
      final handle = _initPipeline(fx, fy, cx, cy);
      if (handle == ffi.nullptr) {
        _pipelineError = 'init_cube_pipeline returned a null handle.';
        return false;
      }
      _pipelineHandle = handle;
      _pipelineError = null;
      return true;
    } catch (e) {
      _pipelineError = e.toString();
      return false;
    }
  }

  /// Releases the native pipeline context. Safe to call more than once.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    final handle = _pipelineHandle;
    if (handle != null) {
      _destroyPipeline(handle);
      _pipelineHandle = null;
    }
    final resultPtr = _resultPtr;
    if (resultPtr != null) {
      calloc.free(resultPtr);
      _resultPtr = null;
    }
  }

  /// Returns `null` when [facelets] is a solvable cube state, otherwise a
  /// human readable description of the first violation found.
  String? validate(String facelets) {
    if (!isLoaded) return _loadError ?? 'Native library is not loaded.';
    final cFacelets = facelets.toNativeUtf8();
    final cErr = calloc<ffi.Uint8>(256).cast<Utf8>();
    try {
      final code = _validate(cFacelets, cErr, 256);
      if (code == 1) return null;
      return cErr.toDartString();
    } finally {
      calloc.free(cFacelets);
      calloc.free(cErr);
    }
  }

  String solveKociemba(String facelets, {int maxDepth = 22}) {
    if (!isLoaded) {
      return 'ERROR: ${_loadError ?? 'Native library is not loaded.'}';
    }
    final cFacelets = facelets.toNativeUtf8();
    try {
      final resPtr = _solveKociemba(cFacelets, maxDepth);
      if (resPtr == ffi.nullptr) return 'ERROR: solve_kociemba returned null.';
      final res = resPtr.toDartString();
      _freeString(resPtr);
      return res;
    } finally {
      calloc.free(cFacelets);
    }
  }

  String generateCfopJson(String facelets) {
    if (!isLoaded) return '[]';
    final cFacelets = facelets.toNativeUtf8();
    try {
      final resPtr = _generateCfop(cFacelets);
      if (resPtr == ffi.nullptr) return '[]';
      final res = resPtr.toDartString();
      _freeString(resPtr);
      return res;
    } finally {
      calloc.free(cFacelets);
    }
  }

  void resetScanner() {
    final handle = _pipelineHandle;
    if (handle == null) return;
    _resetScanner(handle);
  }

  int getScannedFacesCount() {
    final handle = _pipelineHandle;
    if (handle == null) return 0;
    return _getScannedFacesCount(handle);
  }

  /// The assembled 54 facelet string, or `null` while fewer than six faces
  /// have been locked in.
  String? getScannedCubeString() {
    final handle = _pipelineHandle;
    if (handle == null) return null;
    final outBuf = calloc<ffi.Uint8>(64).cast<Utf8>();
    try {
      final success = _getScannedCubeString(handle, outBuf, 64);
      if (success == 1) {
        return outBuf.toDartString();
      }
      return null;
    } finally {
      calloc.free(outBuf);
    }
  }

  /// Feeds one packed frame into the native vision pipeline.
  ///
  /// [bytes] must hold at least `bytesPerRow * height` bytes. Returns `null`
  /// when the pipeline has not been initialized, so callers can tell "no result
  /// available" apart from "nothing detected".
  ///
  /// [rotationDegrees] is how far the frame must turn clockwise to appear
  /// upright. Phone sensors are mounted sideways, so this is rarely zero and
  /// getting it wrong makes the sampler read the background instead of the
  /// cube.
  FaceDetection? processFrame(
    Uint8List bytes, {
    required int width,
    required int height,
    int? bytesPerRow,
    int format = 0,
    int rotationDegrees = 0,
  }) {
    final handle = _pipelineHandle;
    final resultPtr = _resultPtr;
    if (handle == null || resultPtr == null) return null;

    final stride = bytesPerRow ?? width;
    final required = stride * height;
    if (bytes.length < required) {
      throw ArgumentError(
        'Frame buffer is ${bytes.length} bytes but $required are required '
        '($width x $height at stride $stride).',
      );
    }

    final buffer = calloc<ffi.Uint8>(required);
    try {
      buffer.asTypedList(required).setAll(0, bytes);
      _processCameraFrame(
          handle, buffer, width, height, stride, format, rotationDegrees, resultPtr);
      return _readResult(resultPtr);
    } finally {
      calloc.free(buffer);
    }
  }

  /// Feeds one YUV_420_888 frame, the layout Android camera streams arrive in.
  ///
  /// Going straight from the camera's native format avoids converting every
  /// pixel in Dart, which for a 720p stream at 10 fps is tens of megabytes of
  /// per-pixel work every second.
  ///
  /// Chroma planes carry their own strides: CameraX pads rows and may
  /// interleave U and V, so the three planes cannot be assumed to be tight
  /// halves of one buffer.
  FaceDetection? processFrameYuv({
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
    int rotationDegrees = 0,
  }) {
    final handle = _pipelineHandle;
    final resultPtr = _resultPtr;
    if (handle == null || resultPtr == null) return null;

    final yPtr = calloc<ffi.Uint8>(yPlane.length);
    final uPtr = calloc<ffi.Uint8>(uPlane.length);
    final vPtr = calloc<ffi.Uint8>(vPlane.length);
    try {
      yPtr.asTypedList(yPlane.length).setAll(0, yPlane);
      uPtr.asTypedList(uPlane.length).setAll(0, uPlane);
      vPtr.asTypedList(vPlane.length).setAll(0, vPlane);

      _processCameraFrameYuv(
        handle,
        yPtr, yStride, yPixelStride,
        uPtr, uStride, uPixelStride,
        vPtr, vStride, vPixelStride,
        width, height, rotationDegrees, resultPtr,
      );
      return _readResult(resultPtr);
    } finally {
      calloc.free(yPtr);
      calloc.free(uPtr);
      calloc.free(vPtr);
    }
  }

  FaceDetection _readResult(ffi.Pointer<NativeDetectionResult> resultPtr) {
    final ref = resultPtr.ref;

    final corners = <({double x, double y})>[];
    for (var i = 0; i < 4; i++) {
      corners.add((x: ref.corners[i].x, y: ref.corners[i].y));
    }
    final stickers = <int>[];
    for (var i = 0; i < 9; i++) {
      stickers.add(ref.stickers[i]);
    }

    return FaceDetection(
      isDetected: ref.isDetected == 1,
      corners: corners,
      stickers: stickers,
      centerColor: ref.centerColor,
      stepAdvanced: ref.stepAdvanced == 1,
      currentStepIndex: ref.currentStepIndex,
      totalSteps: ref.totalSteps,
      faceFrameCount: ref.faceFrameCount,
      windowSize: ref.windowSize,
      ambiguousCells: ref.ambiguousCells,
      assemblyState: ref.assemblyState,
      assemblyScore: ref.assemblyScore,
    );
  }

  void setValidationSolution(String initial54, String moves) {
    final handle = _pipelineHandle;
    if (handle == null) return;
    final cInit = initial54.toNativeUtf8();
    final cMoves = moves.toNativeUtf8();
    try {
      _setValidationSolution(handle, cInit, cMoves);
    } finally {
      calloc.free(cInit);
      calloc.free(cMoves);
    }
  }

  void stepNavigate(int direction) {
    final handle = _pipelineHandle;
    if (handle == null) return;
    _manualStepNavigate(handle, direction);
  }
}
