import 'dart:async';
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
  State<InteractiveCube3D> createState() => InteractiveCube3DState();
}

class InteractiveCube3DState extends State<InteractiveCube3D>
    with SingleTickerProviderStateMixin {
  // Camera view angles
  double _yaw = 0.65; // ~37 degrees
  double _pitch = -0.45; // ~-26 degrees

  // Animation controller for face turns & snapping
  late AnimationController _turnController;
  late Animation<double> _turnAnimation;
  Completer<void>? _currentMoveCompleter;

  // Active layer turn/snap state
  String? _animatingFace; // e.g. 'U', 'R', 'M', etc.
  double _snapStartAngle = 0.0;
  double _snapTargetAngle = 0.0;
  String? _pendingMoveOnComplete;
  CubeState? _preAnimState;

  // Touch tracking for real-time layer drag
  Offset? _panStartPos;
  _HitTestResult? _panHit;
  bool _isCameraRotating = false;
  _ActiveLayerDrag? _activeDrag;
  double _dragAngle = 0.0;

  @override
  void initState() {
    super.initState();
    _turnController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _turnAnimation = CurvedAnimation(
      parent: _turnController,
      curve: Curves.easeOutCubic,
    );
    _turnController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        final move = _pendingMoveOnComplete;
        setState(() {
          _animatingFace = null;
          _dragAngle = 0.0;
          _snapStartAngle = 0.0;
          _snapTargetAngle = 0.0;
          _pendingMoveOnComplete = null;
          _preAnimState = null;
        });
        if (move != null) {
          widget.onMoveApplied?.call(move);
          HapticFeedback.lightImpact();
        } else {
          // Snap back feedback
          HapticFeedback.selectionClick();
        }
        if (_currentMoveCompleter != null && !_currentMoveCompleter!.isCompleted) {
          _currentMoveCompleter!.complete();
        }
      }
    });
  }

  @override
  void didUpdateWidget(InteractiveCube3D oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state && !_turnController.isAnimating && _activeDrag == null) {
      _preAnimState = null;
    }
  }

  @override
  void dispose() {
    if (_currentMoveCompleter != null && !_currentMoveCompleter!.isCompleted) {
      _currentMoveCompleter!.complete();
    }
    _turnController.dispose();
    super.dispose();
  }

  void _resetView() {
    setState(() {
      _yaw = 0.65;
      _pitch = -0.45;
    });
  }

  /// Triggers an animated face turn from code (e.g. "R", "U'", "F2").
  void animateMove(String move) {
    animateMoveAsync(move);
  }

  /// Asynchronously animates a single move and returns a [Future] that completes
  /// when the turn animation finishes and state is applied.
  Future<void> animateMoveAsync(String move, {Duration duration = const Duration(milliseconds: 220)}) {
    if (_turnController.isAnimating || _activeDrag != null) {
      return Future.value();
    }

    final m = move.trim();
    if (m.isEmpty) return Future.value();

    int turns = 1;
    if (m.contains('2')) {
      turns = 2;
    } else if (m.contains("'") || m.contains('3')) {
      turns = -1;
    }

    final face = m[0].toUpperCase();
    _currentMoveCompleter = Completer<void>();

    setState(() {
      _animatingFace = face;
      _preAnimState = widget.state;
      _snapStartAngle = 0.0;
      _snapTargetAngle = turns * (math.pi / 2);
      _pendingMoveOnComplete = move;
    });

    _turnController.duration = duration;
    CubeSoundService.instance.playGearTurn();
    _turnController.forward(from: 0.0);

    return _currentMoveCompleter!.future;
  }

  /// Asynchronously animates a sequence of moves one after another.
  Future<void> animateMoves(
    List<String> moves, {
    Duration perMoveDuration = const Duration(milliseconds: 220),
    Duration pauseBetweenMoves = const Duration(milliseconds: 50),
  }) async {
    for (final m in moves) {
      if (!mounted) break;
      await animateMoveAsync(m, duration: perMoveDuration);
      if (pauseBetweenMoves > Duration.zero) {
        await Future.delayed(pauseBetweenMoves);
      }
    }
  }

  void _cancelLayerDrag() {
    if (_activeDrag != null || _dragAngle != 0.0) {
      setState(() {
        _activeDrag = null;
        _dragAngle = 0.0;
        _animatingFace = null;
        _preAnimState = null;
      });
    }
  }

  void _snapToAngle({
    required double fromAngle,
    required double toAngle,
    required String? moveOnComplete,
  }) {
    _snapStartAngle = fromAngle;
    _snapTargetAngle = toAngle;
    _pendingMoveOnComplete = moveOnComplete;

    final distance = (toAngle - fromAngle).abs();
    final durationMs = (200 * (distance / (math.pi / 2))).clamp(90, 240).toInt();

    if (moveOnComplete != null) {
      CubeSoundService.instance.playGearTurn();
    }

    _turnController.duration = Duration(milliseconds: durationMs);
    _turnController.forward(from: 0.0);
  }

  Offset _computeScreenTangent(int faceIndex, int row, int col, String layer) {
    final center3d = _getStickerCenter(faceIndex, row, col);
    const dTheta = 0.05;
    final rot3d = _rotateByFace(center3d, layer, dTheta);

    final center = Offset(widget.size / 2, widget.size / 2);
    final scale = widget.size / 5.2;
    const camDist = 5.5;

    final p0 = _projectPoint(center3d, _yaw, _pitch, center, scale, camDist);
    final pRot = _projectPoint(rot3d, _yaw, _pitch, center, scale, camDist);

    return (pRot - p0) * (1.0 / dTheta);
  }

  _ActiveLayerDrag? _initLayerDrag(_HitTestResult hit, Offset delta) {
    final faceIndex = hit.faceIndex;
    final row = hit.row;
    final col = hit.col;

    final (rowLayer, colLayer) = _getCandidateLayers(faceIndex, row, col);

    final tRow = _computeScreenTangent(faceIndex, row, col, rowLayer);
    final tCol = _computeScreenTangent(faceIndex, row, col, colLayer);

    final lenRow = tRow.distance;
    final lenCol = tCol.distance;

    if (lenRow < 1e-4 && lenCol < 1e-4) return null;

    final projRow = lenRow > 1e-4
        ? (delta.dx * tRow.dx + delta.dy * tRow.dy).abs() / lenRow
        : 0.0;
    final projCol = lenCol > 1e-4
        ? (delta.dx * tCol.dx + delta.dy * tCol.dy).abs() / lenCol
        : 0.0;

    if (projRow >= projCol) {
      return _ActiveLayerDrag(
        faceIndex: faceIndex,
        row: row,
        col: col,
        layer: rowLayer,
        screenTangent: tRow,
      );
    } else {
      return _ActiveLayerDrag(
        faceIndex: faceIndex,
        row: row,
        col: col,
        layer: colLayer,
        screenTangent: tCol,
      );
    }
  }

  void _onScaleStart(ScaleStartDetails details) {
    if (!widget.interactive) return;

    // Dual-finger drag: rotate whole cube (camera)
    if (details.pointerCount >= 2) {
      _isCameraRotating = true;
      _cancelLayerDrag();
      return;
    }

    _panStartPos = details.localFocalPoint;
    _isCameraRotating = false;
    _activeDrag = null;
    _dragAngle = 0.0;

    if (widget.allowFaceTurns && !_turnController.isAnimating) {
      _panHit = _hitTest(details.localFocalPoint);
      if (_panHit == null) {
        _isCameraRotating = true;
      }
    } else {
      _panHit = null;
      _isCameraRotating = true;
    }
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (!widget.interactive) return;

    // Dual fingers: ALWAYS rotate entire cube (camera)
    if (details.pointerCount >= 2) {
      if (_activeDrag != null) {
        _cancelLayerDrag();
      }
      _isCameraRotating = true;
      setState(() {
        _yaw += details.focalPointDelta.dx * 0.012;
        _pitch = (_pitch + details.focalPointDelta.dy * 0.012).clamp(-1.35, 1.35);
      });
      return;
    }

    // Single finger in camera rotation mode
    if (_isCameraRotating || _panHit == null) {
      setState(() {
        _yaw += details.focalPointDelta.dx * 0.012;
        _pitch = (_pitch + details.focalPointDelta.dy * 0.012).clamp(-1.35, 1.35);
      });
      return;
    }

    // Single finger on cube facet:
    final delta = details.localFocalPoint - _panStartPos!;

    if (_activeDrag == null) {
      if (delta.distance > 8.0) {
        final drag = _initLayerDrag(_panHit!, delta);
        if (drag == null) {
          _isCameraRotating = true;
          return;
        }
        _activeDrag = drag;
        _preAnimState = widget.state;
      } else {
        return;
      }
    }

    if (_activeDrag != null) {
      final drag = _activeDrag!;
      // Projection of swipe onto screen tangent vector
      final rawAngle = (delta.dx * drag.screenTangent.dx + delta.dy * drag.screenTangent.dy) / drag.tNormSq;
      final clampedAngle = rawAngle.clamp(-1.83, 1.83);

      setState(() {
        _dragAngle = clampedAngle;
        _animatingFace = drag.layer;
      });
    }
  }

  void _onScaleEnd(ScaleEndDetails details) {
    if (!widget.interactive) return;

    if (_activeDrag != null) {
      final drag = _activeDrag!;
      final currentAngle = _dragAngle;
      _activeDrag = null;

      // Project release velocity onto tangent direction
      final vel = details.velocity.pixelsPerSecond;
      final tangentLen = math.sqrt(drag.tNormSq);
      final velProj = (vel.dx * drag.screenTangent.dx + vel.dy * drag.screenTangent.dy) / tangentLen;

      // Threshold: ~35% of a full 90-degree turn (~31.5 degrees)
      const thresholdAngle = 0.35 * (math.pi / 2);

      int targetDirection = 0;
      if (velProj.abs() > 320) {
        // High-velocity flick
        targetDirection = velProj > 0 ? 1 : -1;
      } else if (currentAngle.abs() >= thresholdAngle) {
        targetDirection = currentAngle > 0 ? 1 : -1;
      } else {
        // Slid only a little bit -> snap back to original position (0.0 rad)!
        targetDirection = 0;
      }

      if (targetDirection == 0) {
        // Snap back to 0.0 (return to original position)
        _snapToAngle(fromAngle: currentAngle, toAngle: 0.0, moveOnComplete: null);
      } else {
        final targetAngle = targetDirection * (math.pi / 2);
        final moveName = targetDirection > 0 ? drag.layer : "${drag.layer}'";
        _snapToAngle(fromAngle: currentAngle, toAngle: targetAngle, moveOnComplete: moveName);
      }

      _panStartPos = null;
      _panHit = null;
      _isCameraRotating = false;
      return;
    }

    // Tap detection (minimal movement)
    if (!_isCameraRotating && _panHit != null && _panStartPos != null) {
      if (widget.onFacetTap != null) {
        widget.onFacetTap!(_panHit!.facetIndex);
        HapticFeedback.selectionClick();
      }
    }

    _panStartPos = null;
    _panHit = null;
    _isCameraRotating = false;
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

    final activeState = _preAnimState ?? widget.state;
    final quads = <_ProjectedQuad>[];

    for (var f = 0; f < 6; f++) {
      for (var r = 0; r < 3; r++) {
        for (var c = 0; c < 3; c++) {
          final quad = _buildStickerQuad(
            f, r, c,
            animFace: null,
            animAngle: 0,
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
          final renderedAngle = _turnController.isAnimating
              ? _snapStartAngle + (_snapTargetAngle - _snapStartAngle) * _turnAnimation.value
              : (_activeDrag != null ? _dragAngle : 0.0);

          return CustomPaint(
            size: Size(widget.size, widget.size),
            painter: _Cube3DPainter(
              state: _preAnimState ?? widget.state,
              yaw: _yaw,
              pitch: _pitch,
              animFace: _animatingFace,
              animAngle: renderedAngle,
              highlightMove: widget.highlightMove,
            ),
          );
        },
      ),
    );
  }
}

class _ActiveLayerDrag {
  final int faceIndex;
  final int row;
  final int col;
  final String layer;
  final Offset screenTangent;
  final double tNormSq;

  _ActiveLayerDrag({
    required this.faceIndex,
    required this.row,
    required this.col,
    required this.layer,
    required this.screenTangent,
  }) : tNormSq = math.max(1.0, screenTangent.dx * screenTangent.dx + screenTangent.dy * screenTangent.dy);
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

/// Rotates a 3D point according to Rubik's cube layer/slice convention.
///
/// Positive angle corresponds exactly to the canonical clockwise move
/// in [CubeState.applyMove].
_Vec3 _rotateByFace(_Vec3 v, String face, double angle) {
  switch (face) {
    case 'U': return _rotateY(v, -angle);
    case 'D': return _rotateY(v, angle);
    case 'R': return _rotateX(v, -angle);
    case 'L': return _rotateX(v, angle);
    case 'F': return _rotateZ(v, -angle);
    case 'B': return _rotateZ(v, angle);
    case 'M': return _rotateX(v, angle);
    case 'E': return _rotateY(v, angle);
    case 'S': return _rotateZ(v, -angle);
    default: return v;
  }
}

bool _isCellInAnimLayer(double cx, double cy, double cz, String face) {
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

_Vec3 _getStickerCenter(int faceIndex, int row, int col) {
  double cx = 0, cy = 0, cz = 0;
  switch (faceIndex) {
    case 0: // U (Up, y = 1.5)
      cx = (col - 1).toDouble();
      cy = 1.5;
      cz = (row - 1).toDouble();
      break;
    case 1: // R (Right, x = 1.5)
      cx = 1.5;
      cy = (1 - row).toDouble();
      cz = (1 - col).toDouble();
      break;
    case 2: // F (Front, z = 1.5)
      cx = (col - 1).toDouble();
      cy = (1 - row).toDouble();
      cz = 1.5;
      break;
    case 3: // D (Down, y = -1.5)
      cx = (col - 1).toDouble();
      cy = -1.5;
      cz = (1 - row).toDouble();
      break;
    case 4: // L (Left, x = -1.5)
      cx = -1.5;
      cy = (1 - row).toDouble();
      cz = (col - 1).toDouble();
      break;
    case 5: // B (Back, z = -1.5)
      cx = (1 - col).toDouble();
      cy = (1 - row).toDouble();
      cz = -1.5;
      break;
  }
  return _Vec3(cx, cy, cz);
}

(String, String) _getCandidateLayers(int faceIndex, int row, int col) {
  switch (faceIndex) {
    case 0: // U face
      final rowLayer = (row == 0) ? 'B' : (row == 1 ? 'S' : 'F');
      final colLayer = (col == 0) ? 'L' : (col == 1 ? 'M' : 'R');
      return (rowLayer, colLayer);
    case 1: // R face
      final rowLayer = (row == 0) ? 'U' : (row == 1 ? 'E' : 'D');
      final colLayer = (col == 0) ? 'F' : (col == 1 ? 'S' : 'B');
      return (rowLayer, colLayer);
    case 2: // F face
      final rowLayer = (row == 0) ? 'U' : (row == 1 ? 'E' : 'D');
      final colLayer = (col == 0) ? 'L' : (col == 1 ? 'M' : 'R');
      return (rowLayer, colLayer);
    case 3: // D face
      final rowLayer = (row == 0) ? 'F' : (row == 1 ? 'S' : 'B');
      final colLayer = (col == 0) ? 'L' : (col == 1 ? 'M' : 'R');
      return (rowLayer, colLayer);
    case 4: // L face
      final rowLayer = (row == 0) ? 'U' : (row == 1 ? 'E' : 'D');
      final colLayer = (col == 0) ? 'B' : (col == 1 ? 'S' : 'F');
      return (rowLayer, colLayer);
    case 5: // B face
      final rowLayer = (row == 0) ? 'U' : (row == 1 ? 'E' : 'D');
      final colLayer = (col == 0) ? 'R' : (col == 1 ? 'M' : 'L');
      return (rowLayer, colLayer);
    default:
      return ('U', 'R');
  }
}

Offset _projectPoint(
  _Vec3 v,
  double yaw,
  double pitch,
  Offset center,
  double scale,
  double camDist,
) {
  final trans = _rotateX(_rotateY(v, yaw), pitch);
  final k = camDist / (camDist - trans.z);
  return Offset(
    center.dx + trans.x * k * scale,
    center.dy - trans.y * k * scale,
  );
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

  final bool cellRotates = animFace != null && animAngle != 0 && _isCellInAnimLayer(cx, cy, cz, animFace);

  final rotNormal = cellRotates ? _rotateByFace(normal, animFace, animAngle) : normal;
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
    final rotC = cellRotates ? _rotateByFace(c, animFace, animAngle) : c;
    final v = _rotateX(_rotateY(rotC, yaw), pitch);
    totalDepth += v.z;
    final k = camDist / (camDist - v.z);
    final px = center.dx + v.x * k * scale;
    final py = center.dy - v.y * k * scale;
    pts.add(Offset(px, py));
  }

  final cellCenterVec = _Vec3(cx, cy, cz);
  final rotCenter = cellRotates ? _rotateByFace(cellCenterVec, animFace, animAngle) : cellCenterVec;
  final rotU = cellRotates ? _rotateByFace(cellCenterVec + uDir * 0.5, animFace, animAngle) : (cellCenterVec + uDir * 0.5);
  final rotV = cellRotates ? _rotateByFace(cellCenterVec + vDir * 0.5, animFace, animAngle) : (cellCenterVec + vDir * 0.5);

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

  /// Computes the 4 individual corner radii [r0, r1, r2, r3] for a cubie facet at (row, col).
  ///
  /// Corner indexing in quad points:
  ///   0: top-left (-u, -v)
  ///   1: top-right (+u, -v)
  ///   2: bottom-right (+u, +v)
  ///   3: bottom-left (-u, +v)
  ///
  /// Distinct geometry:
  ///   • Center (1,1): all 4 corners have large rounding (squircle pillow cap).
  ///   • Edge (0,1; 1,0; 1,2; 2,1): inner 2 corners facing center have large rounding;
  ///     outer 2 corners have small crisp rounding.
  ///   • Corner (0,0; 0,2; 2,0; 2,2): outer cube tip and inner center-facing corner
  ///     have medium rounding; side seams have small crisp rounding.
  static List<double> _getCornerRadii(int row, int col, double cellPx) {
    final rLarge = cellPx * 0.28;  // Large round for center piece & inner edge corners
    final rMedium = cellPx * 0.18; // Medium round for outer cube corner & inner corner corner
    final rSmall = cellPx * 0.065; // Small crisp round for outer borders & straight seams

    // ── 1. Center piece (1, 1) ────────────────────────────────────────────────
    if (row == 1 && col == 1) {
      return [rLarge, rLarge, rLarge, rLarge];
    }

    // ── 2. Edge pieces ────────────────────────────────────────────────────────
    // Top edge (0, 1): corners 2 & 3 face the center (+v direction)
    if (row == 0 && col == 1) {
      return [rSmall, rSmall, rLarge, rLarge];
    }
    // Bottom edge (2, 1): corners 0 & 1 face the center (-v direction)
    if (row == 2 && col == 1) {
      return [rLarge, rLarge, rSmall, rSmall];
    }
    // Left edge (1, 0): corners 1 & 2 face the center (+u direction)
    if (row == 1 && col == 0) {
      return [rSmall, rLarge, rLarge, rSmall];
    }
    // Right edge (1, 2): corners 0 & 3 face the center (-u direction)
    if (row == 1 && col == 2) {
      return [rLarge, rSmall, rSmall, rLarge];
    }

    // ── 3. Corner pieces ──────────────────────────────────────────────────────
    // Top-left corner (0, 0):
    //   0: outer cube tip (medium)
    //   1: top seam (small)
    //   2: inner corner pointing to center (medium)
    //   3: left seam (small)
    if (row == 0 && col == 0) {
      return [rMedium, rSmall, rMedium, rSmall];
    }
    // Top-right corner (0, 2):
    //   0: top seam (small)
    //   1: outer cube tip (medium)
    //   2: right seam (small)
    //   3: inner corner pointing to center (medium)
    if (row == 0 && col == 2) {
      return [rSmall, rMedium, rSmall, rMedium];
    }
    // Bottom-right corner (2, 2):
    //   0: inner corner pointing to center (medium)
    //   1: right seam (small)
    //   2: outer cube tip (medium)
    //   3: bottom seam (small)
    if (row == 2 && col == 2) {
      return [rMedium, rSmall, rMedium, rSmall];
    }
    // Bottom-left corner (2, 0):
    //   0: left seam (small)
    //   1: inner corner pointing to center (medium)
    //   2: bottom seam (small)
    //   3: outer cube tip (medium)
    if (row == 2 && col == 0) {
      return [rSmall, rMedium, rSmall, rMedium];
    }

    return [rSmall, rSmall, rSmall, rSmall];
  }

  /// Quad path with per-corner Bézier-rounded corners of radii [radii = [r0, r1, r2, r3]].
  static Path _roundedQuadPathWithRadii(List<Offset> pts, List<double> radii) {
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
      final r = radii[i];
      final cr = math.min(r, math.min(lp, ln) * 0.48);
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

  /// Renders a single cubie face:
  ///   • dark plastic base tile (defines seams/grooves)
  ///   • full-coverage colored tile with differentiated corner roundings (center, edge, corner)
  ///   • subtle 3D lighting + convex pillow shading
  ///   • soft gloss sheen
  ///   • center logo badge for the white center piece (MoYu style)
  void _drawCubieCell(Canvas canvas, _ProjectedQuad q, String? hlFace) {
    final pts = q.points;
    final lf = q.lighting; // 0.72 – 1.00

    // Approximate cell width in screen pixels (avg projected edge length)
    double totalEdge = 0;
    for (int i = 0; i < 4; i++) {
      totalEdge += (pts[(i + 1) % 4] - pts[i]).distance;
    }
    final cellPx = totalEdge / 4;

    final radii = _getCornerRadii(q.row, q.col, cellPx);

    // ── 1. Black plastic base tile (defines the dark seams/grooves around each cubie) ──
    final baseRadii = radii.map((r) => r + cellPx * 0.015).toList();
    final basePath = _roundedQuadPathWithRadii(pts, baseRadii);
    canvas.drawPath(basePath, Paint()..color = const Color(0xFF0C0C0C));

    // ── 2. Full-coverage colored tile with distinct corner roundings ──────────
    final tilePts = _insetQuad(pts, cellPx * 0.038);
    final tileRadii = radii.map((r) => math.max(0.0, r - cellPx * 0.015)).toList();
    final tilePath = _roundedQuadPathWithRadii(tilePts, tileRadii);

    final tileCenter = Offset(
      (tilePts[0].dx + tilePts[1].dx + tilePts[2].dx + tilePts[3].dx) / 4,
      (tilePts[0].dy + tilePts[1].dy + tilePts[2].dy + tilePts[3].dy) / 4,
    );

    final base = q.color.displayColor;
    final sf = 0.88 + 0.12 * lf;
    final colR = (base.r * 255 * sf).round().clamp(0, 255);
    final colG = (base.g * 255 * sf).round().clamp(0, 255);
    final colB = (base.b * 255 * sf).round().clamp(0, 255);
    final tileColor = Color.fromARGB(255, colR, colG, colB);

    // Subtle 3D convex shading gradient (pillow feel matching speedcube reference)
    final highlightCol = Color.fromARGB(
      255,
      math.min(255, colR + (36 * lf).round()),
      math.min(255, colG + (36 * lf).round()),
      math.min(255, colB + (36 * lf).round()),
    );
    final shadowCol = Color.fromARGB(
      255,
      math.max(0, colR - (26 * (1.1 - lf)).round()),
      math.max(0, colG - (26 * (1.1 - lf)).round()),
      math.max(0, colB - (26 * (1.1 - lf)).round()),
    );

    canvas.drawPath(
      tilePath,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.25, -0.35),
          radius: 1.25,
          colors: [highlightCol, tileColor, shadowCol],
          stops: const [0.0, 0.65, 1.0],
        ).createShader(
          Rect.fromCircle(center: tileCenter, radius: cellPx * 0.55),
        ),
    );

    // Subtle gloss sheen
    canvas.drawPath(
      tilePath,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.25, -0.45),
          radius: 1.10,
          colors: [Color(0x32FFFFFF), Color(0x00FFFFFF)],
        ).createShader(
          Rect.fromCircle(center: tileCenter, radius: cellPx * 0.40),
        ),
    );

    // If center piece on the white face: draw stylized "魔方教室" center emblem
    if (q.color == CubeColor.white && q.row == 1 && q.col == 1) {
      _drawCenterLogoBadge(canvas, tileCenter, cellPx * 0.44);
    }

    // ── 3. Move-highlight outline ─────────────────────────────────────────────
    final faceLetter = ['U', 'R', 'F', 'D', 'L', 'B'][q.faceIndex];
    if (hlFace == faceLetter) {
      canvas.drawPath(
        tilePath,
        Paint()
          ..color = const Color(0xFF00E676).withValues(alpha: 0.85)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.8,
      );
    }
  }

  /// Draws a professional speedcube center emblem (MoYu style) on the white center cap.
  static void _drawCenterLogoBadge(Canvas canvas, Offset center, double size) {
    final badgeW = size * 0.72;
    final badgeH = size * 0.72;
    final badgeRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: badgeW, height: badgeH),
      Radius.circular(size * 0.14),
    );

    // Badge background and border
    canvas.drawRRect(badgeRect, Paint()..color = Colors.white);
    canvas.drawRRect(
      badgeRect,
      Paint()
        ..color = const Color(0xFF1E1E1E)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    // Top block: blue "魔方"
    final topRect = Rect.fromCenter(
      center: Offset(center.dx, center.dy - badgeH * 0.22),
      width: badgeW * 0.80,
      height: badgeH * 0.36,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(topRect, const Radius.circular(2)),
      Paint()..color = const Color(0xFF0288D1),
    );

    // Bottom block: red "教室"
    final botRect = Rect.fromCenter(
      center: Offset(center.dx, center.dy + badgeH * 0.18),
      width: badgeW * 0.80,
      height: badgeH * 0.36,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(botRect, const Radius.circular(2)),
      Paint()..color = const Color(0xFFD32F2F),
    );

    // Text: "魔方"
    final tp1 = TextPainter(
      text: const TextSpan(
        text: '魔方',
        style: TextStyle(
          color: Colors.white,
          fontSize: 7.5,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp1.paint(canvas, Offset(center.dx - tp1.width / 2, center.dy - badgeH * 0.22 - tp1.height / 2));

    // Text: "教室"
    final tp2 = TextPainter(
      text: const TextSpan(
        text: '教室',
        style: TextStyle(
          color: Colors.white,
          fontSize: 7.5,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp2.paint(canvas, Offset(center.dx - tp2.width / 2, center.dy + badgeH * 0.18 - tp2.height / 2));
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

  @override
  bool shouldRepaint(covariant _Cube3DPainter old) {
    return old.state != state ||
        old.yaw != yaw ||
        old.pitch != pitch ||
        old.animAngle != animAngle ||
        old.highlightMove != highlightMove;
  }
}

