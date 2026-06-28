import 'package:diagram_editor/diagram_editor.dart';
import 'package:flutter/material.dart';

import 'models.dart';
import 'table_card.dart';
import 'table_editor.dart';

import 'erd/types.dart';
import 'erd/minimap.dart';
import 'erd/grid.dart';
import 'erd/layout.dart';

// ERDLinkData is defined in lib/erd/types.dart

/// The top-level ERD diagram widget.
///
/// `ERDDiagram` wires the diagram controller to the UI, builds components
/// from a `SchemaModel` and provides the canvas, controls, grid and mini-map.
/// It intentionally keeps high-level orchestration logic here while
/// delegating rendering helpers to `lib/erd/` modules.
class ERDDiagram extends StatefulWidget {
  final SchemaModel schema;
  final void Function(String tableName)? onRemoveTable;

  const ERDDiagram({super.key, required this.schema, this.onRemoveTable});

  @override
  State<ERDDiagram> createState() => _ERDDiagramState();
}

class _ERDDiagramState extends State<ERDDiagram> {
  final tableSpacing = const Size(320, 260);
  late DiagramController<TableModel, ERDLinkData> controller;
  String? selectedComponentId;
  late Offset _lastFocalPoint;
  late List<TableLayout> tableBoxes;
  bool _showGrid = false;
  bool _showMiniMap = false;

  @override
  void initState() {
    super.initState();
    _initController();
    _loadSchemaIntoController();
  }

  @override
  void didUpdateWidget(covariant ERDDiagram oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.schema != widget.schema) {
      setState(() {
        selectedComponentId = null;
        _loadSchemaIntoController();
      });
    }
  }

  void _initController() {
    controller = DiagramController<TableModel, ERDLinkData>(
      canvasConfig: CanvasConfig(backgroundColor: Colors.grey.shade100),
    );
  }

  void _loadSchemaIntoController() {
    controller.removeAllLinks();
    controller.removeAllComponents();
    tableBoxes = _buildTableBoxes();

    for (final layout in tableBoxes) {
      controller.addComponent(
        ComponentData<TableModel>(
          id: layout.table.tableName,
          position: layout.position,
          size: layout.size,
          data: layout.table,
        ),
      );
    }

    _buildLinksFromSchema();
  }

  List<TableLayout> _buildTableBoxes() {
    final result = <TableLayout>[];
    for (var index = 0; index < widget.schema.tables.length; index++) {
      final row = index ~/ 3;
      final column = index % 3;
      final x = column * tableSpacing.width + 16;
      final y = row * tableSpacing.height + 16;
      final table = widget.schema.tables[index];
      final extraDescriptionHeight = table.description != null ? 40.0 : 0.0;
      final height = 120 + extraDescriptionHeight + table.columns.length * 38.0;
      result.add(
        TableLayout(
          table: table,
          position: Offset(x, y),
          size: Size(300, height),
        ),
      );
    }
    return result;
  }

  void _buildLinksFromSchema() {
    final tableIds = controller.components.keys.toSet();
    for (final table in widget.schema.tables) {
      for (final column in table.columns) {
        final fk = column.foreignKey;
        if (fk == null) continue;
        if (!tableIds.contains(table.tableName) ||
            !tableIds.contains(fk.referenceTable)) {
          continue;
        }

        controller.connect(
          sourceComponentId: table.tableName,
          targetComponentId: fk.referenceTable,
          linkStyle: const LinkStyle(
            arrowType: ArrowType.pointedArrow,
            lineWidth: 1.8,
          ),
          data: ERDLinkData(
            columnName: column.columnName,
            referenceColumns: fk.referenceColumns,
          ),
        );
      }
    }
  }

  TableModel? get _selectedTable {
    if (selectedComponentId == null) return null;
    if (!controller.componentExists(selectedComponentId!)) return null;
    return controller.getComponent(selectedComponentId!).data;
  }

  void _zoomIn() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Zoom in not supported programmatically. Use mouse wheel or touchpad.',
        ),
      ),
    );
  }

  void _zoomOut() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Zoom out not supported programmatically. Use mouse wheel or touchpad.',
        ),
      ),
    );
  }

  void _fitToScreen() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Fit-to-screen not supported programmatically. Use zoom/pan controls.',
        ),
      ),
    );
  }

  void _updateCurrentComponent() {
    if (selectedComponentId != null) {
      controller.updateComponent(selectedComponentId!);
    }
    setState(() {});
  }

  void _clearSelection() {
    setState(() {
      selectedComponentId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border.all(color: Colors.deepPurple.shade200, width: 2),
            ),
            child: Stack(
              children: [
                DiagramEditor<TableModel, ERDLinkData>(
                  controller: controller,
                  componentBuilder: (context, component) {
                    return SizedBox(
                      width: component.size.width,
                      height: component.size.height,
                      child: TableCard(
                        table: component.data!,
                        width: component.size.width,
                        selected: component.id == selectedComponentId,
                      ),
                    );
                  },
                  backgroundBuilder: (context) => [
                    if (_showGrid) const GridBackground(),
                    Container(color: Colors.grey.shade100),
                  ],
                  onCanvasTap: _clearSelection,
                  onComponentTap: (id) {
                    setState(() {
                      selectedComponentId = selectedComponentId == id
                          ? null
                          : id;
                    });
                  },
                  onComponentScaleStart: (id, details) {
                    _lastFocalPoint = details.localFocalPoint;
                  },
                  onComponentScaleUpdate: (id, details) {
                    controller.moveComponent(
                      id,
                      details.localFocalPoint - _lastFocalPoint,
                    );
                    _lastFocalPoint = details.localFocalPoint;
                  },
                  linksOnTop: false,
                  enableDefaultPanZoom: true,
                ),

                // Controls overlay
                Positioned(
                  top: 8,
                  right: 8,
                  child: Card(
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 4,
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.zoom_in),
                            tooltip: 'Zoom in',
                            onPressed: _zoomIn,
                          ),
                          IconButton(
                            icon: const Icon(Icons.zoom_out),
                            tooltip: 'Zoom out',
                            onPressed: _zoomOut,
                          ),
                          IconButton(
                            icon: const Icon(Icons.fit_screen),
                            tooltip: 'Fit to screen',
                            onPressed: _fitToScreen,
                          ),
                          IconButton(
                            icon: Icon(
                              _showGrid ? Icons.grid_on : Icons.grid_off,
                            ),
                            tooltip: 'Toggle grid',
                            onPressed: () =>
                                setState(() => _showGrid = !_showGrid),
                          ),
                          IconButton(
                            icon: Icon(
                              _showMiniMap ? Icons.map : Icons.map_outlined,
                            ),
                            tooltip: 'Toggle mini-map',
                            onPressed: () =>
                                setState(() => _showMiniMap = !_showMiniMap),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                if (_showMiniMap)
                  Positioned(
                    right: 12,
                    bottom: 12,
                    child: MiniMap(controller: controller),
                  ),
              ],
            ),
          ),
        ),
        if (_selectedTable != null) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Selected table: ${_selectedTable!.tableName}',
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.delete_outline),
                label: const Text('Remove Table'),
                onPressed: widget.onRemoveTable == null
                    ? null
                    : () {
                        widget.onRemoveTable!(_selectedTable!.tableName);
                        setState(() {
                          selectedComponentId = null;
                        });
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TableEditor(
              table: _selectedTable!,
              tables: widget.schema.tables,
              onUpdated: _updateCurrentComponent,
              onForeignKeyUpdated: () {
                controller.removeAllLinks();
                _buildLinksFromSchema();
                _updateCurrentComponent();
              },
            ),
          ),
        ],
      ],
    );
  }
}

// MiniMap, GridBackground/GridPainter, and TableLayout moved to lib/erd/*.dart
