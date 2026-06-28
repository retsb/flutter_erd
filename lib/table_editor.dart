import 'package:flutter/material.dart';

import 'models.dart';

const List<String> dataTypeOptions = [
  'bigint',
  'integer',
  'bigserial',
  'boolean',
  'varchar',
  'text',
  'numeric',
  'date',
  'timestamp',
  'timestamp with time zone',
  'uuid',
  'json',
  'jsonb',
];

String? _canonicalizeDataType(String value) {
  final v = value.trim().toLowerCase();
  final varcharMatch = RegExp(r'^varchar\s*\(');
  if (varcharMatch.hasMatch(v)) {
    return 'varchar';
  }
  if (v == 'int' || v == 'int4' || v == 'int8') return 'integer';
  if (v == 'serial') return 'bigserial';
  if (v == 'bool') return 'boolean';
  if (v == 'timestamptz' || v == 'timestamp with tz') {
    return 'timestamp with time zone';
  }
  if (v == 'decimal') return 'numeric';
  if (v == 'text' || v == 'char' || v == 'character') return 'text';
  if (dataTypeOptions.contains(value)) {
    return value;
  }
  final lowerMatch = dataTypeOptions.firstWhere(
    (opt) => opt.toLowerCase() == v,
    orElse: () => '',
  );
  return lowerMatch.isEmpty ? null : lowerMatch;
}

/// Editor widget that shows lists of columns/indices/constraints/foreign-keys
/// and a compact detail pane for editing the selected item.
///
/// The editor uses a list+detail pattern to keep the UI compact and desktop-
/// friendly. It notifies its parent via [onUpdated] and
/// [onForeignKeyUpdated] when data changes so external callers can refresh
/// diagram links or re-render components.
class TableEditor extends StatefulWidget {
  final TableModel table;
  final List<TableModel> tables;
  final VoidCallback onUpdated;
  final VoidCallback onForeignKeyUpdated;

  const TableEditor({
    super.key,
    required this.table,
    required this.tables,
    required this.onUpdated,
    required this.onForeignKeyUpdated,
  });

  @override
  State<TableEditor> createState() => _TableEditorState();
}

class _TableEditorState extends State<TableEditor> {
  int _tabIndex = 0; // 0=Columns,1=Indices,2=Constraints,3=FKs
  int? _selectedIndex;

  TableModel get table => widget.table;
  List<TableModel> get tables => widget.tables;

  void _onUpdated() {
    widget.onUpdated();
    setState(() {});
  }

  void _onForeignKeyUpdated() {
    widget.onForeignKeyUpdated();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.deepPurple.shade200, width: 2),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Edit table: ${table.tableName}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          TextFormField(
            initialValue: table.description ?? '',
            decoration: const InputDecoration(
              labelText: 'Table description',
              border: OutlineInputBorder(),
            ),
            onChanged: (v) {
              table.description = v.isEmpty ? null : v;
              _onUpdated();
            },
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Row(
              children: [
                Flexible(flex: 3, child: _leftPane()),
                const SizedBox(width: 12),
                Flexible(flex: 5, child: _rightPane()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _leftPane() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                _tabButton(0, 'Columns'),
                const SizedBox(width: 8),
                _tabButton(1, 'Indices'),
                const SizedBox(width: 8),
                _tabButton(2, 'Constraints'),
                const SizedBox(width: 8),
                _tabButton(3, 'Foreign Keys'),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(child: _buildListArea()),
        ],
      ),
    );
  }

  Widget _rightPane() {
    if (_selectedIndex == null) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Center(child: Text('Select an item to edit')),
      );
    }
    switch (_tabIndex) {
      case 0:
        return _columnDetail(table.columns[_selectedIndex!]);
      case 1:
        return _indexDetail(table.indices[_selectedIndex!]);
      case 2:
        return _constraintDetail(table.constraints[_selectedIndex!]);
      case 3:
        final fks = table.columns.where((c) => c.foreignKey != null).toList();
        return _fkDetail(fks[_selectedIndex!]);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _tabButton(int index, String label) {
    final selected = _tabIndex == index;
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: selected
            ? Theme.of(context).primaryColor
            : Colors.grey.shade200,
        foregroundColor: selected ? Colors.white : Colors.black87,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      onPressed: () {
        setState(() {
          _tabIndex = index;
          _selectedIndex = null;
        });
      },
      child: Text(label),
    );
  }

  Widget _buildListArea() {
    switch (_tabIndex) {
      case 0:
        return _columnsList();
      case 1:
        return _indicesList();
      case 2:
        return _constraintsList();
      case 3:
        return _fksList();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _columnsList() {
    return Column(
      children: [
        ListTile(
          title: const Text('Columns'),
          trailing: ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Add'),
            onPressed: () {
              _addColumn();
              setState(() {
                _selectedIndex = table.columns.length - 1;
              });
            },
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            itemCount: table.columns.length,
            itemBuilder: (context, i) {
              final col = table.columns[i];
              return ListTile(
                selected: _selectedIndex == i,
                title: Text(col.columnName),
                subtitle: Text(col.dataType),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () {
                    table.columns.removeAt(i);
                    _onUpdated();
                    setState(() {
                      _selectedIndex = null;
                    });
                  },
                ),
                onTap: () => setState(() => _selectedIndex = i),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _indicesList() {
    return Column(
      children: [
        ListTile(
          title: const Text('Indices'),
          trailing: ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Add'),
            onPressed: () {
              _addIndex();
              setState(() {
                _selectedIndex = table.indices.length - 1;
              });
            },
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            itemCount: table.indices.length,
            itemBuilder: (context, i) {
              final it = table.indices[i];
              return ListTile(
                selected: _selectedIndex == i,
                title: Text(it.indexName),
                subtitle: Text(it.columns.join(', ')),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () {
                    table.indices.removeAt(i);
                    _onUpdated();
                    setState(() {
                      _selectedIndex = null;
                    });
                  },
                ),
                onTap: () => setState(() => _selectedIndex = i),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _constraintsList() {
    return Column(
      children: [
        ListTile(
          title: const Text('Constraints'),
          trailing: ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Add'),
            onPressed: () {
              _addConstraint();
              setState(() {
                _selectedIndex = table.constraints.length - 1;
              });
            },
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            itemCount: table.constraints.length,
            itemBuilder: (context, i) {
              final it = table.constraints[i];
              return ListTile(
                selected: _selectedIndex == i,
                title: Text(it.constraintName),
                subtitle: Text(it.constraintType),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () {
                    table.constraints.removeAt(i);
                    _onUpdated();
                    setState(() {
                      _selectedIndex = null;
                    });
                  },
                ),
                onTap: () => setState(() => _selectedIndex = i),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _fksList() {
    final fks = table.columns.where((c) => c.foreignKey != null).toList();
    return Column(
      children: [
        ListTile(
          title: const Text('Foreign Keys'),
          subtitle: Text('${fks.length} items'),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            itemCount: fks.length,
            itemBuilder: (context, i) {
              final col = fks[i];
              return ListTile(
                selected: _selectedIndex == i,
                title: Text(col.columnName),
                subtitle: Text(col.foreignKey?.referenceTable ?? ''),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () {
                    col.foreignKey = null;
                    _onForeignKeyUpdated();
                    setState(() {
                      _selectedIndex = null;
                    });
                  },
                ),
                onTap: () => setState(() => _selectedIndex = i),
              );
            },
          ),
        ),
      ],
    );
  }

  void _addColumn() {
    table.columns.add(
      ColumnModel(
        columnName: 'column_${table.columns.length + 1}',
        description: null,
        dataType: 'varchar',
        isPrimaryKey: false,
        isNullable: true,
        isUnique: false,
        foreignKey: null,
      ),
    );
    _onUpdated();
  }

  void _addIndex() {
    table.indices.add(
      IndexModel(
        indexName: 'index_${table.indices.length + 1}',
        description: null,
        columns: [],
        isUnique: false,
        indexType: 'btree',
      ),
    );
    _onUpdated();
  }

  void _addConstraint() {
    table.constraints.add(
      ConstraintModel(
        constraintName: 'constraint_${table.constraints.length + 1}',
        description: null,
        constraintType: 'foreign key',
        columns: [],
        referenceTable: null,
        referenceColumns: [],
        expression: null,
      ),
    );
    _onUpdated();
  }

  Widget _columnDetail(ColumnModel column) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Column details',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: column.columnName,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) {
                      column.columnName = v;
                      _onUpdated();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue:
                        _canonicalizeDataType(column.dataType) ??
                        column.dataType,
                    decoration: const InputDecoration(
                      labelText: 'Type',
                      border: OutlineInputBorder(),
                    ),
                    items: dataTypeOptions
                        .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        column.dataType = v;
                        _onUpdated();
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    title: const Text('Primary key'),
                    value: column.isPrimaryKey,
                    onChanged: (val) {
                      column.isPrimaryKey = val ?? false;
                      _onUpdated();
                    },
                  ),
                ),
                Expanded(
                  child: CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    title: const Text('Unique'),
                    value: column.isUnique,
                    onChanged: (val) {
                      column.isUnique = val ?? false;
                      _onUpdated();
                    },
                  ),
                ),
                Expanded(
                  child: CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    title: const Text('Nullable'),
                    value: column.isNullable,
                    onChanged: (val) {
                      column.isNullable = val ?? true;
                      _onUpdated();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: column.description ?? '',
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) {
                column.description = v.isEmpty ? null : v;
                _onUpdated();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _indexDetail(IndexModel idx) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Index details',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: idx.indexName,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) {
                idx.indexName = v;
                _onUpdated();
              },
            ),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: idx.columns.join(', '),
              decoration: const InputDecoration(
                labelText: 'Columns (comma separated)',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) {
                idx.columns = v
                    .split(',')
                    .map((s) => s.trim())
                    .where((s) => s.isNotEmpty)
                    .toList();
                _onUpdated();
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Unique'),
                    value: idx.isUnique,
                    onChanged: (v) {
                      idx.isUnique = v ?? false;
                      _onUpdated();
                    },
                  ),
                ),
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    initialValue: idx.indexType,
                    decoration: const InputDecoration(
                      labelText: 'Type',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('Default')),
                      DropdownMenuItem(value: 'btree', child: Text('btree')),
                    ],
                    onChanged: (v) {
                      idx.indexType = v;
                      _onUpdated();
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _constraintDetail(ConstraintModel c) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Constraint details',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: c.constraintName,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) {
                c.constraintName = v;
                _onUpdated();
              },
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: c.constraintType,
              decoration: const InputDecoration(
                labelText: 'Type',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'primary key',
                  child: Text('Primary key'),
                ),
                DropdownMenuItem(
                  value: 'foreign key',
                  child: Text('Foreign key'),
                ),
                DropdownMenuItem(value: 'unique', child: Text('Unique')),
              ],
              onChanged: (v) {
                if (v != null) {
                  c.constraintType = v;
                  _onUpdated();
                }
              },
            ),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: c.columns.join(', '),
              decoration: const InputDecoration(
                labelText: 'Columns',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) {
                c.columns = v
                    .split(',')
                    .map((s) => s.trim())
                    .where((s) => s.isNotEmpty)
                    .toList();
                _onUpdated();
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: c.referenceTable ?? '',
                    decoration: const InputDecoration(
                      labelText: 'Reference table',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) {
                      c.referenceTable = v.isEmpty ? null : v;
                      _onUpdated();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    initialValue: c.referenceColumns.join(', '),
                    decoration: const InputDecoration(
                      labelText: 'Reference columns',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) {
                      c.referenceColumns = v
                          .split(',')
                          .map((s) => s.trim())
                          .where((s) => s.isNotEmpty)
                          .toList();
                      _onUpdated();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: c.expression ?? '',
              decoration: const InputDecoration(
                labelText: 'Expression',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) {
                c.expression = v.isEmpty ? null : v;
                _onUpdated();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _fkDetail(ColumnModel column) {
    final fk = column.foreignKey!;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Foreign key details',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    initialValue: fk.referenceTable,
                    decoration: const InputDecoration(
                      labelText: 'Reference table',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      DropdownMenuItem<String?>(
                        value: null,
                        child: const Text('None'),
                      ),
                      ...tables
                          .where((t) => t.tableName != table.tableName)
                          .map(
                            (t) => DropdownMenuItem<String?>(
                              value: t.tableName,
                              child: Text(t.tableName),
                            ),
                          ),
                    ],
                    onChanged: (v) {
                      if (v == null) {
                        column.foreignKey = null;
                      } else {
                        fk.referenceTable = v;
                      }
                      _onForeignKeyUpdated();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    initialValue: fk.referenceColumns.join(', '),
                    decoration: const InputDecoration(
                      labelText: 'Reference columns',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) {
                      fk.referenceColumns = v
                          .split(',')
                          .map((s) => s.trim())
                          .where((s) => s.isNotEmpty)
                          .toList();
                      _onForeignKeyUpdated();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    initialValue: fk.onDelete,
                    decoration: const InputDecoration(
                      labelText: 'ON DELETE',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('Default')),
                      DropdownMenuItem(
                        value: 'NO ACTION',
                        child: Text('NO ACTION'),
                      ),
                      DropdownMenuItem(
                        value: 'RESTRICT',
                        child: Text('RESTRICT'),
                      ),
                      DropdownMenuItem(
                        value: 'CASCADE',
                        child: Text('CASCADE'),
                      ),
                      DropdownMenuItem(
                        value: 'SET NULL',
                        child: Text('SET NULL'),
                      ),
                      DropdownMenuItem(
                        value: 'SET DEFAULT',
                        child: Text('SET DEFAULT'),
                      ),
                    ],
                    onChanged: (v) {
                      fk.onDelete = v;
                      _onForeignKeyUpdated();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    initialValue: fk.onUpdate,
                    decoration: const InputDecoration(
                      labelText: 'ON UPDATE',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('Default')),
                      DropdownMenuItem(
                        value: 'NO ACTION',
                        child: Text('NO ACTION'),
                      ),
                      DropdownMenuItem(
                        value: 'RESTRICT',
                        child: Text('RESTRICT'),
                      ),
                      DropdownMenuItem(
                        value: 'CASCADE',
                        child: Text('CASCADE'),
                      ),
                      DropdownMenuItem(
                        value: 'SET NULL',
                        child: Text('SET NULL'),
                      ),
                      DropdownMenuItem(
                        value: 'SET DEFAULT',
                        child: Text('SET DEFAULT'),
                      ),
                    ],
                    onChanged: (v) {
                      fk.onUpdate = v;
                      _onForeignKeyUpdated();
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
