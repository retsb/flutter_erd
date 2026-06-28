import 'dart:convert';
import 'dart:io';
import 'lib/models.dart';

void main() {
  final file = File('example_flutter_erd.json');
  final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final errors = SchemaModel.validateJson(json);
  if (errors.isEmpty) {
    stdout.writeln('VALID');
  } else {
    stdout.writeln('INVALID');
    for (final error in errors) {
      stdout.writeln(error);
    }
  }
}
