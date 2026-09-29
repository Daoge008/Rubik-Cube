import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/cube_color.dart';
import '../../models/cube_state.dart';

/// Interactive 3D Rubik's Cube simulation widget.
///
/// Supports:
/// - Perspective 3D rendering with dynamic lighting and depth sorting
/// - Dragging blank space rotates the entire cube camera angle (pitch & yaw)
/// - Swiping on a face turns that layer/face with animation and haptic feedback
/// - Double tap to reset orientation
/// - Optional tap-to-color callback for manual calibration mode
class InteractiveCube3D extends StatefulWidget {
  final CubeState state;
  final double size;
  final bool interactive;
  final bool allowFaceTurns;
  final ValueChanged<String>? onMoveApplied;
  final ValueChanged<int>? onFacetTap;
  final String? highlightMove;

  const InteractiveCube3D({
    super.key,
    required this.state,
    this.size = 280,
    this.interactive = true,
    this.allowFaceTurns = true,
    this.onMoveApplied,
    this.onFacetTap,
    this.highlightMove,
  });

  @override
  State<InteractiveCube3D> createState() => _InteractiveCube3DState();
}

class _InteractiveCube3DState extends State<InteractiveCube3D>
    with SingleTickerProviderStateMixin {
  // Camera view angles for standard convex 3D cube view
  double _yaw = -0.65; // ~-37 degrees (reveals Front & Right)
  double _pitch = 0.45; // ~+26 degrees (reveals Up / Top)

  // Animation controller for face turns
  late AnimationController _turnController;
  late Animation<double> _turnAnimation;
  String? _animatingMove;
  double _animatingTargetAngle = 0;
  CubeState? _preAnimState;

  // Touch tracking
  Offset? _panStartPos;
  _HitTestResult? _panHit;
  bool _isTurnTriggered = false;
  bool _isCameraRotating = false;

  @override
  void initState() {
    super.initState();
    _turnController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _turnAnimation = CurvedAnimation(
      parent: _turnController,
      curve: Curves.easeInOutCubic,
    );
    _turnController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (_animatingMove != null && _preAnimState != null) {
          final move = _animatingMove!;
          setState(() {
            _animatingMove = null;
            _preAnimState = null;
          });
          widget.onMoveApplied?.call(move);
        }
      }
    });
  }

  @override
  void dispose() {
    _turnController.dispose();
    super.dispose();
  }

  void _resetView() {
    setState(() {
      _yaw = -0.65;
      _pitch = 0.45;
    });
  }

  /// Triggers an animated face turn (e.g. "R", "U'", "F2").
  void animateMove(String move) {
    if (_turnController.isAnimating) return;

    final m = move.trim();
    if (m.isEmpty) return;

    int turns = 1;
    if (m.contains('2')) {
      turns = 2;
    } else if (m.contains("'") || m.contains('3')) {
      turns = -1;
    }

    setState(() {
      _animatingMove = move;
      _animatingTargetAngle = turns * math.pi / 2;
      _preAnimState = widget.state;
    });

    _turnController.forward(from: 0.0);
    HapticFeedback.lightImpact();
  }

  void _onPanStart(DragStartDetails details) {
    if (!widget.interactive) return;
    _panStartPos = details.localPosition;
    _isTurnTriggered = false;
    _isCameraRotating = false;

    if (widget.allowFaceTurns && !_turnController.isAnimating) {
      _panHit = _hitTest(details.localPosition);
    } else {
      _panHit = null;
    }

    if (_panHit == null) {
      _isCameraRotating = true;
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!widget.interactive || _panStartPos == null) return;

    final delta = details.localPosition - _panStartPos!;

    // If touching blank space or decided to rotate camera
    if (_isCameraRotating || _panHit == null) {
      setState(() {
        _yaw += details.delta.dx * 0.012;
        _pitch = (_pitch + details.delta.dy * 0.012).clamp(-1.35, 1.35);
      });
      return;
    }

    // Swiping on a face
    if (!_isTurnTriggered && widget.allowFaceTurns && _panHit != null) {
      if (delta.distance > 18) {
        final move = _resolveMoveFromSwipe(_panHit!, delta);
        if (move != null) {
          _isTurnTriggered = true;
          animateMove(move);
        } else {
          // If gesture is ambiguous, fall back to rotating camera
          _isCameraRotating = true;
        }
      }
    }
  }

  void _onPanEnd(DragEndDetails details) {
    if (!widget.interactive) return;

    // Check if it was a quick tap
    if (!_isTurnTriggered && !_isCameraRotating && _panHit != null && _panStartPos != null) {
      if (widget.onFacetTap != null) {
        widget.onFacetTap!(_panHit!.facetIndex);
        HapticFeedback.selectionClick();
      }
    }

    _panStartPos = null;
    _panHit = null;
    _isTurnTriggered = false;
    _isCameraRotating = false;
  }

  /// Maps a swipe on a facelet to a Rubik's Cube turn notation.
  String? _resolveMoveFromSwipe(_HitTestResult hit, Offset delta) {
    final uScreen = hit.uScreenVec;
    final vScreen = hit.vScreenVec;

    final dotU = delta.dx * uScreen.dx + delta.dy * uScreen.dy;
    final dotV = delta.dx * vScreen.dx + delta.dy * vScreen.dy;

    final isHorizontal = dotU.abs() > dotV.abs();
    final sign = isHorizontal ? (dotU > 0 ? 1 : -1) : (dotV > 0 ? 1 : -1);

    final face = hit.faceIndex;
    final row = hit.row;
    final col = hit.col;

    // Face mapping:
    // 0: U, 1: R, 2: F, 3: D, 4: L, 5: B
    switch (face) {
      case 2: // Front (F)
        if (isHorizontal) {
          if (row == 0) return sign > 0 ? "U'" : "U";
          if (row == 2) return sign > 0 ? "D" : "D'";
        } else {
          if (col == 0) return sign > 0 ? "L" : "L'";
          if (col == 2) return sign > 0 ? "R'" : "R";
        }
        break;

      case 0: // Up (U)
        if (isHorizontal) {
          if (row == 0) return sign > 0 ? "B'" : "B";
          if (row == 2) return sign > 0 ? "F" : "F'";
        } else {
          if (col == 0) return sign > 0 ? "L" : "L'";
          if (col == 2) return sign > 0 ? "R'" : "R";
        }
        break;

      case 3: // Down (D)
        if (isHorizontal) {
          if (row == 0) return sign > 0 ? "F'" : "F";
          if (row == 2) return sign > 0 ? "B" : "B'";
        } else {
          if (col == 0) return sign > 0 ? "L'" : "L";
          if (col == 2) return sign > 0 ? "R" : "R'";
        }
        break;

      case 1: // Right (R)
        if (isHorizontal) {
          if (row == 0) return sign > 0 ? "U'" : "U";
          if (row == 2) return sign > 0 ? "D" : "D'";
        } else {
          if (col == 0) return sign > 0 ? "F'" : "F";
          if (col == 2) return sign > 0 ? "B" : "B'";
        }
        break;

      case 4: // Left (L)
        if (isHorizontal) {
          if (row == 0) return sign > 0 ? "U'" : "U";
          if (row == 2) return sign > 0 ? "D" : "D'";
        } else {
          if (col == 0) return sign > 0 ? "B" : "B'";
          if (col == 2) return sign > 0 ? "F'" : "F";
        }
        break;

      case 5: // Back (B)
        if (isHorizontal) {
          if (row == 0) return sign > 0 ? "U'" : "U";
          if (row == 2) return sign > 0 ? "D" : "D'";
        } else {
          if (col == 0) return sign > 0 ? "R" : "R'";
          if (col == 2) return sign > 0 ? "L'" : "L";
        }
        break;
    }

    return null;
  }

  _HitTestResult? _hitTest(Offset pos) {
    final quads = _computeProjectedQuads();
    for (var i = quads.length - 1; i >= 0; i--) {
      final q = quads[i];
      if (_pointInPolygon(pos, q.points)) {
        return _HitTestResult(
          faceIndex: q.faceIndex,
          row: q.row,
          col: q.col,
          facetIndex: q.faceIndex * 9 + q.row * 3 + q.col,
          uScreenVec: q.uScreen,
          vScreenVec: q.vScreen,
        );
      }
    }
    return null;
  }

  static bool _pointInPolygon(Offset p, List<Offset> poly) {
    if (poly.length < 3) return false;
    var inside = false;
    for (int i = 0, j = poly.length - 1; i < poly.length; j = i++) {
      if (((poly[i].dy > p.dy) != (poly[j].dy > p.dy)) &&
          (p.dx < (poly[j].dx - poly[i].dx) * (p.dy - poly[i].dy) /
                  (poly[j].dy - poly[i].dy) + poly[i].dx)) {
        inside = !inside;
      }
    }
    return inside;
  }

  List<_ProjectedQuad> _computeProjectedQuads() {
    final center = Offset(widget.size / 2, widget.size / 2);
    final scale = widget.size / 5.2;
    const camDist = 5.5;

    double animAngle = 0;
    String? animFace;
    if (_animatingMove != null && _turnController.isAnimating) {
      animAngle = _turnAnimation.value * _animatingTargetAngle;
      animFace = _animatingMove![0].toUpperCase();
    }

    final activeState = _preAnimState ?? widget.state;
    final quads = <_ProjectedQuad>[];

    for (var f = 0; f < 6; f++) {
      for (var r = 0; r < 3; r++) {
        for (var c = 0; c < 3; c++) {
          final quad = _buildStickerQuad(
            f, r, c,
            animFace: animFace,
            animAngle: animAngle,
            yaw: _yaw,
            pitch: _pitch,
            center: center,
            scale: scale,
            camDist: camDist,
            color: activeState.facelets[f * 9 + r * 3 + c],
          );
          if (quad != null) quads.add(quad);
        }
      }
    }

    quads.sort((a, b) => a.depth.compareTo(b.depth));
    return quads;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      onDoubleTap: _resetView,
      child: AnimatedBuilder(
        animation: _turnAnimation,
        builder: (context, _) {
          return CustomPaint(
            size: Size(widget.size, widget.size),
            painter: _Cube3DPainter(
              state: _preAnimState ?? widget.state,
              yaw: _yaw,
              pitch: _pitch,
              animFace: _animatingMove != null ? _animatingMove![0].toUpperCase() : null,
              animAngle: _turnAnimation.value * _animatingTargetAngle,
              highlightMove: widget.highlightMove,
            ),
          );
        },
      ),
    );
  }
}

class _HitTestResult {
  final int faceIndex;
  final int row;
  final int col;
  final int facetIndex;
  final Offset uScreenVec;
  final Offset vScreenVec;

  _HitTestResult({
    required this.faceIndex,
    required this.row,
    required this.col,
    required this.facetIndex,
    required this.uScreenVec,
    required this.vScreenVec,
  });
}

class _ProjectedQuad {
  final int faceIndex;
  final int row;
  final int col;
  final List<Offset> points;
  final double depth;
  final Offset uScreen;
  final Offset vScreen;
  final CubeColor color;
  final double lighting;

  _ProjectedQuad({
    required this.faceIndex,
    required this.row,
    required this.col,
    required this.points,
    required this.depth,
    required this.uScreen,
    required this.vScreen,
    required this.color,
    required this.lighting,
  });
}

class _Vec3 {
  final double x, y, z;
  const _Vec3(this.x, this.y, this.z);

  _Vec3 operator +(_Vec3 o) => _Vec3(x + o.x, y + o.y, z + o.z);
  _Vec3 operator -(_Vec3 o) => _Vec3(x - o.x, y - o.y, z - o.z);
  _Vec3 operator *(double s) => _Vec3(x * s, y * s, z * s);

  double dot(_Vec3 o) => x * o.x + y * o.y + z * o.z;

  _Vec3 normalized() {
    final len = math.sqrt(x * x + y * y + z * z);
    return len > 0 ? _Vec3(x / len, y / len, z / len) : this;
  }
}

_Vec3 _rotateX(_Vec3 v, double a) {
  final c = math.cos(a);
  final s = math.sin(a);
  return _Vec3(v.x, v.y * c - v.z * s, v.y * s + v.z * c);
}

_Vec3 _rotateY(_Vec3 v, double a) {
  final c = math.cos(a);
  final s = math.sin(a);
  return _Vec3(v.x * c + v.z * s, v.y, -v.x * s + v.z * c);
}

_Vec3 _rotateZ(_Vec3 v, double a) {
  final c = math.cos(a);
  final s = math.sin(a);
  return _Vec3(v.x * c - v.y * s, v.x * s + v.y * c, v.z);
}

_ProjectedQuad? _buildStickerQuad(
  int faceIndex,
  int row,
  int col, {
  String? animFace,
  double animAngle = 0,
  required double yaw,
  required double pitch,
  required Offset center,
  required double scale,
  required double camDist,
  required CubeColor color,
}) {
  double cx = 0, cy = 0, cz = 0;
  _Vec3 uDir = const _Vec3(1, 0, 0);
  _Vec3 vDir = const _Vec3(0, 1, 0);
  _Vec3 normal = const _Vec3(0, 0, 1);

  switch (faceIndex) {
    case 0: // U (Up, y = 1.5)
      cx = (col - 1).toDouble();
      cy = 1.5;
      cz = (row - 1).toDouble();
      uDir = const _Vec3(1, 0, 0);
      vDir = const _Vec3(0, 0, 1);
      normal = const _Vec3(0, 1, 0);
      break;

    case 3: // D (Down, y = -1.5)
      cx = (col - 1).toDouble();
      cy = -1.5;
      cz = (1 - row).toDouble();
      uDir = const _Vec3(1, 0, 0);
      vDir = const _Vec3(0, 0, -1);
      normal = const _Vec3(0, -1, 0);
      break;

    case 2: // F (Front, z = 1.5)
      cx = (col - 1).toDouble();
      cy = (1 - row).toDouble();
      cz = 1.5;
      uDir = const _Vec3(1, 0, 0);
      vDir = const _Vec3(0, -1, 0);
      normal = const _Vec3(0, 0, 1);
      break;

    case 5: // B (Back, z = -1.5)
      cx = (1 - col).toDouble();
      cy = (1 - row).toDouble();
      cz = -1.5;
      uDir = const _Vec3(-1, 0, 0);
      vDir = const _Vec3(0, -1, 0);
      normal = const _Vec3(0, 0, -1);
      break;

    case 1: // R (Right, x = 1.5)
      cx = 1.5;
      cy = (1 - row).toDouble();
      cz = (1 - col).toDouble();
      uDir = const _Vec3(0, 0, -1);
      vDir = const _Vec3(0, -1, 0);
      normal = const _Vec3(1, 0, 0);
      break;

    case 4: // L (Left, x = -1.5)
      cx = -1.5;
      cy = (1 - row).toDouble();
      cz = (col - 1).toDouble();
      uDir = const _Vec3(0, 0, 1);
      vDir = const _Vec3(0, -1, 0);
      normal = const _Vec3(-1, 0, 0);
      break;
  }

  const hw = 0.43;
  final localCorners = [
    _Vec3(cx, cy, cz) + uDir * (-hw) + vDir * (-hw),
    _Vec3(cx, cy, cz) + uDir * hw + vDir * (-hw),
    _Vec3(cx, cy, cz) + uDir * hw + vDir * hw,
    _Vec3(cx, cy, cz) + uDir * (-hw) + vDir * hw,
  ];

  _Vec3 applyLayerTurn(_Vec3 p) {
    if (animFace == null || animAngle == 0) return p;
    switch (animFace) {
      case 'U':
        if (p.y > 0.5) return _rotateY(p, -animAngle);
        break;
      case 'D':
        if (p.y < -0.5) return _rotateY(p, animAngle);
        break;
      case 'R':
        if (p.x > 0.5) return _rotateX(p, -animAngle);
        break;
      case 'L':
        if (p.x < -0.5) return _rotateX(p, animAngle);
        break;
      case 'F':
        if (p.z > 0.5) return _rotateZ(p, -animAngle);
        break;
      case 'B':
        if (p.z < -0.5) return _rotateZ(p, animAngle);
        break;
    }
    return p;
  }

  _Vec3 transform(_Vec3 p) {
    var v = applyLayerTurn(p);
    v = _rotateY(v, yaw);
    v = _rotateX(v, pitch);
    return v;
  }

  final transformedNorm = (transform(normal) - transform(const _Vec3(0, 0, 0))).normalized();
  // Camera is at +Z (camDist = 5.5) looking at origin (0, 0, 0).
  // Front-facing exterior faces pointing toward camera have positive Z normal.
  // Cull back-facing surfaces pointing away from camera (z <= 0.05).
  if (transformedNorm.z <= 0.05) {
    return null;
  }

  // Light coming from top-right in front of the cube
  final lightDir = const _Vec3(0.40, 0.65, 0.65).normalized();
  final diffuse = math.max(0.0, transformedNorm.dot(lightDir));
  final lighting = 0.72 + 0.28 * diffuse;

  final pts = <Offset>[];
  double totalDepth = 0;
  for (final c in localCorners) {
    final v = transform(c);
    totalDepth += v.z;
    final k = camDist / (camDist - v.z);
    final px = center.dx + v.x * k * scale;
    final py = center.dy - v.y * k * scale;
    pts.add(Offset(px, py));
  }

  final centerTrans = transform(_Vec3(cx, cy, cz));
  final uTrans = transform(_Vec3(cx, cy, cz) + uDir * 0.5);
  final vTrans = transform(_Vec3(cx, cy, cz) + vDir * 0.5);

  final kC = camDist / (camDist - centerTrans.z);
  final cPx = center.dx + centerTrans.x * kC * scale;
  final cPy = center.dy - centerTrans.y * kC * scale;

  final kU = camDist / (camDist - uTrans.z);
  final uPx = center.dx + uTrans.x * kU * scale;
  final uPy = center.dy - uTrans.y * kU * scale;

  final kV = camDist / (camDist - vTrans.z);
  final vPx = center.dx + vTrans.x * kV * scale;
  final vPy = center.dy - vTrans.y * kV * scale;

  final uScreen = Offset(uPx - cPx, uPy - cPy);
  final vScreen = Offset(vPx - cPx, vPy - cPy);

  return _ProjectedQuad(
    faceIndex: faceIndex,
    row: row,
    col: col,
    points: pts,
    depth: totalDepth / 4,
    uScreen: uScreen,
    vScreen: vScreen,
    color: color,
    lighting: lighting,
  );
}

class _Cube3DPainter extends CustomPainter {
  final CubeState state;
  final double yaw;
  final double pitch;
  final String? animFace;
  final double animAngle;
  final String? highlightMove;

  _Cube3DPainter({
    required this.state,
    required this.yaw,
    required this.pitch,
    this.animFace,
    this.animAngle = 0,
    this.highlightMove,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final scale = size.width / 5.2;
    const camDist = 5.5;

    final quads = <_ProjectedQuad>[];
    for (var f = 0; f < 6; f++) {
      for (var r = 0; r < 3; r++) {
        for (var c = 0; c < 3; c++) {
          final quad = _buildStickerQuad(
            f, r, c,
            animFace: animFace,
            animAngle: animAngle,
            yaw: yaw,
            pitch: pitch,
            center: center,
            scale: scale,
            camDist: camDist,
            color: state.facelets[f * 9 + r * 3 + c],
          );
          if (quad != null) quads.add(quad);
        }
      }
    }

    quads.sort((a, b) => a.depth.compareTo(b.depth));

    String? hlFace;
    if (highlightMove != null && highlightMove!.isNotEmpty) {
      hlFace = highlightMove![0].toUpperCase();
    }

    final borderPaint = Paint()
      ..color = const Color(0xFF151515)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;

    final stickerPaint = Paint()..style = PaintingStyle.fill;

    for (final q in quads) {
      final baseColor = q.color.displayColor;
      final litColor = Color.fromARGB(
        255,
        ((baseColor.r * 255.0) * q.lighting).round().clamp(0, 255),
        ((baseColor.g * 255.0) * q.lighting).round().clamp(0, 255),
        ((baseColor.b * 255.0) * q.lighting).round().clamp(0, 255),
      );

      final path = Path()
        ..moveTo(q.points[0].dx, q.points[0].dy)
        ..lineTo(q.points[1].dx, q.points[1].dy)
        ..lineTo(q.points[2].dx, q.points[2].dy)
        ..lineTo(q.points[3].dx, q.points[3].dy)
        ..close();

      stickerPaint.color = litColor;
      canvas.drawPath(path, stickerPaint);
      canvas.drawPath(path, borderPaint);

      final faceLetter = ['U', 'R', 'F', 'D', 'L', 'B'][q.faceIndex];
      if (hlFace == faceLetter) {
        final hlPaint = Paint()
          ..color = const Color(0xFF00E676).withValues(alpha: 0.65)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0;
        canvas.drawPath(path, hlPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _Cube3DPainter old) {
    return old.state != state ||
        old.yaw != yaw ||
        old.pitch != pitch ||
        old.animAngle != animAngle ||
        old.highlightMove != highlightMove;
  }
}
