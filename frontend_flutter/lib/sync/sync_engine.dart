import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import '../data/db.dart';
import 'lan_discovery_service.dart';

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
      syncWithLanPeers();
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

      final response = await http.get(
        Uri.parse('$backendUrl/api/health'),
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
      final backendUrl = prefs.getString('backend_url') ?? 'http://localhost:8000';

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
        Uri.parse('$backendUrl/api/sync'),
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

  Future<List<DiscoveredPeer>> syncWithLanPeers({List<DiscoveredPeer>? peers}) async {
    final syncedPeers = <DiscoveredPeer>[];
    if (peers == null || peers.isEmpty) return syncedPeers;

    final prefs = await SharedPreferences.getInstance();
    final lanEnabled = prefs.getBool('lan_sync_enabled') ?? false;
    if (!lanEnabled) return syncedPeers;

    final queueItems = await _localDb.getSyncQueue();
    if (queueItems.isEmpty) return syncedPeers;

    for (final peer in peers) {
      try {
        final success = await _syncWithPeer(peer, queueItems);
        if (success) syncedPeers.add(peer);
      } catch (e) {
        debugPrint('SyncEngine: LAN sync failed for ${peer.hostname}: $e');
      }
    }

    return syncedPeers;
  }

  Future<bool> _syncWithPeer(DiscoveredPeer peer, List<Map<String, dynamic>> queueItems) async {
    try {
      final entries = <Map<String, dynamic>>[];
      for (final item in queueItems) {
        Map<String, dynamic> data = {};
        try {
          data = jsonDecode(item['data_json'] as String);
        } catch (_) {}

        if (item['entity'] == 'form_entries') {
          entries.add({
            'id': item['entity_id'],
            'module': data['module'] ?? '',
            'date': data['date'] ?? '',
            'user_id': data['user_id'] ?? '',
            'device_id': data['device_id'] ?? '',
            'version': data['version'] ?? 1,
            'data_json': item['data_json'],
            'status': data['status'] ?? 'pending',
            'created_at': item['timestamp'],
            'updated_at': item['timestamp'],
          });
        }
      }

      if (entries.isEmpty) return false;

      final url = 'http://${peer.ip}:${peer.port}/sync/push';
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'entries': entries}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final resData = jsonDecode(response.body);
        if (resData['success'] == true) {
          final inserted = resData['inserted'] as int? ?? 0;
          debugPrint('SyncEngine: Pushed $inserted entries to ${peer.hostname}');

          final pullUrl = 'http://${peer.ip}:${peer.port}/sync/pull';
          final pullResponse = await http.get(
            Uri.parse(pullUrl),
          ).timeout(const Duration(seconds: 10));

          if (pullResponse.statusCode == 200) {
            final pullData = jsonDecode(pullResponse.body);
            if (pullData['success'] == true) {
              final remoteEntries = pullData['entries'] as List? ?? [];
              final db = await _localDb.database;
              int pulledCount = 0;

              for (final entry in remoteEntries) {
                try {
                  await db.insert('form_entries', {
                    'id': entry['id'],
                    'module': entry['module'] ?? '',
                    'date': entry['date'] ?? '',
                    'user_id': entry['user_id'] ?? '',
                    'device_id': entry['device_id'] ?? '',
                    'version': entry['version'] ?? 1,
                    'data_json': entry['data_json'] is String
                        ? entry['data_json']
                        : jsonEncode(entry['data_json'] ?? {}),
                    'status': entry['status'] ?? 'pending',
                    'created_at': entry['created_at'] ?? '',
                    'updated_at': entry['updated_at'] ?? '',
                  }, conflictAlgorithm: ConflictAlgorithm.ignore);
                  pulledCount++;
                } catch (e) {
                  debugPrint('SyncEngine: Pull insert error: $e');
                }
              }

              debugPrint('SyncEngine: Pulled $pulledCount entries from ${peer.hostname}');
              _syncCount++;
              _lastSync = DateTime.now();
            }
          }

          return true;
        }
      }
    } catch (e) {
      debugPrint('SyncEngine: LAN peer sync error (${peer.hostname}): $e');
    }

    return false;
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
