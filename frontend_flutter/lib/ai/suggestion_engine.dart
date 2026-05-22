import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/db.dart';
import '../domain/form_definitions.dart';

class SuggestionEngine {
  final LocalDatabase _db;
  final Map<String, List<String>> _historyCache = {};
  final Map<String, List<Map<String, dynamic>>> _fieldSuggestions = {};
  DateTime _lastLoad = DateTime(2000);
  static const _cacheDuration = Duration(minutes: 5);

  SuggestionEngine(this._db);

  Future<List<String>> getSuggestions(String fieldKey, String query, {int maxResults = 8}) async {
    await _ensureLoaded();
    final all = _historyCache[fieldKey] ?? [];
    if (query.isEmpty) return all.take(maxResults).toList();
    final q = query.toLowerCase();
    return all.where((v) => v.toLowerCase().contains(q)).take(maxResults).toList();
  }

  Future<List<Map<String, dynamic>>> getContextualSuggestions(String module, String sectionKey, Map<String, dynamic> currentData) async {
    await _ensureLoaded();
    final key = '$module/$sectionKey';
    final suggestions = _fieldSuggestions[key] ?? [];
    if (suggestions.isEmpty) return [];

    final scored = suggestions.map((s) {
      int score = 0;
      for (final entry in currentData.entries) {
        if (s['context']?[entry.key]?.toString().toLowerCase() == entry.value.toString().toLowerCase()) {
          score += 10;
        }
      }
      score += (s['frequency'] as int? ?? 1);
      return Map<String, dynamic>.from(s)..['_score'] = score;
    }).toList();

    scored.sort((a, b) => (b['_score'] as int? ?? 0).compareTo(a['_score'] as int? ?? 0));
    return scored.take(5).toList();
  }

  Future<String?> predictNextField(String module, String sectionKey, String currentFieldKey, Map<String, dynamic> currentData) async {
    await _ensureLoaded();
    final key = '$module/$sectionKey';
    const predictions = {
      'hora_inicio': 'hora_fin',
      'responsable': 'cargo_operativo',
      'area': 'supervisor',
      'reactivo': 'lote',
      'lote': 'caducidad',
      'caducidad': 'cantidad',
      'equipo': 'tipo_equipo',
    };
    return predictions[currentFieldKey];
  }

  Future<String?> predictValue(String module, String fieldKey, Map<String, dynamic> context) async {
    await _ensureLoaded();
    if (fieldKey == 'hora_fin' && context.containsKey('hora_inicio')) {
      final start = context['hora_inicio'] as String? ?? '';
      if (start.isNotEmpty) {
        try {
          final parts = start.split(':');
          final h = int.parse(parts[0]) + 1;
          return '${h.toString().padLeft(2, '0')}:${parts[1]}';
        } catch (_) {}
      }
    }
    if (fieldKey == 'turno') {
      final now = DateTime.now().hour;
      return now < 14 ? 'MATUTINO' : 'VESPERTINO';
    }
    final all = _historyCache[fieldKey] ?? [];
    if (all.isNotEmpty) return all.first;
    return null;
  }

  Future<Map<String, List<String>>> getBatchSuggestions(String module, String sectionKey) async {
    await _ensureLoaded();
    final result = <String, List<String>>{};
    final def = findSection(module, sectionKey);
    if (def == null) return result;

    final fields = (def['general_fields'] as List?) ?? [];
    for (final f in fields) {
      final key = f['key'] as String;
      if (f['type'] == 'autofill' || f['type'] == 'select') continue;
      result[key] = (_historyCache[key] ?? []).take(5).toList();
    }
    return result;
  }

  Future<void> recordValue(String fieldKey, String value) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'ai_history_$fieldKey';
    final raw = prefs.getString(key) ?? '[]';
    List<String> list;
    try { list = (jsonDecode(raw) as List).cast<String>(); } catch (_) { list = []; }
    list.remove(value);
    list.insert(0, value);
    if (list.length > 50) list = list.sublist(0, 50);
    await prefs.setString(key, jsonEncode(list));
    _historyCache[fieldKey] = list;
  }

  Future<void> recordContextualSuggestion(String module, String sectionKey, Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'ai_context_$module/$sectionKey';
    final raw = prefs.getString(key) ?? '[]';
    List<Map<String, dynamic>> list;
    try {
      list = (jsonDecode(raw) as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) { list = []; }

    final contextualKeys = ['responsable', 'area', 'turno', 'equipo', 'reactivo'];
    final context = <String, dynamic>{};
    for (final ck in contextualKeys) {
      if (data.containsKey(ck) && data[ck].toString().isNotEmpty) {
        context[ck] = data[ck].toString();
      }
    }

    if (context.isEmpty) return;

    final entry = {
      'context': context,
      'frequency': 1,
      'last_used': DateTime.now().toIso8601String(),
    };

    final existingIdx = list.indexWhere((e) =>
      e['context'] is Map &&
      (e['context'] as Map).entries.every((ee) => context[ee.key]?.toString() == ee.value.toString()));
    if (existingIdx >= 0) {
      list[existingIdx]['frequency'] = (list[existingIdx]['frequency'] as int? ?? 1) + 1;
      list[existingIdx]['last_used'] = DateTime.now().toIso8601String();
    } else {
      list.insert(0, entry);
    }
    if (list.length > 100) list = list.sublist(0, 100);
    await prefs.setString(key, jsonEncode(list));
    _fieldSuggestions[key] = list;
  }

  Future<void> _ensureLoaded() async {
    if (DateTime.now().difference(_lastLoad) < _cacheDuration) return;
    _lastLoad = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith('ai_history_'));
    for (final k in keys) {
      final fieldKey = k.replaceFirst('ai_history_', '');
      final raw = prefs.getString(k) ?? '[]';
      try {
        _historyCache[fieldKey] = (jsonDecode(raw) as List).cast<String>();
      } catch (_) {}
    }
    final ctxKeys = prefs.getKeys().where((k) => k.startsWith('ai_context_'));
    for (final k in ctxKeys) {
      final suggestionKey = k.replaceFirst('ai_context_', '');
      final raw = prefs.getString(k) ?? '[]';
      try {
        _fieldSuggestions[suggestionKey] = (jsonDecode(raw) as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      } catch (_) {}
    }
  }
}
