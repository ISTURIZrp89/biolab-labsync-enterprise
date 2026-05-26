import 'dart:convert';
import 'dart:io';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MemoryEntry {
  final String id;
  final String key;
  final String value;
  final String nodeId;
  final int version;
  final DateTime timestamp;
  final String checksum;

  MemoryEntry({
    required this.id,
    required this.key,
    required this.value,
    required this.nodeId,
    this.version = 1,
    DateTime? timestamp,
    String? checksum,
  }) : timestamp = timestamp ?? DateTime.now(),
       checksum = checksum ?? _computeChecksum(value);

  static String _computeChecksum(String v) {
    final bytes = utf8.encode(v);
    int hash = 0;
    for (final b in bytes) { hash = ((hash << 5) - hash) + b; }
    return hash.toRadixString(16);
  }

  MemoryEntry incrementVersion() => MemoryEntry(
    id: id, key: key, value: value, nodeId: nodeId,
    version: version + 1, timestamp: DateTime.now(),
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'key': key, 'value': value, 'nodeId': nodeId,
    'version': version, 'timestamp': timestamp.toIso8601String(),
    'checksum': checksum,
  };
}

class SharedMemory extends ChangeNotifier {
  final Map<String, MemoryEntry> _store = {};
  final Queue<Map<String, dynamic>> _taskQueue = Queue();
  String? _leaderNodeId;
  bool _locked = false;
  String _lockHolder = '';

  static const _memoryKey = 'ai_shared_memory';
  static const _syncPathKey = 'ai_sync_path';

  Map<String, MemoryEntry> get store => Map.unmodifiable(_store);
  int get entryCount => _store.length;
  bool get isLocked => _locked;
  String? get leaderNodeId => _leaderNodeId;
  int get pendingTasks => _taskQueue.length;

  set leaderNodeId(String? id) { _leaderNodeId = id; notifyListeners(); }

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_memoryKey) ?? [];
      for (final s in raw) {
        try {
          final map = jsonDecode(s) as Map<String, dynamic>;
          final entry = MemoryEntry(
            id: map['id'] as String, key: map['key'] as String,
            value: map['value'] as String, nodeId: map['nodeId'] as String,
            version: map['version'] as int? ?? 1,
            timestamp: DateTime.parse(map['timestamp'] as String),
          );
          _store[entry.key] = entry;
        } catch (_) {}
      }
    } catch (_) {}
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = _store.values.map((e) => jsonEncode(e.toJson())).toList();
      await prefs.setStringList(_memoryKey, raw);
    } catch (_) {}
  }

  bool acquireLock(String nodeId) {
    if (_locked && _lockHolder != nodeId) return false;
    _locked = true;
    _lockHolder = nodeId;
    notifyListeners();
    return true;
  }

  void releaseLock(String nodeId) {
    if (_lockHolder == nodeId) {
      _locked = false;
      _lockHolder = '';
      notifyListeners();
    }
  }

  Future<bool> setEntry(String key, String value, String nodeId) async {
    if (_locked && _lockHolder != nodeId) {
      _taskQueue.add({'action': 'set', 'key': key, 'value': value, 'nodeId': nodeId});
      return false;
    }
    final existing = _store[key];
    final entry = MemoryEntry(
      id: 'mem_${DateTime.now().millisecondsSinceEpoch}',
      key: key, value: value, nodeId: nodeId,
      version: (existing?.version ?? 0) + 1,
    );
    _store[key] = entry;
    await _save();
    notifyListeners();
    return true;
  }

  MemoryEntry? getEntry(String key) => _store[key];

  List<MemoryEntry> getEntriesByPrefix(String prefix) {
    return _store.values.where((e) => e.key.startsWith(prefix)).toList();
  }

  Future<void> consolidateFromNode(String nodeId) async {
    if (nodeId != _leaderNodeId) return;
    if (!acquireLock(nodeId)) return;
    try {
      await _save();
    } finally {
      releaseLock(nodeId);
    }
  }

  Future<void> syncToDisk() async {
    final prefs = await SharedPreferences.getInstance();
    final syncPath = prefs.getString(_syncPathKey);
    if (syncPath == null || syncPath.isEmpty) return;

    try {
      final dir = Directory(syncPath);
      if (!await dir.exists()) await dir.create(recursive: true);
      final file = File('$syncPath/ai_memory.json');
      final data = {
        'version': 1,
        'leader': _leaderNodeId,
        'entries': _store.values.map((e) => e.toJson()).toList(),
        'syncedAt': DateTime.now().toIso8601String(),
      };
      await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
    } catch (_) {}
  }

  Future<void> setSyncPath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_syncPathKey, path);
  }

  String? getSyncPath() {
    final prefs = SharedPreferences.getInstance();
    return null;
  }

  Future<String?> getSyncPathAsync() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_syncPathKey);
  }

  Future<void> processQueue() async {
    while (_taskQueue.isNotEmpty && !_locked) {
      final task = _taskQueue.removeFirst();
      if (task['action'] == 'set') {
        await setEntry(
          task['key'] as String,
          task['value'] as String,
          task['nodeId'] as String,
        );
      }
    }
  }
}
