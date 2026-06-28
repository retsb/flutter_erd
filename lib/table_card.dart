import 'package:flutter/material.dart';

import 'models.dart';

/// Small visual widget that renders a `TableModel` as a compact card.
///
/// Used as the component content for the diagram controller. It is kept
/// presentation-focused and stateless so the diagram may instantiate many
/// copies cheaply.
class TableCard extends StatelessWidget {
  final TableModel table;
  final double width;
  final bool selected;

  const TableCard({
    super.key,
    required this.table,
    required this.width,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: selected ? Colors.deepPurple.shade50 : Colors.white,
        border: Border.all(
          color: selected ? Colors.deepPurple : Colors.deepPurple.shade300,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            table.tableName,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: selected ? Colors.deepPurple.shade900 : Colors.black,
            ),
          ),
          if (table.description != null) ...[
            const SizedBox(height: 4),
            Text(
              table.description!,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
          const Divider(color: Colors.deepPurple, thickness: 1.2),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: table.columns.length,
              itemBuilder: (context, index) {
                final column = table.columns[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${column.columnName} : ${column.dataType}${_columnAttributes(column)}',
                        style: const TextStyle(fontSize: 13),
                      ),
                      if (column.description != null)
                        Text(
                          column.description!,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.black54,
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _columnAttributes(ColumnModel column) {
    final tags = <String>[];
    if (column.isPrimaryKey) tags.add('PK');
    if (column.isUnique) tags.add('UQ');
    if (!column.isNullable) tags.add('NN');
    if (column.foreignKey != null) {
      final fk = column.foreignKey!;
      final refs = fk.referenceColumns.join(', ');
      tags.add('FK → ${fk.referenceTable}($refs)');
    }
    return tags.isEmpty ? '' : ' (${tags.join(', ')})';
  }
}
