import 'dart:async';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show DeviceOrientation;

import '../../core/native_bridge/rubik_ffi_bridge.dart';
import '../../core/vision/scanner_service.dart';
import '../../models/cube_color.dart';
import '../../models/solution_step.dart';
import 'solver_screen.dart';

/// Fraction of the shorter frame edge the guide box spans.
///
/// This must stay equal to the default `sideFraction` of `sampleFaceGrid` in
/// `vision_pipeline.hpp`. The two are the same rectangle by construction, which
/// is why the box drawn here needs no projection maths to line up with what the
/// native side actually measures.
const double kGuideSideFraction = 0.72;

class ScanScreen extends StatefulWidget {
  final SolveMode mode;
  const ScanScreen({Key? key, required this.mode}) : super(key: key);

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final ScannerService _scanner = ScannerService();

  CameraController? _controller;
  String? _cameraError;

  /// Frames are throttled: the camera delivers 30 per second but the vote only
  /// needs a handful, and running the pipeline flat out just heats the phone.
  static const Duration _frameInterval = Duration(milliseconds: 90);
  DateTime _lastFrameAt = DateTime.fromMillisecondsSinceEpoch(0);

  /// Extra rotation on top of the computed sensor rotation.
  ///
  /// The sensor orientation formula is right for the common case but depends on
  /// device orientation reporting that not every OEM implements identically,
  /// and a wrong value points the sampling grid at the background. Since a
  /// quarter turn is the only thing that can be wrong, the app can just try the
  /// other three rather than asking the user to debug it.
  int _rotationExtra = 0;
  int _consecutiveMisses = 0;

  /// Once anything has been recognised the rotation is clearly right; searching
  /// after that would restart a scan the user is halfway through.
  bool _hasEverDetected = false;

  bool _finishing = false;

  @override
  void initState() {
    super.initState();
    _scanner.startScanning();
    _openCamera();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _openCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) setState(() => _cameraError = '设备上没有找到可用的摄像头。');
        return;
      }

      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        camera,
        // 720p is plenty: the guide box covers less than half of the frame, so
        // each sticker still gets well over a hundred pixels to average.
        ResolutionPreset.medium,
        enableAudio: false,
        // Feeding the camera's native layout straight to the engine avoids a
        // per-pixel RGB conversion in Dart, which at 720p would cost far more
        // than the recognition it feeds.
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      await controller.startImageStream(_onFrame);

      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _controller = controller);
    } on CameraException catch (e) {
      if (mounted) {
        setState(() => _cameraError = '相机不可用：${e.description ?? e.code}');
      }
    } catch (e) {
      if (mounted) setState(() => _cameraError = '相机初始化失败：$e');
    }
  }

  /// How far the stream must be rotated clockwise to appear upright.
  ///
  /// Phone sensors are mounted sideways, so the raw buffer is landscape on a
  /// portrait phone. Getting this wrong points the sampling grid at the table
  /// instead of the cube, which looks like "recognition is broken" rather than
  /// like an orientation bug.
  int _rotationDegrees() {
    final controller = _controller;
    if (controller == null) return (90 + _rotationExtra) % 360;

    final sensor = controller.description.sensorOrientation;
    final device = _deviceOrientationDegrees(controller.value.deviceOrientation);

    final base = controller.description.lensDirection == CameraLensDirection.front
        ? (sensor + device) % 360
        : (sensor - device + 360) % 360;
    return (base + _rotationExtra) % 360;
  }

  static int _deviceOrientationDegrees(DeviceOrientation orientation) {
    switch (orientation) {
      case DeviceOrientation.portraitUp:
        return 0;
      case DeviceOrientation.landscapeLeft:
        return 90;
      case DeviceOrientation.portraitDown:
        return 180;
      case DeviceOrientation.landscapeRight:
        return 270;
    }
  }
  void _onFrame(CameraImage image) {
    final now = DateTime.now();
    if (now.difference(_lastFrameAt) < _frameInterval) return;
    _lastFrameAt = now;

    if (image.planes.length < 3) return;

    final y = image.planes[0];
    final u = image.planes[1];
    final v = image.planes[2];

    // `bytesPerPixel` is the Android pixel stride; it is null on iOS, where
    // planes are tightly packed, hence the fallback of 1.
    _scanner.processYuvFrame(
      yPlane: y.bytes,
      yStride: y.bytesPerRow,
      yPixelStride: y.bytesPerPixel ?? 1,
      uPlane: u.bytes,
      uStride: u.bytesPerRow,
      uPixelStride: u.bytesPerPixel ?? 1,
      vPlane: v.bytes,
      vStride: v.bytesPerRow,
      vPixelStride: v.bytesPerPixel ?? 1,
      width: image.width,
      height: image.height,
      rotationDegrees: _rotationDegrees(),
    );

    _trackDetectionQuality();

    if (mounted) setState(() {});
    _maybeFinish();
  }

  /// Rotates through the four possible sensor orientations while nothing has
  /// been recognised yet.
  ///
  /// The guide box is a lot smaller than the frame, so a wrong quarter turn
  /// makes the sampler read the background and report "nothing there" forever.
  /// That looks identical to a broken build from the user's side, so it is
  /// worth fixing automatically instead of shipping a debug menu.
  void _trackDetectionQuality() {
    if (_hasEverDetected) return;

    if (_scanner.lastDetection?.isDetected == true) {
      _hasEverDetected = true;
      _consecutiveMisses = 0;
      return;
    }

    _consecutiveMisses++;
    if (_consecutiveMisses >= 18) {
      _consecutiveMisses = 0;
      _rotationExtra = (_rotationExtra + 90) % 360;
    }
  }

  /// Leaves for the solver as soon as the native side has stitched a solvable
  /// cube. Six locked faces alone are not enough - the stitch can still fail,
  /// and that failure is reported in place rather than by navigating.
  void _maybeFinish() {
    if (_finishing || !mounted || _scanner.scannedState == null) return;
    _finishing = true;

    final state = _scanner.scannedState!;
    _controller?.stopImageStream().catchError((Object _) {});
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => SolverScreen(initialState: state, mode: widget.mode),
      ),
    );
  }

  void _restartScan() {
    _scanner.startScanning();
    setState(() => _finishing = false);
  }

  /// Aspect ratio of the upright preview, matching the coordinate system the
  /// native sampler works in.
  double _uprightAspectRatio() {
    final size = _controller?.value.previewSize;
    if (size == null || size.width <= 0 || size.height <= 0) return 3 / 4;

    final quarterTurn = _rotationDegrees() % 180 != 0;
    final w = quarterTurn ? size.height : size.width;
    final h = quarterTurn ? size.width : size.height;
    return w / h;
  }

  String get _guidance {
    if (_scanner.assemblyState == ScanAssemblyState.failed) {
      return '六面无法拼成合法魔方（合法块 ${_scanner.assemblyScore}/20）\n'
          '请检查光照，或点击右上角重新扫描';
    }

    final detection = _scanner.lastDetection;
    if (detection != null && !detection.isDetected) {
      return '看不到魔方\n把魔方放进取景框，让它填满框内区域';
    }

    if (_scanner.scannedFacesCount == 0) {
      return '把白色面朝向镜头，让魔方填满取景框';
    }
    if (_scanner.scannedFacesCount < 6) {
      return '已识别 ${_scanner.scannedFacesCount} 面，转动魔方换下一面';
    }
    return '六面已识别，正在拼合校验…';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('扫描魔方 (${_scanner.scannedFacesCount}/6 面)'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: '重新扫描',
            onPressed: _restartScan,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_cameraError != null) return _buildCameraError(_cameraError!);

    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF00E676)),
            SizedBox(height: 16),
            Text('正在启动摄像头…', style: TextStyle(color: Colors.white70)),
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(child: _buildPreview(controller)),
        _buildStatusPanel(),
      ],
    );
  }

  Widget _buildCameraError(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.no_photography_outlined, size: 64, color: Colors.white38),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 12),
            const Text(
              '可在首页选择「手动涂色校准」直接录入魔方状态。',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: () {
                setState(() => _cameraError = null);
                _openCamera();
              },
              child: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }

  /// Preview and overlay share one [AspectRatio] so the guide box sits exactly
  /// over the region the native sampler reads. Sizing them independently is how
  /// these overlays usually drift apart.
  Widget _buildPreview(CameraController controller) {
    final detection = _scanner.lastDetection;

    return Center(
      child: AspectRatio(
        aspectRatio: _uprightAspectRatio(),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CameraPreview(controller),
            CustomPaint(
              painter: _GuideOverlayPainter(
                stickers: detection?.stickers,
                locked: _scanner.scannedFacesCount,
                ambiguousCells: detection?.ambiguousCells ?? 0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusPanel() {
    final detection = _scanner.lastDetection;
    final failed = _scanner.assemblyState == ScanAssemblyState.failed;
    final progress = detection?.faceProgress ?? 0.0;

    return Container(
      width: double.infinity,
      color: const Color(0xFF12121E),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(6, (i) {
                final done = i < _scanner.scannedFacesCount;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 34,
                  height: 8,
                  decoration: BoxDecoration(
                    color: done ? const Color(0xFF00E676) : Colors.white24,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
            const SizedBox(height: 12),
            Text(
              _guidance,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: failed ? const Color(0xFFFF5252) : Colors.white70,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 10),

            // Settling progress for the face in view. Without it a user has no
            // way to tell "hold still" apart from "it is not detecting".
            if (!failed && _scanner.scannedFacesCount < 6)
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 4,
                  backgroundColor: Colors.white12,
                  valueColor: const AlwaysStoppedAnimation(Color(0xFF00E676)),
                ),
              ),

            if (detection != null && detection.ambiguousCells > 0 && !failed) ...[
              const SizedBox(height: 8),
              Text(
                '有 ${detection.ambiguousCells} 格颜色相近，靠近一点或调亮光线',
                style: const TextStyle(color: Color(0xFFFFB74D), fontSize: 12),
              ),
            ],

            if (failed) ...[
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _restartScan,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('重新扫描'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E676),
                  foregroundColor: Colors.black,
                ),
              ),
            ],

            if (!_scanner.isEngineReady && _scanner.engineError != null) ...[
              const SizedBox(height: 8),
              Text(
                _scanner.engineError!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFFFF5252), fontSize: 11),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Draws the guide box and mirrors the nine recognised colours into it.
///
/// Showing the per-cell result is what turns the scan from a black box into
/// something the user can steer: a wrong reading is visible immediately, so
/// they can move the cube or the light instead of completing six bad faces and
/// finding out at the end.
class _GuideOverlayPainter extends CustomPainter {
  _GuideOverlayPainter({
    required this.stickers,
    required this.locked,
    required this.ambiguousCells,
  });

  final List<int>? stickers;
  final int locked;
  final int ambiguousCells;

  @override
  void paint(Canvas canvas, Size size) {
    final side = math.min(size.width, size.height) * kGuideSideFraction;
    final left = (size.width - side) / 2;
    final top = (size.height - side) / 2;
    final cell = side / 3;

    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = locked == 0 ? Colors.white70 : const Color(0xFF00E676);

    // The cells first, so the border and grid lines sit on top of them.
    if (stickers != null && stickers!.length == 9) {
      for (var r = 0; r < 3; r++) {
        for (var c = 0; c < 3; c++) {
          final rect = Rect.fromLTWH(
            left + c * cell,
            top + r * cell,
            cell,
            cell,
          ).deflate(3);

          final color = CubeColor.fromInt(stickers![r * 3 + c]).displayColor;
          canvas.drawRRect(
            RRect.fromRectAndRadius(rect, const Radius.circular(8)),
            Paint()..color = color.withValues(alpha: 0.55),
          );
        }
      }
    }

    final gridPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white24;
    for (var i = 1; i < 3; i++) {
      canvas.drawLine(
        Offset(left + i * cell, top),
        Offset(left + i * cell, top + side),
        gridPaint,
      );
      canvas.drawLine(
        Offset(left, top + i * cell),
        Offset(left + side, top + i * cell),
        gridPaint,
      );
    }

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(left, top, side, side),
        const Radius.circular(12),
      ),
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _GuideOverlayPainter old) {
    return old.locked != locked ||
        old.ambiguousCells != ambiguousCells ||
        !_sameStickers(old.stickers, stickers);
  }

  static bool _sameStickers(List<int>? a, List<int>? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null || a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
