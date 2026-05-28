import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../data/database/database_provider.dart';
import '../data/database/app_database.dart';

class SyncEngine {
  Timer? _periodicTimer;
  bool _isSyncing = false;
  bool _isOnline = false;
  int _syncCount = 0;
  int _failedCount = 0;

  final AppDatabase _db;

  SyncEngine(this._db);

  bool get isOnline => _isOnline;
  bool get isSyncing => _isSyncing;
  int get syncCount => _syncCount;
  int get failedCount => _failedCount;

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
      final prefs = await SharedPreferences.getInstance();
      final backendUrl = prefs.getString('backend_url') ?? 'http://localhost:8000';
      final response = await http
          .get(Uri.parse('$backendUrl/api/health'))
          .timeout(const Duration(seconds: 5));
      _isOnline = response.statusCode == 200;
    } catch (e) {
      _isOnline = false;
    }
    return _isOnline;
  }

  Future<bool> synchronize() async {
    if (_isSyncing) return false;
    _isSyncing = true;

    try {
      await checkOnline();
      if (!_isOnline) {
        _isSyncing = false;
        return false;
      }

      final prefs = await SharedPreferences.getInstance();
      final deviceId = prefs.getString('device_id') ?? 'dev-unknown';
      final lastSync = prefs.getString('last_sync_timestamp') ?? '';
      final backendUrl = prefs.getString('backend_url') ?? 'http://localhost:8000';

      final queueItems = await _db.getSyncQueue();

      final mappedQueue = <Map<String, dynamic>>[];
      for (final item in queueItems) {
        Map<String, dynamic> data = {};
        try {
          data = jsonDecode(item.dataJson);
        } catch (_) {}
        mappedQueue.add({
          'id': item.id,
          'action': item.action,
          'entity': item.entity,
          'entity_id': item.entityId,
          'data': data,
          'timestamp': item.timestamp,
        });
      }

      final response = await http
          .post(
            Uri.parse('$backendUrl/api/sync'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'device_id': deviceId,
              'queue': mappedQueue,
              'last_sync_timestamp': lastSync,
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final resData = jsonDecode(response.body);
        if (resData['success'] == true) {
          final processed = (resData['processed_ids'] as List?) ?? [];
          for (final id in processed) {
            await _db.deleteQueueItem(id as int);
          }

          final updates = (resData['updates_to_pull'] as List?) ?? [];
          for (final update in updates) {
            final entity = update['entity'] as String;
            final itemData = update['data'] as Map<String, dynamic>;
            if (entity == 'form_entries') {
              await _db.into(_db.formEntries).insertOnConflictUpdate(
                    FormEntriesCompanion.insert(
                      id: itemData['id'],
                      module: itemData['module'] ?? '',
                      date: itemData['date'] ?? '',
                      userId: Value(itemData['user_id']),
                      deviceId: Value(itemData['device_id']),
                      version: itemData['version'] ?? 1,
                      dataJson: jsonEncode(itemData['data'] ?? {}),
                      status: itemData['status'] ?? 'saved',
                    ),
                  );
            }
          }

          await prefs.setString(
              'last_sync_timestamp', resData['server_time'] ?? DateTime.now().toUtc().toIso8601String());
          _syncCount++;
        }
      } else {
        _failedCount++;
      }
    } catch (e) {
      _isOnline = false;
      _failedCount++;
      debugPrint('Sync error: $e');
    } finally {
      _isSyncing = false;
    }

    return _isOnline;
  }

  void dispose() {
    stopPeriodicSync();
  }
}

final syncEngineProvider = Provider<SyncEngine>((ref) {
  final db = ref.watch(databaseProvider);
  return SyncEngine(db);
});
