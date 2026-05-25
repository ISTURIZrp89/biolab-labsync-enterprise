import 'package:flutter/foundation.dart';
import '../data/db.dart';
import '../domain/form_definitions.dart';
import 'suggestion_engine.dart';
import 'validation_engine.dart';

class AiService extends ChangeNotifier {
  final SuggestionEngine suggestions;
  final ValidationEngine validation;
  bool _enabled = true;

  AiService(LocalDatabase db)
      : suggestions = SuggestionEngine(db),
        validation = ValidationEngine();

  bool get enabled => _enabled;
  set enabled(bool v) { _enabled = v; notifyListeners(); }

  Future<List<String>> getSuggestions(String fieldKey, String query) async {
    if (!_enabled) return [];
    return suggestions.getSuggestions(fieldKey, query);
  }

  Future<String?> predictValue(String module, String fieldKey, Map<String, dynamic> context) async {
    if (!_enabled) return null;
    return suggestions.predictValue(module, fieldKey, context);
  }

  Future<String?> predictNextField(String module, String sectionKey, String currentFieldKey, Map<String, dynamic> currentData) async {
    if (!_enabled) return null;
    return suggestions.predictNextField(module, sectionKey, currentFieldKey, currentData);
  }

  Future<Map<String, List<String>>> getBatchSuggestions(String module, String sectionKey) async {
    if (!_enabled) return {};
    return suggestions.getBatchSuggestions(module, sectionKey);
  }

  Future<List<Map<String, dynamic>>> getContextualSuggestions(String module, String sectionKey, Map<String, dynamic> currentData) async {
    if (!_enabled) return [];
    return suggestions.getContextualSuggestions(module, sectionKey, currentData);
  }

  Future<void> recordValue(String fieldKey, String value) async {
    if (!_enabled || value.isEmpty) return;
    await suggestions.recordValue(fieldKey, value);
  }

  Future<void> recordContextualSuggestion(String module, String sectionKey, Map<String, dynamic> data) async {
    if (!_enabled) return;
    await suggestions.recordContextualSuggestion(module, sectionKey, data);
  }

  ValidationResult validate(Map<String, dynamic> data, FormSectionDef section) {
    if (!_enabled) return ValidationResult();
    return validation.validate(data, section);
  }

  List<String> validateEntryForClosure(Map<String, dynamic> data) {
    if (!_enabled) return [];
    return validation.validateEntryForClosure(data);
  }
}
