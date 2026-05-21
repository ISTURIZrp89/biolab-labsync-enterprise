import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import '../data/db.dart';

class SyncEngine extends ChangeNotifier {
  final String backendUrl;
  final LocalDatabase _localDb;
  bool _isSyncing = false;
  bool _isOnline = false;
  DateTime? _lastSync;
  int _syncCount = 0;
  int _failedCount = 0;
  int _pendingCount = 0;
  List<String> _conflicts = [];
  Timer? _periodicTimer;

  SyncEngine({this.backendUrl = "http://localhost:8000", LocalDatabase? localDb})
      : _localDb = localDb ?? LocalDatabase.instance;

  bool get isSyncing => _isSyncing;
  bool get isOnline => _isOnline;
  DateTime? get lastSync => _lastSync;
  int get syncCount => _syncCount;
  int get failedCount => _failedCount;
  int get pendingCount => _pendingCount;
  List<String> get conflicts => _conflicts;

  void startPeriodicSync({Duration interval = const Duration(minutes: 5)}) {
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(interval, (_) => synchronize());
  }

  void stopPeriodicSync() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
  }

  Future<bool> checkOnline() async {
    try {
      final response = await http.get(
        Uri.parse('$backendUrl/api/health'),
      ).timeout(const Duration(seconds: 5));
      _isOnline = response.statusCode == 200;
      notifyListeners();
      return _isOnline;
    } catch (e) {
      _isOnline = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> synchronize({int maxRetries = 3}) async {
    if (_isSyncing) return false;

    final online = await checkOnline();
    if (!online) return false;

    _isSyncing = true;
    notifyListeners();

    for (int attempt = 0; attempt < maxRetries; attempt++) {
      if (attempt > 0) {
        await Future.delayed(Duration(seconds: attempt * 2));
      }
      if (await _doSync()) {
        _isSyncing = false;
        _isOnline = true;
        notifyListeners();
        return true;
      }
    }

    _isSyncing = false;
    _isOnline = false;
    _failedCount++;
    notifyListeners();
    return false;
  }

  Future<bool> _doSync() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final deviceId = prefs.getString('device_id') ?? 'dev-unknown';
      final lastSync = prefs.getString('last_sync_timestamp') ?? '';

      final queueItems = await _localDb.getSyncQueue();
      _pendingCount = queueItems.length;

      final List<Map<String, dynamic>> mappedQueue = queueItems.map((item) {
        Map<String, dynamic> data = {};
        try {
          data = jsonDecode(item['data_json'] as String);
        } catch (_) {}
        return {
          'id': item['id'],
          'action': item['action'],
          'entity': item['entity'],
          'entity_id': item['entity_id'],
          'data': data,
          'timestamp': item['timestamp'],
        };
      }).toList();

      final syncPayload = {
        'device_id': deviceId,
        'queue': mappedQueue,
        'last_sync_timestamp': lastSync,
      };

      final response = await http.post(
        Uri.parse('$backendUrl/api/sync'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(syncPayload),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final resData = jsonDecode(response.body);
        if (resData['success'] == true) {
          final db = await _localDb.database;

          final List<dynamic> processedIds = resData['processed_ids'];
          for (var localQueueId in processedIds) {
            await _localDb.deleteQueueItem(localQueueId.toString());
          }

          final List<dynamic> updates = resData['updates_to_pull'];
          if (updates.isNotEmpty) {
            await db.transaction((txn) async {
              for (var update in updates) {
                final entity = update['entity'] as String;
                final itemData = update['data'] as Map<String, dynamic>;
                if (entity == 'form_entries') {
                  await txn.insert('form_entries', {
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
                  await txn.insert('day_closures', {
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
            });
          }

          final List<dynamic> conflictList = resData['conflicts'] ?? [];
          if (conflictList.isNotEmpty) {
            _conflicts = conflictList.map((c) {
              final data = c as Map<String, dynamic>;
              return '${data['entity']}/${data['entity_id']}: v${data['local_version']} -> v${data['incoming_version']}';
            }).toList();
          }

          final String serverTime = resData['server_time'];
          await prefs.setString('last_sync_timestamp', serverTime);
          _lastSync = DateTime.now();
          _syncCount++;

          final remainingQueue = await _localDb.getSyncQueue();
          _pendingCount = remainingQueue.length;

          return true;
        }
      }
      return false;
    } catch (e) {
      debugPrint("Sync error: $e");
      return false;
    }
  }

  Future<int> getPendingCount() async {
    final queue = await _localDb.getSyncQueue();
    _pendingCount = queue.length;
    notifyListeners();
    return _pendingCount;
  }

  Future<void> clearConflicts() async {
    _conflicts.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    stopPeriodicSync();
    super.dispose();
  }
}
