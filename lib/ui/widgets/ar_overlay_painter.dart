import 'package:flutter/material.dart';

class ArOverlayPainter extends CustomPainter {
  final List<Offset> corners;
  final bool isDetected;
  final String? currentMove;
  final String? visualHint;

  ArOverlayPainter({
    required this.corners,
    required this.isDetected,
    this.currentMove,
    this.visualHint,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (!isDetected || corners.length < 4) return;

    final borderPaint = Paint()
      ..color = const Color(0xFF00E676)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;

    final fillPaint = Paint()
      ..color = const Color(0xFF00E676).withOpacity(0.12)
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(corners[0].dx, corners[0].dy)
      ..lineTo(corners[1].dx, corners[1].dy)
      ..lineTo(corners[2].dx, corners[2].dy)
      ..lineTo(corners[3].dx, corners[3].dy)
      ..close();

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, borderPaint);

    for (int i = 1; i <= 2; i++) {
      double t = i / 3.0;
      Offset pL = Offset.lerp(corners[0], corners[3], t)!;
      Offset pR = Offset.lerp(corners[1], corners[2], t)!;
      canvas.drawLine(pL, pR, Paint()..color = Colors.white24..strokeWidth = 1.5);

      Offset pT = Offset.lerp(corners[0], corners[1], t)!;
      Offset pB = Offset.lerp(corners[3], corners[2], t)!;
      canvas.drawLine(pT, pB, Paint()..color = Colors.white24..strokeWidth = 1.5);
    }
  }

  @override
  bool shouldRepaint(covariant ArOverlayPainter oldDelegate) {
    return oldDelegate.corners != corners ||
        oldDelegate.isDetected != isDetected ||
        oldDelegate.currentMove != currentMove;
  }
}
