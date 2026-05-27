import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

// ---------------------------------------------------------------------------
// Field-level diff model
// ---------------------------------------------------------------------------

class FieldChange {
  final String field;
  final dynamic oldValue;
  final dynamic newValue;

  const FieldChange({
    required this.field,
    required this.oldValue,
    required this.newValue,
  });

  Map<String, dynamic> toJson() => {
    'field': field,
    'old': oldValue,
    'new': newValue,
  };

  static FieldChange fromJson(Map<String, dynamic> json) => FieldChange(
    field: json['field'] as String,
    oldValue: json['old'],
    newValue: json['new'],
  );

  /// Compute list of changed fields between two data maps.
  static List<FieldChange> diff(
    Map<String, dynamic> oldData,
    Map<String, dynamic> newData, {
    List<String> ignoreKeys = const ['updated_at', 'created_at'],
  }) {
    final changes = <FieldChange>[];
    final allKeys = {...oldData.keys, ...newData.keys};
    for (final key in allKeys) {
      if (ignoreKeys.contains(key)) continue;
      final oldVal = oldData[key];
      final newVal = newData[key];
      // Deep comparison via JSON encoding for nested structures
      if (jsonEncode(oldVal) != jsonEncode(newVal)) {
        changes.add(FieldChange(field: key, oldValue: oldVal, newValue: newVal));
      }
    }
    return changes;
  }
}

// ---------------------------------------------------------------------------
// Audit entry model
// ---------------------------------------------------------------------------

class AuditEntry {
  final String id;
  final String action;
  final String type;
  final String userId;
  final String userName;
  final String? details;
  final String? ipAddress;
  final String? deviceId;
  final DateTime timestamp;
  // New: granular field tracking
  final String? entityId;
  final List<FieldChange> changedFields;

  AuditEntry({
    required this.id,
    required this.action,
    required this.type,
    required this.userId,
    required this.userName,
    this.details,
    this.ipAddress,
    this.deviceId,
    DateTime? timestamp,
    this.entityId,
    List<FieldChange>? changedFields,
  })  : timestamp = timestamp ?? DateTime.now(),
        changedFields = changedFields ?? [];

  bool get hasFieldChanges => changedFields.isNotEmpty;

  Map<String, dynamic> toJson() => {
    'id': id,
    'action': action,
    'type': type,
    'user_id': userId,
    'user_name': userName,
    'details': details,
    'ip_address': ipAddress,
    'device_id': deviceId,
    'timestamp': timestamp.toIso8601String(),
    'entity_id': entityId,
    'changed_fields': changedFields.map((c) => c.toJson()).toList(),
  };

  static AuditEntry fromJson(Map<String, dynamic> json) => AuditEntry(
    id: json['id'] as String,
    action: json['action'] as String,
    type: json['type'] as String,
    userId: json['user_id'] as String,
    userName: json['user_name'] as String,
    details: json['details'] as String?,
    ipAddress: json['ip_address'] as String?,
    deviceId: json['device_id'] as String?,
    timestamp: DateTime.parse(json['timestamp'] as String),
    entityId: json['entity_id'] as String?,
    changedFields: (json['changed_fields'] as List<dynamic>? ?? [])
        .map((e) => FieldChange.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

// ---------------------------------------------------------------------------
// Audit Service
// ---------------------------------------------------------------------------

class AuditService extends ChangeNotifier {
  final List<AuditEntry> _entries = [];
  Timer? _flushTimer;

  List<AuditEntry> get entries => List.unmodifiable(_entries);

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('audit_log');
    if (raw != null) {
      try {
        final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
        _entries.addAll(list.map(AuditEntry.fromJson));
      } catch (_) {}
    }
    _flushTimer = Timer.periodic(const Duration(minutes: 1), (_) => _flush());
  }

  /// Standard log without field diff.
  Future<void> log({
    required String action,
    required String type,
    required String userId,
    required String userName,
    String? details,
    String? ipAddress,
    String? deviceId,
    String? entityId,
  }) async {
    final entry = AuditEntry(
      id: '${DateTime.now().millisecondsSinceEpoch}_${userId}_${_entries.length}',
      action: action,
      type: type,
      userId: userId,
      userName: userName,
      details: details,
      ipAddress: ipAddress,
      deviceId: deviceId,
      entityId: entityId,
    );
    _addEntry(entry);
  }

  /// Log with granular field-level diff between oldData and newData.
  Future<void> logWithDiff({
    required String action,
    required String type,
    required String userId,
    required String userName,
    required String entityId,
    required Map<String, dynamic> oldData,
    required Map<String, dynamic> newData,
    String? details,
    String? deviceId,
  }) async {
    final changes = FieldChange.diff(oldData, newData);

    // Only record if something actually changed
    if (changes.isEmpty) return;

    final summary = changes.map((c) => c.field).join(', ');
    final entry = AuditEntry(
      id: '${DateTime.now().millisecondsSinceEpoch}_${userId}_${_entries.length}',
      action: action,
      type: type,
      userId: userId,
      userName: userName,
      details: details ?? 'Campos modificados: $summary',
      deviceId: deviceId,
      entityId: entityId,
      changedFields: changes,
    );
    _addEntry(entry);
  }

  void _addEntry(AuditEntry entry) {
    _entries.insert(0, entry);
    notifyListeners();
    _flush();
  }

  Future<void> _flush() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final maxEntries = prefs.getInt('audit_max_entries') ?? 5000;
      final slice = _entries.take(maxEntries).toList();
      await prefs.setString(
        'audit_log',
        jsonEncode(slice.map((e) => e.toJson()).toList()),
      );
    } catch (_) {}
  }

  /// Returns only entries that have field-level changes.
  List<AuditEntry> get entriesWithDiff =>
      _entries.where((e) => e.hasFieldChanges).toList();

  /// Returns all changes to a specific entity (form entry).
  List<AuditEntry> historyForEntity(String entityId) =>
      _entries.where((e) => e.entityId == entityId).toList();

  Future<void> clearAll() async {
    _entries.clear();
    notifyListeners();
    await _flush();
  }

  @override
  void dispose() {
    _flushTimer?.cancel();
    super.dispose();
  }
}
