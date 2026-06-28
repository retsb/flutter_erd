List<String> _validateStringField(
  Map<String, dynamic> json,
  String key,
  String path, {
  bool required = false,
  bool allowEmpty = true,
}) {
  if (!json.containsKey(key) || json[key] == null) {
    return required ? ['$path$key is required.'] : [];
  }

  final value = json[key];
  if (value is! String) {
    return ['$path$key must be a string.'];
  }
  if (!allowEmpty && value.isEmpty) {
    return ['$path$key must not be empty.'];
  }
  return [];
}

List<String> _validateStringListField(
  Map<String, dynamic> json,
  String key,
  String path, {
  bool required = false,
}) {
  if (!json.containsKey(key) || json[key] == null) {
    return required ? ['$path$key is required.'] : [];
  }

  final value = json[key];
  if (value is! List) {
    return ['$path$key must be a list of strings.'];
  }

  final errors = <String>[];
  for (var i = 0; i < value.length; i++) {
    if (value[i] is! String) {
      errors.add('$path$key[$i] must be a string.');
    }
  }
  return errors;
}

List<String> _validateOptionalObjectField(
  Map<String, dynamic> json,
  String key,
  String path,
) {
  if (!json.containsKey(key) || json[key] == null) {
    return [];
  }

  if (json[key] is! Map<String, dynamic>) {
    return ['$path$key must be an object.'];
  }
  return [];
}

class SchemaModel {
  String dbType;
  String databaseName;
  String schemaName;
  List<TableModel> tables;

  SchemaModel({
    required this.dbType,
    required this.databaseName,
    required this.schemaName,
    required this.tables,
  });

  static List<String> validateJson(Map<String, dynamic> json) {
    final errors = <String>[];

    errors.addAll(
      _validateStringField(
        json,
        'dbType',
        'Schema.',
        required: true,
        allowEmpty: false,
      ),
    );
    errors.addAll(
      _validateStringField(
        json,
        'databaseName',
        'Schema.',
        required: true,
        allowEmpty: false,
      ),
    );
    errors.addAll(
      _validateStringField(
        json,
        'schemaName',
        'Schema.',
        required: true,
        allowEmpty: false,
      ),
    );

    if (json.containsKey('tables') && json['tables'] != null) {
      if (json['tables'] is! List<dynamic>) {
        errors.add('Schema.tables must be an array.');
      } else {
        final tables = json['tables'] as List<dynamic>;
        for (var i = 0; i < tables.length; i++) {
          final entry = tables[i];
          if (entry is Map<String, dynamic>) {
            errors.addAll(TableModel.validateJson(entry, 'Schema.tables[$i].'));
          } else {
            errors.add('Schema.tables[$i] must be an object.');
          }
        }
      }
    } else {
      errors.add('Schema.tables is required.');
    }

    final tableEntries = <Map<String, dynamic>>[];
    if (json.containsKey('tables') && json['tables'] is List<dynamic>) {
      for (final tableEntry in json['tables'] as List<dynamic>) {
        if (tableEntry is Map<String, dynamic>) {
          tableEntries.add(tableEntry);
        }
      }
    }

    final tableColumns = _collectTableColumns(tableEntries);
    errors.addAll(_validateTableReferences(tableColumns, tableEntries));

    return errors;
  }

  static Map<String, Set<String>> _collectTableColumns(
    List<Map<String, dynamic>> tables,
  ) {
    final result = <String, Set<String>>{};
    for (final tableJson in tables) {
      final tableName = tableJson['tableName'];
      if (tableName is! String || tableName.isEmpty) {
        continue;
      }

      final columns = <String>{};
      if (tableJson['columns'] is List<dynamic>) {
        for (final columnEntry in tableJson['columns'] as List<dynamic>) {
          if (columnEntry is Map<String, dynamic>) {
            final columnName = columnEntry['columnName'];
            if (columnName is String && columnName.isNotEmpty) {
              columns.add(columnName);
            }
          }
        }
      }
      result[tableName] = columns;
    }
    return result;
  }

  static List<String> _validateTableReferences(
    Map<String, Set<String>> tableColumns,
    List<Map<String, dynamic>> tables,
  ) {
    final errors = <String>[];
    for (var i = 0; i < tables.length; i++) {
      final tableJson = tables[i];
      final path = 'Schema.tables[$i].';
      if (tableJson['columns'] is List<dynamic>) {
        for (
          var j = 0;
          j < (tableJson['columns'] as List<dynamic>).length;
          j++
        ) {
          final columnEntry = (tableJson['columns'] as List<dynamic>)[j];
          if (columnEntry is Map<String, dynamic> &&
              columnEntry['foreignKey'] is Map<String, dynamic>) {
            errors.addAll(
              _validateForeignKeyReference(
                columnEntry['foreignKey'] as Map<String, dynamic>,
                '${path}columns[$j].foreignKey.',
                tableColumns,
              ),
            );
          }
        }
      }

      if (tableJson['constraints'] is List<dynamic>) {
        for (
          var j = 0;
          j < (tableJson['constraints'] as List<dynamic>).length;
          j++
        ) {
          final constraintEntry =
              (tableJson['constraints'] as List<dynamic>)[j];
          if (constraintEntry is Map<String, dynamic>) {
            errors.addAll(
              _validateConstraintReferences(
                constraintEntry,
                '${path}constraints[$j].',
                tableColumns,
              ),
            );
          }
        }
      }

      final tableName = tableJson['tableName'];
      if (tableName is String &&
          tableColumns.containsKey(tableName) &&
          tableJson['indices'] is List<dynamic>) {
        for (
          var j = 0;
          j < (tableJson['indices'] as List<dynamic>).length;
          j++
        ) {
          final indexEntry = (tableJson['indices'] as List<dynamic>)[j];
          if (indexEntry is Map<String, dynamic>) {
            errors.addAll(
              _validateIndexColumns(
                indexEntry,
                '${path}indices[$j].',
                tableColumns[tableName]!,
              ),
            );
          }
        }
      }
    }
    return errors;
  }

  static List<String> _validateForeignKeyReference(
    Map<String, dynamic> json,
    String path,
    Map<String, Set<String>> tableColumns,
  ) {
    final errors = <String>[];
    final referenceTable = json['referenceTable'];
    if (referenceTable is! String || referenceTable.isEmpty) {
      return errors;
    }

    if (!tableColumns.containsKey(referenceTable)) {
      errors.add(
        '$path referenceTable refers to unknown table "$referenceTable".',
      );
      return errors;
    }

    final referencedColumns = <String>[];
    if (json['referenceColumns'] is List<dynamic>) {
      for (final item in json['referenceColumns'] as List<dynamic>) {
        if (item is String) {
          referencedColumns.add(item);
        }
      }
    }

    final availableColumns = tableColumns[referenceTable]!;
    for (final referencedColumn in referencedColumns) {
      if (!availableColumns.contains(referencedColumn)) {
        errors.add(
          '$path referenceColumns refers to unknown column "$referencedColumn" in table "$referenceTable".',
        );
      }
    }
    return errors;
  }

  static List<String> _validateConstraintReferences(
    Map<String, dynamic> json,
    String path,
    Map<String, Set<String>> tableColumns,
  ) {
    final errors = <String>[];
    if (json['referenceTable'] is String &&
        (json['referenceTable'] as String).isNotEmpty) {
      final referenceTable = json['referenceTable'] as String;
      if (!tableColumns.containsKey(referenceTable)) {
        errors.add(
          '$path referenceTable refers to unknown table "$referenceTable".',
        );
      } else {
        final availableColumns = tableColumns[referenceTable]!;
        if (json['referenceColumns'] is List<dynamic>) {
          for (final item in json['referenceColumns'] as List<dynamic>) {
            if (item is String && !availableColumns.contains(item)) {
              errors.add(
                '$path referenceColumns refers to unknown column "$item" in table "$referenceTable".',
              );
            }
          }
        }
      }
    }
    return errors;
  }

  static List<String> _validateIndexColumns(
    Map<String, dynamic> json,
    String path,
    Set<String> currentTableColumns,
  ) {
    final errors = <String>[];
    if (json['columns'] is List<dynamic>) {
      for (final item in json['columns'] as List<dynamic>) {
        if (item is String && !currentTableColumns.contains(item)) {
          errors.add(
            '$path columns refers to unknown column "$item" in the current table.',
          );
        }
      }
    }
    return errors;
  }

  factory SchemaModel.fromJson(Map<String, dynamic> json) {
    return SchemaModel(
      dbType: json['dbType'] as String? ?? 'PostgreSQL',
      databaseName: json['databaseName'] as String? ?? '',
      schemaName: json['schemaName'] as String? ?? '',
      tables: (json['tables'] as List<dynamic>? ?? [])
          .map((entry) => TableModel.fromJson(entry as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'dbType': dbType,
    'databaseName': databaseName,
    'schemaName': schemaName,
    'tables': tables.map((table) => table.toJson()).toList(),
  };
}

class TableModel {
  String tableName;
  String? description;
  List<ColumnModel> columns;
  List<IndexModel> indices;
  List<ConstraintModel> constraints;

  TableModel({
    required this.tableName,
    this.description,
    required this.columns,
    required this.indices,
    required this.constraints,
  });

  static List<String> validateJson(Map<String, dynamic> json, String path) {
    final errors = <String>[];

    errors.addAll(
      _validateStringField(
        json,
        'tableName',
        path,
        required: true,
        allowEmpty: false,
      ),
    );
    if (json.containsKey('description') &&
        json['description'] != null &&
        json['description'] is! String) {
      errors.add('${path}description must be a string.');
    }

    if (json.containsKey('columns') && json['columns'] != null) {
      if (json['columns'] is! List<dynamic>) {
        errors.add('${path}columns must be an array.');
      } else {
        final columns = json['columns'] as List<dynamic>;
        for (var i = 0; i < columns.length; i++) {
          final entry = columns[i];
          if (entry is Map<String, dynamic>) {
            errors.addAll(
              ColumnModel.validateJson(entry, '${path}columns[$i].'),
            );
          } else {
            errors.add('${path}columns[$i] must be an object.');
          }
        }
      }
    } else {
      errors.add('${path}columns is required.');
    }

    if (json.containsKey('indices') && json['indices'] != null) {
      if (json['indices'] is! List<dynamic>) {
        errors.add('${path}indices must be an array.');
      } else {
        final indices = json['indices'] as List<dynamic>;
        for (var i = 0; i < indices.length; i++) {
          final entry = indices[i];
          if (entry is Map<String, dynamic>) {
            errors.addAll(
              IndexModel.validateJson(entry, '${path}indices[$i].'),
            );
          } else {
            errors.add('${path}indices[$i] must be an object.');
          }
        }
      }
    }

    if (json.containsKey('constraints') && json['constraints'] != null) {
      if (json['constraints'] is! List<dynamic>) {
        errors.add('${path}constraints must be an array.');
      } else {
        final constraints = json['constraints'] as List<dynamic>;
        for (var i = 0; i < constraints.length; i++) {
          final entry = constraints[i];
          if (entry is Map<String, dynamic>) {
            errors.addAll(
              ConstraintModel.validateJson(entry, '${path}constraints[$i].'),
            );
          } else {
            errors.add('${path}constraints[$i] must be an object.');
          }
        }
      }
    }

    return errors;
  }

  factory TableModel.fromJson(Map<String, dynamic> json) {
    return TableModel(
      tableName: json['tableName'] as String,
      description: json['description'] as String?,
      columns: (json['columns'] as List<dynamic>? ?? [])
          .map((entry) => ColumnModel.fromJson(entry as Map<String, dynamic>))
          .toList(),
      indices: (json['indices'] as List<dynamic>? ?? [])
          .map((entry) => IndexModel.fromJson(entry as Map<String, dynamic>))
          .toList(),
      constraints: (json['constraints'] as List<dynamic>? ?? [])
          .map(
            (entry) => ConstraintModel.fromJson(entry as Map<String, dynamic>),
          )
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'tableName': tableName,
    'description': description,
    'columns': columns.map((column) => column.toJson()).toList(),
    'indices': indices.map((index) => index.toJson()).toList(),
    'constraints': constraints
        .map((constraint) => constraint.toJson())
        .toList(),
  };
}

class ColumnModel {
  String columnName;
  String? description;
  String dataType;
  bool isPrimaryKey;
  bool isNullable;
  bool isUnique;
  ForeignKeyModel? foreignKey;

  ColumnModel({
    required this.columnName,
    this.description,
    required this.dataType,
    required this.isPrimaryKey,
    required this.isNullable,
    required this.isUnique,
    this.foreignKey,
  });

  static List<String> validateJson(Map<String, dynamic> json, String path) {
    final errors = <String>[];

    errors.addAll(
      _validateStringField(
        json,
        'columnName',
        path,
        required: true,
        allowEmpty: false,
      ),
    );
    errors.addAll(
      _validateStringField(
        json,
        'dataType',
        path,
        required: true,
        allowEmpty: false,
      ),
    );
    if (json.containsKey('description') &&
        json['description'] != null &&
        json['description'] is! String) {
      errors.add('${path}description must be a string.');
    }
    if (json.containsKey('isPrimaryKey') &&
        json['isPrimaryKey'] != null &&
        json['isPrimaryKey'] is! bool) {
      errors.add('${path}isPrimaryKey must be a boolean.');
    }
    if (json.containsKey('isNullable') &&
        json['isNullable'] != null &&
        json['isNullable'] is! bool) {
      errors.add('${path}isNullable must be a boolean.');
    }
    if (json.containsKey('isUnique') &&
        json['isUnique'] != null &&
        json['isUnique'] is! bool) {
      errors.add('${path}isUnique must be a boolean.');
    }
    errors.addAll(_validateOptionalObjectField(json, 'foreignKey', path));
    if (json.containsKey('foreignKey') &&
        json['foreignKey'] is Map<String, dynamic>) {
      errors.addAll(
        ForeignKeyModel.validateJson(
          json['foreignKey'] as Map<String, dynamic>,
          '${path}foreignKey.',
        ),
      );
    }

    return errors;
  }

  factory ColumnModel.fromJson(Map<String, dynamic> json) {
    return ColumnModel(
      columnName: json['columnName'] as String,
      description: json['description'] as String?,
      dataType: json['dataType'] as String,
      isPrimaryKey: json['isPrimaryKey'] as bool? ?? false,
      isNullable: json['isNullable'] as bool? ?? true,
      isUnique: json['isUnique'] as bool? ?? false,
      foreignKey: json['foreignKey'] != null
          ? ForeignKeyModel.fromJson(json['foreignKey'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'columnName': columnName,
    'description': description,
    'dataType': dataType,
    'isPrimaryKey': isPrimaryKey,
    'isNullable': isNullable,
    'isUnique': isUnique,
    'foreignKey': foreignKey?.toJson(),
  };
}

class ForeignKeyModel {
  String referenceTable;
  List<String> referenceColumns;
  String? onDelete;
  String? onUpdate;

  ForeignKeyModel({
    required this.referenceTable,
    required this.referenceColumns,
    this.onDelete,
    this.onUpdate,
  });

  static List<String> validateJson(Map<String, dynamic> json, String path) {
    final errors = <String>[];

    errors.addAll(
      _validateStringField(
        json,
        'referenceTable',
        path,
        required: true,
        allowEmpty: false,
      ),
    );
    errors.addAll(
      _validateStringListField(json, 'referenceColumns', path, required: true),
    );
    if (json.containsKey('onDelete') &&
        json['onDelete'] != null &&
        json['onDelete'] is! String) {
      errors.add('${path}onDelete must be a string.');
    }
    if (json.containsKey('onUpdate') &&
        json['onUpdate'] != null &&
        json['onUpdate'] is! String) {
      errors.add('${path}onUpdate must be a string.');
    }

    return errors;
  }

  factory ForeignKeyModel.fromJson(Map<String, dynamic> json) {
    return ForeignKeyModel(
      referenceTable: json['referenceTable'] as String,
      referenceColumns: (json['referenceColumns'] as List<dynamic>)
          .map((value) => value as String)
          .toList(),
      onDelete: json['onDelete'] as String?,
      onUpdate: json['onUpdate'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'referenceTable': referenceTable,
    'referenceColumns': referenceColumns,
    'onDelete': onDelete,
    'onUpdate': onUpdate,
  };
}

class IndexModel {
  String indexName;
  String? description;
  List<String> columns;
  bool isUnique;
  String? indexType;

  IndexModel({
    required this.indexName,
    this.description,
    required this.columns,
    required this.isUnique,
    this.indexType,
  });

  static List<String> validateJson(Map<String, dynamic> json, String path) {
    final errors = <String>[];

    errors.addAll(
      _validateStringField(
        json,
        'indexName',
        path,
        required: true,
        allowEmpty: false,
      ),
    );
    if (json.containsKey('description') &&
        json['description'] != null &&
        json['description'] is! String) {
      errors.add('${path}description must be a string.');
    }
    errors.addAll(
      _validateStringListField(json, 'columns', path, required: true),
    );
    if (json.containsKey('isUnique') &&
        json['isUnique'] != null &&
        json['isUnique'] is! bool) {
      errors.add('${path}isUnique must be a boolean.');
    }
    if (json.containsKey('indexType') &&
        json['indexType'] != null &&
        json['indexType'] is! String) {
      errors.add('${path}indexType must be a string.');
    }

    return errors;
  }

  factory IndexModel.fromJson(Map<String, dynamic> json) {
    return IndexModel(
      indexName: json['indexName'] as String,
      description: json['description'] as String?,
      columns: (json['columns'] as List<dynamic>? ?? [])
          .map((value) => value as String)
          .toList(),
      isUnique: json['isUnique'] as bool? ?? false,
      indexType: json['indexType'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'indexName': indexName,
    'description': description,
    'columns': columns,
    'isUnique': isUnique,
    'indexType': indexType,
  };
}

class ConstraintModel {
  String constraintName;
  String? description;
  String constraintType;
  List<String> columns;
  String? referenceTable;
  List<String> referenceColumns;
  String? expression;

  ConstraintModel({
    required this.constraintName,
    this.description,
    required this.constraintType,
    required this.columns,
    this.referenceTable,
    required this.referenceColumns,
    this.expression,
  });

  static List<String> validateJson(Map<String, dynamic> json, String path) {
    final errors = <String>[];

    errors.addAll(
      _validateStringField(
        json,
        'constraintName',
        path,
        required: true,
        allowEmpty: false,
      ),
    );
    errors.addAll(
      _validateStringField(
        json,
        'constraintType',
        path,
        required: true,
        allowEmpty: false,
      ),
    );
    if (json.containsKey('description') &&
        json['description'] != null &&
        json['description'] is! String) {
      errors.add('${path}description must be a string.');
    }
    errors.addAll(
      _validateStringListField(json, 'columns', path, required: true),
    );

    final constraintTypeValue = json['constraintType'];
    final isForeignKey =
        constraintTypeValue is String &&
        constraintTypeValue.toLowerCase() == 'foreign key';
    final hasReferenceTable =
        json.containsKey('referenceTable') &&
        json['referenceTable'] != null &&
        json['referenceTable'] is String &&
        (json['referenceTable'] as String).isNotEmpty;

    if (json.containsKey('referenceTable') && json['referenceTable'] != null) {
      if (json['referenceTable'] is! String ||
          (json['referenceTable'] as String).isEmpty) {
        errors.add('${path}referenceTable must be a non-empty string.');
      }
    }

    if (isForeignKey || hasReferenceTable) {
      errors.addAll(
        _validateStringListField(
          json,
          'referenceColumns',
          path,
          required: true,
        ),
      );
      if (!hasReferenceTable) {
        errors.add(
          '${path}referenceTable is required for foreign key constraints.',
        );
      }
    } else if (json.containsKey('referenceColumns') &&
        json['referenceColumns'] != null) {
      if (json['referenceColumns'] is! List<dynamic>) {
        errors.add('${path}referenceColumns must be a list of strings.');
      } else {
        for (
          var i = 0;
          i < (json['referenceColumns'] as List<dynamic>).length;
          i++
        ) {
          if ((json['referenceColumns'] as List<dynamic>)[i] is! String) {
            errors.add('${path}referenceColumns[$i] must be a string.');
          }
        }
      }
    }

    if (json.containsKey('expression') &&
        json['expression'] != null &&
        json['expression'] is! String) {
      errors.add('${path}expression must be a string.');
    }

    return errors;
  }

  factory ConstraintModel.fromJson(Map<String, dynamic> json) {
    return ConstraintModel(
      constraintName: json['constraintName'] as String,
      description: json['description'] as String?,
      constraintType: json['constraintType'] as String,
      columns: (json['columns'] as List<dynamic>? ?? [])
          .map((value) => value as String)
          .toList(),
      referenceTable: json['referenceTable'] as String?,
      referenceColumns: (json['referenceColumns'] as List<dynamic>? ?? [])
          .map((value) => value as String)
          .toList(),
      expression: json['expression'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'constraintName': constraintName,
    'description': description,
    'constraintType': constraintType,
    'columns': columns,
    'referenceTable': referenceTable,
    'referenceColumns': referenceColumns,
    'expression': expression,
  };
}
