import 'dart:async';

class ToolParameter {
  final String name;
  final String type;
  final String description;
  final bool required;
  ToolParameter({required this.name, required this.type, required this.description, this.required = true});
}

class ToolResult {
  final bool success;
  final String data;
  final String? error;
  final String? mimeType;
  ToolResult({required this.success, required this.data, this.error, this.mimeType});
}

abstract class AiTool {
  String get name;
  String get description;
  List<ToolParameter> get parameters;

  Future<ToolResult> execute(Map<String, dynamic> args);

  Map<String, dynamic> toJson() => {
    'name': name,
    'description': description,
    'parameters': parameters.map((p) => {
      'name': p.name, 'type': p.type,
      'description': p.description, 'required': p.required,
    }).toList(),
  };
}
