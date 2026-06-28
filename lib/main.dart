import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'erd_diagram.dart';
import 'models.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter ERD',
      theme: ThemeData.from(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'Flutter ERD Diagram'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  SchemaModel? schema;
  String? errorMessage;
  String? statusMessage;
  bool loading = false;

  Future<void> _pickJsonFile() async {
    setState(() {
      errorMessage = null;
      loading = true;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        return;
      }

      final file = result.files.single;
      if (file.bytes == null) {
        throw StateError('Unable to read selected JSON file.');
      }
      final content = utf8.decode(file.bytes!);
      setState(() {
        statusMessage = 'File read successfully.';
      });

      final jsonMap = jsonDecode(content) as Map<String, dynamic>;
      setState(() {
        statusMessage = 'JSON parsed successfully.';
      });

      final validationErrors = SchemaModel.validateJson(jsonMap);
      if (validationErrors.isNotEmpty) {
        throw FormatException(
          'Schema validation failed:\n${validationErrors.join('\n')}',
        );
      }

      final loadedSchema = SchemaModel.fromJson(jsonMap);
      setState(() {
        schema = loadedSchema;
        statusMessage =
            'Diagram created with ${loadedSchema.tables.length} tables.';
      });
    } catch (error) {
      setState(() {
        errorMessage = 'Failed to load JSON: ${error.toString()}';
      });
    } finally {
      setState(() {
        loading = false;
      });
    }
  }

  void _addTable() {
    final nextIndex = (schema?.tables.length ?? 0) + 1;
    final newTable = TableModel(
      tableName: 'table_$nextIndex',
      description: null,
      columns: [
        ColumnModel(
          columnName: 'id',
          description: 'Primary key',
          dataType: 'bigserial',
          isPrimaryKey: true,
          isNullable: false,
          isUnique: true,
          foreignKey: null,
        ),
      ],
      indices: [],
      constraints: [],
    );

    final current = schema;
    final newSchema = SchemaModel(
      dbType: current?.dbType ?? 'PostgreSQL',
      databaseName: current?.databaseName ?? '',
      schemaName: current?.schemaName ?? '',
      tables: [...?current?.tables, newTable],
    );

    setState(() {
      schema = newSchema;
      statusMessage = 'Added table ${newTable.tableName}.';
      errorMessage = null;
    });
  }

  void _removeTable(String tableName) {
    final current = schema;
    if (current == null) return;

    final remainingTables = current.tables
        .where((table) => table.tableName != tableName)
        .toList();

    setState(() {
      schema = SchemaModel(
        dbType: current.dbType,
        databaseName: current.databaseName,
        schemaName: current.schemaName,
        tables: remainingTables,
      );
      statusMessage = 'Removed table $tableName.';
      errorMessage = null;
    });
  }

  Future<void> _exportJson() async {
    if (schema == null) return;
    final content = const JsonEncoder.withIndent(
      '  ',
    ).convert(schema!.toJson());
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Export ERD JSON'),
          content: SizedBox(
            width: 600,
            child: SingleChildScrollView(child: SelectableText(content)),
          ),
          actions: [
            TextButton(
              onPressed: () => _copyJsonToClipboard(content),
              child: const Text('Copy'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _copyJsonToClipboard(String content) async {
    await Clipboard.setData(ClipboardData(text: content));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('JSON copied to clipboard.')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_open),
            onPressed: loading ? null : _pickJsonFile,
            tooltip: 'Open ERD JSON file',
          ),
          if (schema != null)
            IconButton(
              icon: const Icon(Icons.save_outlined),
              onPressed: _exportJson,
              tooltip: 'Export ERD JSON',
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.folder_open),
                  label: const Text('Select ERD JSON File'),
                  onPressed: loading ? null : _pickJsonFile,
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Add Table'),
                  onPressed: loading ? null : _addTable,
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  icon: const Icon(Icons.delete),
                  label: const Text('Remove Last Table'),
                  onPressed: (schema == null || schema!.tables.isEmpty)
                      ? null
                      : () => _removeTable(schema!.tables.last.tableName),
                ),
                const SizedBox(width: 12),
                if (schema != null)
                  ElevatedButton.icon(
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Export JSON'),
                    onPressed: _exportJson,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (loading) const LinearProgressIndicator(),
            if (errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(errorMessage!, style: const TextStyle(color: Colors.red)),
            ],
            if (statusMessage != null && errorMessage == null) ...[
              const SizedBox(height: 12),
              Text(
                statusMessage!,
                style: TextStyle(color: Colors.green.shade700),
              ),
            ],
            const SizedBox(height: 12),
            Expanded(
              child: schema != null
                  ? ERDDiagram(schema: schema!, onRemoveTable: _removeTable)
                  : const Center(
                      child: Text(
                        'Select a JSON file to render the ERD diagram.',
                        textAlign: TextAlign.center,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
