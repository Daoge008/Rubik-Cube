import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/sound_service.dart';
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
  // Camera view angles
  double _yaw = 0.65; // ~37 degrees
  double _pitch = -0.45; // ~-26 degrees

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
      _yaw = 0.65;
      _pitch = -0.45;
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
    CubeSoundService.instance.playClick();
  }

  void _onScaleStart(ScaleStartDetails details) {
    if (!widget.interactive) return;

    // Dual-finger drag: rotate whole cube (camera)
    if (details.pointerCount >= 2) {
      _isCameraRotating = true;
      _panHit = null;
      _isTurnTriggered = false;
      return;
    }

    _panStartPos = details.localFocalPoint;
    _isTurnTriggered = false;
    _isCameraRotating = false;

    if (widget.allowFaceTurns && !_turnController.isAnimating) {
      _panHit = _hitTest(details.localFocalPoint);
    } else {
      _panHit = null;
    }

    if (_panHit == null) {
      _isCameraRotating = true;
    }
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (!widget.interactive) return;

    // Dual fingers: ALWAYS rotate entire cube (camera)
    if (details.pointerCount >= 2) {
      setState(() {
        _yaw += details.focalPointDelta.dx * 0.012;
        _pitch = (_pitch + details.focalPointDelta.dy * 0.012).clamp(-1.35, 1.35);
      });
      return;
    }

    // Single finger in blank space / edge area: camera rotate
    if (_isCameraRotating || _panHit == null) {
      setState(() {
        _yaw += details.focalPointDelta.dx * 0.012;
        _pitch = (_pitch + details.focalPointDelta.dy * 0.012).clamp(-1.35, 1.35);
      });
      return;
    }

    // Single finger on cube: trigger face/slice turn
    if (!_isTurnTriggered && widget.allowFaceTurns && _panStartPos != null) {
      final delta = details.localFocalPoint - _panStartPos!;
      if (delta.distance > 16) {
        final move = _resolveMoveFromSwipe(_panHit!, delta);
        if (move != null) {
          _isTurnTriggered = true;
          animateMove(move);
        }
      }
    }
  }

  void _onScaleEnd(ScaleEndDetails details) {
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
  ///
  /// Convention: drag a sticker in direction D → the slice that sticker lives
  /// on moves in that same direction (natural feel).
  String? _resolveMoveFromSwipe(_HitTestResult hit, Offset delta) {
    final uScreen = hit.uScreenVec; // +u → screen-right on this face
    final vScreen = hit.vScreenVec; // +v → screen-down on this face

    final dotU = delta.dx * uScreen.dx + delta.dy * uScreen.dy;
    final dotV = delta.dx * vScreen.dx + delta.dy * vScreen.dy;

    // Determine dominant swipe axis on this face
    final isHorizontal = dotU.abs() > dotV.abs();

    // Positive sign means swipe in the +u (horizontal) or +v (vertical) direction
    final sign = isHorizontal ? (dotU > 0 ? 1 : -1) : (dotV > 0 ? 1 : -1);

    final face = hit.faceIndex;
    final row  = hit.row;
    final col  = hit.col;

    // Helper: pick from (positive-sign move, negative-sign move)
    String pick(String pos, String neg) => sign > 0 ? pos : neg;

    switch (face) {
      // ── Front face (F, z = +1.5) ──────────────────────────────────────────
      // +u = right, +v = down
      case 2:
        if (isHorizontal) {
          // Horizontal swipe → moves a horizontal slice (U/E/D)
          // Swiping right on F top row → U' (top goes right = U')
          if (row == 0) return pick("U'", "U");
          if (row == 1) return pick("E",  "E'");
          if (row == 2) return pick("D",  "D'");
        } else {
          // Vertical swipe → moves a vertical slice (L/M/R)
          // Swiping down on F left col → L (left face goes down = L)
          if (col == 0) return pick("L",  "L'");
          if (col == 1) return pick("M",  "M'");
          if (col == 2) return pick("R'", "R");
        }
        break;

      // ── Up face (U, y = +1.5) ─────────────────────────────────────────────
      // +u = right (world +x), +v = forward (world +z)
      case 0:
        if (isHorizontal) {
          // Horizontal swipe → moves a "depth" slice as seen from top (B/U slice/F)
          if (row == 0) return pick("B",  "B'");
          if (row == 1) return pick("U",  "U'"); // middle of U face → rotate U layer
          if (row == 2) return pick("F'", "F");
        } else {
          // Vertical (depth) swipe → moves a left/right slice
          if (col == 0) return pick("L'", "L");
          if (col == 1) return pick("M'", "M");
          if (col == 2) return pick("R",  "R'");
        }
        break;

      // ── Down face (D, y = -1.5) ───────────────────────────────────────────
      case 3:
        if (isHorizontal) {
          if (row == 0) return pick("F",  "F'");
          if (row == 1) return pick("D'", "D");
          if (row == 2) return pick("B'", "B");
        } else {
          if (col == 0) return pick("L'", "L");
          if (col == 1) return pick("M'", "M");
          if (col == 2) return pick("R",  "R'");
        }
        break;

      // ── Right face (R, x = +1.5) ──────────────────────────────────────────
      // +u = screen-left (world -z), +v = screen-down (world -y)
      case 1:
        if (isHorizontal) {
          // Horizontal swipe on R → moves a vertical layer (U/E/D)
          if (row == 0) return pick("U",  "U'");
          if (row == 1) return pick("E'", "E");
          if (row == 2) return pick("D'", "D");
        } else {
          // Vertical swipe on R → moves a depth slice (F/S/B)
          if (col == 0) return pick("F'", "F");
          if (col == 1) return pick("S'", "S");
          if (col == 2) return pick("B",  "B'");
        }
        break;

      // ── Left face (L, x = -1.5) ───────────────────────────────────────────
      case 4:
        if (isHorizontal) {
          if (row == 0) return pick("U'", "U");
          if (row == 1) return pick("E",  "E'");
          if (row == 2) return pick("D",  "D'");
        } else {
          if (col == 0) return pick("B'", "B");
          if (col == 1) return pick("S",  "S'");
          if (col == 2) return pick("F",  "F'");
        }
        break;

      // ── Back face (B, z = -1.5) ───────────────────────────────────────────
      case 5:
        if (isHorizontal) {
          if (row == 0) return pick("U",  "U'");
          if (row == 1) return pick("E'", "E");
          if (row == 2) return pick("D'", "D");
        } else {
          if (col == 0) return pick("R'", "R");
          if (col == 1) return pick("M'", "M");
          if (col == 2) return pick("L",  "L'");
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
      onScaleStart: _onScaleStart,
      onScaleUpdate: _onScaleUpdate,
      onScaleEnd: _onScaleEnd,
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

  bool isCellInAnimLayer(double cx, double cy, double cz, String face) {
    switch (face) {
      case 'U': return cy > 0.5;
      case 'D': return cy < -0.5;
      case 'R': return cx > 0.5;
      case 'L': return cx < -0.5;
      case 'F': return cz > 0.5;
      case 'B': return cz < -0.5;
      case 'M': return cx.abs() <= 0.5;
      case 'E': return cy.abs() <= 0.5;
      case 'S': return cz.abs() <= 0.5;
      default: return false;
    }
  }

  _Vec3 rotateByFace(_Vec3 v, String face, double angle) {
    switch (face) {
      case 'U': return _rotateY(v, angle);
      case 'D': return _rotateY(v, -angle);
      case 'R': return _rotateX(v, -angle);
      case 'L': return _rotateX(v, angle);
      case 'F': return _rotateZ(v, -angle);
      case 'B': return _rotateZ(v, angle);
      case 'M': return _rotateX(v, angle);
      case 'E': return _rotateY(v, -angle);
      case 'S': return _rotateZ(v, -angle);
      default: return v;
    }
  }

  final bool cellRotates = animFace != null && animAngle != 0 && isCellInAnimLayer(cx, cy, cz, animFace);

  final rotNormal = cellRotates ? rotateByFace(normal, animFace, animAngle) : normal;
  final transformedNorm = _rotateX(_rotateY(rotNormal, yaw), pitch).normalized();

  if (transformedNorm.z <= 0.05) {
    return null;
  }

  // Light comes from upper-left-front; brightest on faces whose normals
  // face the light most directly.
  const lightDir = _Vec3(0.40, 0.70, 0.60);
  final diffuse = math.max(0.0, transformedNorm.dot(lightDir));
  final lighting = 0.72 + 0.28 * diffuse;

  final pts = <Offset>[];
  double totalDepth = 0;
  for (final c in localCorners) {
    final rotC = cellRotates ? rotateByFace(c, animFace, animAngle) : c;
    final v = _rotateX(_rotateY(rotC, yaw), pitch);
    totalDepth += v.z;
    final k = camDist / (camDist - v.z);
    final px = center.dx + v.x * k * scale;
    final py = center.dy - v.y * k * scale;
    pts.add(Offset(px, py));
  }

  final cellCenterVec = _Vec3(cx, cy, cz);
  final rotCenter = cellRotates ? rotateByFace(cellCenterVec, animFace, animAngle) : cellCenterVec;
  final rotU = cellRotates ? rotateByFace(cellCenterVec + uDir * 0.5, animFace, animAngle) : (cellCenterVec + uDir * 0.5);
  final rotV = cellRotates ? rotateByFace(cellCenterVec + vDir * 0.5, animFace, animAngle) : (cellCenterVec + vDir * 0.5);

  final centerTrans = _rotateX(_rotateY(rotCenter, yaw), pitch);
  final uTrans = _rotateX(_rotateY(rotU, yaw), pitch);
  final vTrans = _rotateX(_rotateY(rotV, yaw), pitch);

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

    // Painter's algorithm: far-to-near
    quads.sort((a, b) => a.depth.compareTo(b.depth));

    String? hlFace;
    if (highlightMove != null && highlightMove!.isNotEmpty) {
      hlFace = highlightMove![0].toUpperCase();
    }

    for (final q in quads) {
      _drawCubieCell(canvas, q, hlFace);
    }
  }

  /// Renders a single cubie face:
  ///   • dark plastic base tile (defines seams/grooves)
  ///   • dark rounded body (per-face lighting + radial pillow gradient)
  ///   • inset oval / rounded sticker
  ///   • subtle gloss sheen on the sticker
  void _drawCubieCell(Canvas canvas, _ProjectedQuad q, String? hlFace) {
    final pts = q.points;
    final lf = q.lighting; // 0.72 – 1.00

    // Approximate cell width in screen pixels (avg projected edge length)
    double totalEdge = 0;
    for (int i = 0; i < 4; i++) {
      totalEdge += (pts[(i + 1) % 4] - pts[i]).distance;
    }
    final cellPx = totalEdge / 4;

    // ── 1. Black plastic base tile (defines the dark seams/grooves around each cubie) ──
    final basePath = _roundedQuadPath(pts, cellPx * 0.10);
    canvas.drawPath(basePath, Paint()..color = const Color(0xFF0A0A0A));

    // ── 2. Groove gap between cubies (narrow so cells look tight/realistic) ──
    final bodyPts = _insetQuad(pts, cellPx * 0.045);
    final bodyPath = _roundedQuadPath(bodyPts, cellPx * 0.18);

    // ── 2. Cubie body: dark gray with a radial "pillow" gradient ─────────────
    final bodyCenter = Offset(
      (bodyPts[0].dx + bodyPts[1].dx + bodyPts[2].dx + bodyPts[3].dx) / 4,
      (bodyPts[0].dy + bodyPts[1].dy + bodyPts[2].dy + bodyPts[3].dy) / 4,
    );
    final bodyRadius = cellPx * 0.46;

    // Lighting: top face ~78, front ~65, side ~55 — always clearly above #0A0A0A
    // lf ranges 0.72-1.00; dark edge of gradient 48-78, highlight peak 80-110
    final darkVal  = (48 + (lf - 0.72) / 0.28 * 30).round().clamp(48, 78);
    final lightVal = (darkVal + 32).clamp(0, 120);

    canvas.drawPath(
      bodyPath,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.20, -0.30),
          radius: 1.20,
          colors: [
            Color.fromARGB(255, lightVal, lightVal, lightVal),
            Color.fromARGB(255, darkVal,  darkVal,  darkVal),
          ],
        ).createShader(
          Rect.fromCircle(center: bodyCenter, radius: bodyRadius),
        ),
    );

    // ── 3. Coloured sticker: inset oval (very round corners) ─────────────────
    final stickerPts = _insetQuad(bodyPts, cellPx * 0.16);
    final stickerPath = _stickerPath(stickerPts);

    final base = q.color.displayColor;
    // Keep stickers vivid; only mild darkening for less-lit faces
    final sf = 0.88 + 0.12 * lf;
    canvas.drawPath(
      stickerPath,
      Paint()
        ..color = Color.fromARGB(
          255,
          (base.r * 255 * sf).round().clamp(0, 255),
          (base.g * 255 * sf).round().clamp(0, 255),
          (base.b * 255 * sf).round().clamp(0, 255),
        )
        ..style = PaintingStyle.fill,
    );

    // Gloss sheen overlay (top-left brightspot)
    final scx = (stickerPts[0].dx + stickerPts[1].dx +
                 stickerPts[2].dx + stickerPts[3].dx) / 4;
    final scy = (stickerPts[0].dy + stickerPts[1].dy +
                 stickerPts[2].dy + stickerPts[3].dy) / 4;
    canvas.drawPath(
      stickerPath,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.15, -0.50),
          radius: 1.30,
          colors: [Color(0x55FFFFFF), Color(0x00FFFFFF)],
        ).createShader(
          Rect.fromCircle(center: Offset(scx, scy), radius: cellPx * 0.25),
        ),
    );

    // ── 4. Move-highlight outline ─────────────────────────────────────────────
    final faceLetter = ['U', 'R', 'F', 'D', 'L', 'B'][q.faceIndex];
    if (hlFace == faceLetter) {
      canvas.drawPath(
        bodyPath,
        Paint()
          ..color = const Color(0xFF00E676).withValues(alpha: 0.78)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6,
      );
    }
  }

  // ── Geometry helpers ────────────────────────────────────────────────────────

  /// Moves each corner of [pts] toward the quad's centre by [inset] pixels.
  static List<Offset> _insetQuad(List<Offset> pts, double inset) {
    final cx = (pts[0].dx + pts[1].dx + pts[2].dx + pts[3].dx) / 4;
    final cy = (pts[0].dy + pts[1].dy + pts[2].dy + pts[3].dy) / 4;
    return pts.map((p) {
      final dx = cx - p.dx;
      final dy = cy - p.dy;
      final len = math.sqrt(dx * dx + dy * dy);
      if (len < 1e-6) return p;
      final t = math.min(inset, len * 0.48);
      return Offset(p.dx + dx / len * t, p.dy + dy / len * t);
    }).toList();
  }

  /// Quad path with Bézier-rounded corners of radius [r].
  static Path _roundedQuadPath(List<Offset> pts, double r) {
    final path = Path();
    bool started = false;
    for (int i = 0; i < 4; i++) {
      final curr = pts[i];
      final prev = pts[(i + 3) % 4];
      final next = pts[(i + 1) % 4];
      final toPrev = Offset(prev.dx - curr.dx, prev.dy - curr.dy);
      final toNext = Offset(next.dx - curr.dx, next.dy - curr.dy);
      final lp = toPrev.distance;
      final ln = toNext.distance;
      if (lp < 1e-6 || ln < 1e-6) continue;
      final cr = math.min(r, math.min(lp, ln) * 0.45);
      final p1 = Offset(curr.dx + toPrev.dx / lp * cr,
                        curr.dy + toPrev.dy / lp * cr);
      final p2 = Offset(curr.dx + toNext.dx / ln * cr,
                        curr.dy + toNext.dy / ln * cr);
      if (!started) {
        path.moveTo(p1.dx, p1.dy);
        started = true;
      } else {
        path.lineTo(p1.dx, p1.dy);
      }
      path.quadraticBezierTo(curr.dx, curr.dy, p2.dx, p2.dy);
    }
    path.close();
    return path;
  }

  /// Very-rounded (≈ oval) sticker path inscribed in [pts].
  /// Corner radius ≈ 44% of the shortest projected edge → almost circular.
  static Path _stickerPath(List<Offset> pts) {
    double minEdge = double.infinity;
    for (int i = 0; i < 4; i++) {
      final d = (pts[(i + 1) % 4] - pts[i]).distance;
      if (d < minEdge) minEdge = d;
    }
    return _roundedQuadPath(pts, minEdge * 0.44);
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

