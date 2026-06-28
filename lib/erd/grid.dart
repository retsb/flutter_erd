import 'package:flutter/material.dart';

/// A reusable grid background for the ERD canvas.
///
/// `GridBackground` paints a regular grid using [GridPainter]. It's small and
/// stateless so it can be toggled on/off cheaply by the parent widget.
class GridBackground extends StatelessWidget {
  const GridBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return const CustomPaint(painter: GridPainter(), size: Size.infinite);
  }
}

/// Paints the faint grid lines used behind the canvas to aid alignment.
///
/// The painter is intentionally simple and returns `false` from
/// [shouldRepaint] because the grid appearance is constant.
class GridPainter extends CustomPainter {
  final double step = 24.0;

  const GridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.withAlpha(40)
      ..strokeWidth = 0.5;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
