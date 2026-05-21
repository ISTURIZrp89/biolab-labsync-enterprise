import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import '../data/db.dart';

class SyncEngine extends ChangeNotifier {
  final LocalDatabase _localDb;
  bool _isSyncing = false;
  bool _isOnline = false;
  DateTime? _lastSync;
  int _syncCount = 0;
  int _failedCount = 0;
  int _pendingCount = 0;
  bool _disposed = false;
  Timer? _periodicTimer;

  SyncEngine({LocalDatabase? localDb})
      : _localDb = localDb ?? LocalDatabase.instance;

  bool get isSyncing => _isSyncing;
  bool get isOnline => _isOnline;
  DateTime? get lastSync => _lastSync;
  int get syncCount => _syncCount;
  int get failedCount => _failedCount;
  int get pendingCount => _pendingCount;

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  void startPeriodicSync({Duration interval = const Duration(minutes: 5)}) {
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(interval, (_) {
      synchronize();
    });
  }

  void stopPeriodicSync() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
  }

  Future<bool> checkOnline() async {
    try {
      final response = await http.get(
        Uri.parse('http://localhost:8000/api/health'),
      ).timeout(const Duration(seconds: 3));
      _isOnline = response.statusCode == 200;
    } catch (e) {
      _isOnline = false;
    }
    _safeNotify();
    return _isOnline;
  }

  Future<bool> synchronize() async {
    if (_isSyncing) return false;

    _isSyncing = true;
    _safeNotify();

    try {
      final online = await checkOnline();
      if (!online) {
        _isSyncing = false;
        _safeNotify();
        return false;
      }

      final prefs = await SharedPreferences.getInstance();
      final deviceId = prefs.getString('device_id') ?? 'dev-unknown';
      final lastSync = prefs.getString('last_sync_timestamp') ?? '';

      final queueItems = await _localDb.getSyncQueue();
      _pendingCount = queueItems.length;

      final mappedQueue = <Map<String, dynamic>>[];
      for (final item in queueItems) {
        Map<String, dynamic> data = {};
        try {
          data = jsonDecode(item['data_json'] as String);
        } catch (_) {}
        mappedQueue.add({
          'id': item['id'],
          'action': item['action'],
          'entity': item['entity'],
          'entity_id': item['entity_id'],
          'data': data,
          'timestamp': item['timestamp'],
        });
      }

      final response = await http.post(
        Uri.parse('http://localhost:8000/api/sync'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'device_id': deviceId,
          'queue': mappedQueue,
          'last_sync_timestamp': lastSync,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final resData = jsonDecode(response.body);
        if (resData['success'] == true) {
          final db = await _localDb.database;

          for (var id in (resData['processed_ids'] as List)) {
            await _localDb.deleteQueueItem(id.toString());
          }

          for (var update in (resData['updates_to_pull'] as List)) {
            final entity = update['entity'] as String;
            final itemData = update['data'] as Map<String, dynamic>;
            if (entity == 'form_entries') {
              await db.insert('form_entries', {
                'id': itemData['id'],
                'module': itemData['module'],
                'date': itemData['date'],
                'user_id': itemData['user_id'],
                'device_id': itemData['device_id'],
                'version': itemData['version'],
                'data_json': jsonEncode(itemData['data']),
                'status': itemData['status'],
                'created_at': itemData['created_at'],
                'updated_at': itemData['updated_at'],
              }, conflictAlgorithm: ConflictAlgorithm.replace);
            } else if (entity == 'day_closures') {
              await db.insert('day_closures', {
                'id': itemData['id'],
                'date': itemData['date'],
                'status': itemData['status'],
                'closed_by': itemData['closed_by'],
                'closed_at': itemData['closed_at'],
                'notes': itemData['notes'],
                'reopen_log_json': jsonEncode(itemData['reopen_log']),
              }, conflictAlgorithm: ConflictAlgorithm.replace);
            }
          }

          await prefs.setString('last_sync_timestamp', resData['server_time']);
          _lastSync = DateTime.now();
          _syncCount++;
          _isOnline = true;
        }
      }
    } catch (e) {
      _isOnline = false;
      _failedCount++;
    } finally {
      _isSyncing = false;
      _safeNotify();
    }

    return _isOnline;
  }

  Future<int> getPendingCount() async {
    try {
      final queue = await _localDb.getSyncQueue();
      _pendingCount = queue.length;
      _safeNotify();
      return _pendingCount;
    } catch (e) {
      return 0;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    stopPeriodicSync();
    super.dispose();
  }
}
