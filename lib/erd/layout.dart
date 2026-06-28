import 'package:flutter/material.dart';

import '../models.dart';

/// Simple holder for table geometry used by the ERD layout logic.
///
/// `TableLayout` pairs a `TableModel` with a position and a size so the
/// diagram builder can add components to the controller with precomputed
/// frames.
class TableLayout {
  /// The model that the layout entry represents.
  final TableModel table;

  /// Top-left position for the table on the canvas.
  final Offset position;

  /// Size (width/height) for the table component.
  final Size size;

  TableLayout({
    required this.table,
    required this.position,
    required this.size,
  });
}
