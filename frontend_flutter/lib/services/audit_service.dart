import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

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
  }) : timestamp = timestamp ?? DateTime.now();

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
  );
}

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

  Future<void> log({
    required String action,
    required String type,
    required String userId,
    required String userName,
    String? details,
    String? ipAddress,
    String? deviceId,
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
    );
    _entries.insert(0, entry);
    notifyListeners();
    await _flush();
  }

  Future<void> _flush() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final maxEntries = prefs.getInt('audit_max_entries') ?? 5000;
      final slice = _entries.take(maxEntries).toList();
      await prefs.setString('audit_log', jsonEncode(slice.map((e) => e.toJson()).toList()));
    } catch (_) {}
  }

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
