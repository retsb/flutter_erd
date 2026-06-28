import 'package:flutter/material.dart';
import 'package:diagram_editor/diagram_editor.dart';

import '../models.dart';
import 'types.dart';

/// Small overview map that shows an approximate layout of components.
///
/// The mini-map is intentionally lightweight: it scales the controller's
/// component rectangles down into a fixed-size card so the user can get an
/// orientation of the diagram. Interactivity (click-to-pan) can be added
/// later without changing the visual representation.
class MiniMap extends StatelessWidget {
  final DiagramController<TableModel, ERDLinkData> controller;

  const MiniMap({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final components = controller.components.values.toList();
    final width = 220.0;
    final height = 140.0;
    if (components.isEmpty) return SizedBox(width: width, height: height);

    final minX = components
        .map((c) => c.position.dx)
        .reduce((a, b) => a < b ? a : b);
    final minY = components
        .map((c) => c.position.dy)
        .reduce((a, b) => a < b ? a : b);
    final maxX = components
        .map((c) => c.position.dx + c.size.width)
        .reduce((a, b) => a > b ? a : b);
    final maxY = components
        .map((c) => c.position.dy + c.size.height)
        .reduce((a, b) => a > b ? a : b);

    final contentW = maxX - minX;
    final contentH = maxY - minY;
    final scaleX = contentW == 0 ? 1.0 : width / contentW;
    final scaleY = contentH == 0 ? 1.0 : height / contentH;
    final scale = scaleX < scaleY ? scaleX : scaleY;

    return Card(
      elevation: 6,
      child: SizedBox(
        width: width,
        height: height,
        child: Padding(
          padding: const EdgeInsets.all(6.0),
          child: Stack(
            children: components.map((c) {
              final x = (c.position.dx - minX) * scale;
              final y = (c.position.dy - minY) * scale;
              final w = c.size.width * scale;
              final h = c.size.height * scale;
              return Positioned(
                left: x,
                top: y,
                child: Container(
                  width: w,
                  height: h,
                  decoration: BoxDecoration(
                    color: Colors.blue.withAlpha((0.12 * 255).round()),
                    border: Border.all(
                      color: Colors.blueAccent.withAlpha((0.6 * 255).round()),
                      width: 0.5,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
