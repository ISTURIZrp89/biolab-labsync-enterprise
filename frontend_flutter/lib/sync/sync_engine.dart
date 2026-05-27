import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../data/db.dart';
import '../services/audit_service.dart';
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

  final List<Map<String, dynamic>> _syncLog = [];

  SyncEngine({LocalDatabase? localDb})
      : _localDb = localDb ?? LocalDatabase.instance;

  bool get isSyncing => _isSyncing;
  bool get isOnline => _isOnline;
  DateTime? get lastSync => _lastSync;
  int get syncCount => _syncCount;
  int get failedCount => _failedCount;
  int get pendingCount => _pendingCount;
  List<Map<String, dynamic>> get syncLog => List.unmodifiable(_syncLog);

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

  void _logSync(String action, String status, Map<String, dynamic>? details) {
    _syncLog.insert(0, {
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'action': action,
      'status': status,
      'details': details,
    });
    if (_syncLog.length > 100) _syncLog.removeLast();
  }

  Future<bool> checkOnline() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final backendUrl = prefs.getString('backend_url') ?? 'http://localhost:8000';
      final response = await http.get(
        Uri.parse('$backendUrl/api/health'),
      ).timeout(const Duration(seconds: 5));
      final wasOffline = !_isOnline;
      _isOnline = response.statusCode == 200;
      if (wasOffline && _isOnline) {
        _logSync('reconnect', 'success', {'message': 'Conexión restablecida'});
        synchronize();
      }
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
          'device_id': deviceId,
          'version': data['version'] ?? 1,
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
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final resData = jsonDecode(response.body);
        if (resData['success'] == true) {
          final db = await _localDb.database;

          final processed = (resData['processed_ids'] as List?) ?? [];
          final conflicts = (resData['conflicts'] as List?) ?? [];
          final rejected = (resData['rejected'] as List?) ?? [];

          for (var id in processed) {
            await _localDb.deleteQueueItem(id.toString());
          }

          for (final conflict in conflicts) {
            final entityId = conflict['entity_id'] as String?;
            final serverVersion = conflict['server_version'] as int? ?? 0;
            final localVersion = conflict['local_version'] as int? ?? 0;
            final resolution = conflict['resolution'] as String? ?? 'server_wins';
            final changedFields = conflict['changed_fields'] as List? ?? [];
            final isRejected = conflict['rejected'] == true;

            if (isRejected) {
              // Month-closure rejection — log locally but don't apply data
              final rejUuid = const Uuid().v4();
              await db.insert('audit_log', {
                'id': rejUuid,
                'action': 'SYNC_REJECTED_MONTH_CLOSED',
                'user_id': 'system',
                'device_id': deviceId,
                'timestamp': DateTime.now().toUtc().toIso8601String(),
                'details_json': jsonEncode({
                  'entity_id': entityId,
                  'reason': conflict['reason'] ?? 'Mes cerrado',
                }),
                'entity_id': entityId,
                'changed_fields_json': '[]',
              });
              continue;
            }

            if (resolution == 'server_wins' && conflict['data'] != null) {
              final itemData = conflict['data'] as Map<String, dynamic>;
              final entity = conflict['entity'] as String? ?? 'form_entries';
              if (entity == 'form_entries') {
                final existing = await db.query('form_entries',
                  where: 'id = ?', whereArgs: [itemData['id']]);
                if (existing.isNotEmpty) {
                  final localVer = existing.first['version'] as int? ?? 0;
                  if ((itemData['version'] as int? ?? 0) <= localVer) {
                    await _localDb.deleteQueueItem(itemData['id'] as String);
                    continue;
                  }
                }
                await db.insert('form_entries', {
                  'id': itemData['id'],
                  'module': itemData['module'],
                  'date': itemData['date'],
                  'user_id': itemData['user_id'],
                  'device_id': itemData['device_id'],
                  'version': itemData['version'],
                  'data_json': jsonEncode(itemData['data']),
                  'checksum': itemData['checksum'] ?? '',
                  'status': itemData['status'],
                  'created_at': itemData['created_at'],
                  'updated_at': itemData['updated_at'],
                }, conflictAlgorithm: ConflictAlgorithm.fail);
              }
            }

            // Persist field-level conflict audit
            final uuid = const Uuid().v4();
            await db.insert('audit_log', {
              'id': uuid,
              'action': 'SYNC_CONFLICT',
              'user_id': 'system',
              'device_id': deviceId,
              'timestamp': DateTime.now().toUtc().toIso8601String(),
              'details_json': jsonEncode({
                'entity_id': entityId,
                'server_version': serverVersion,
                'local_version': localVersion,
                'resolution': resolution,
                'entity': conflict['entity'],
              }),
              'entity_id': entityId,
              'changed_fields_json': jsonEncode(changedFields),
            });
          }

          // NOTE: rejections from closed months are now handled inside the
          // conflict loop above (rejected == true). This legacy block handles
          // any remaining explicit rejection items from older servers.
          for (final rejection in (resData['rejected'] as List? ?? [])) {
            final entityId = rejection['entity_id'] as String?;
            final reason = rejection['reason'] as String? ?? 'unknown';
            final rejUuid = const Uuid().v4();
            await db.insert('audit_log', {
              'id': rejUuid,
              'action': 'SYNC_REJECTED',
              'user_id': 'system',
              'device_id': deviceId,
              'timestamp': DateTime.now().toUtc().toIso8601String(),
              'details_json': jsonEncode({'entity_id': entityId, 'reason': reason}),
              'entity_id': entityId,
              'changed_fields_json': '[]',
            });
          }

          int pulled = 0;
          for (var update in (resData['updates_to_pull'] as List?) ?? []) {
            final entity = update['entity'] as String;
            final itemData = update['data'] as Map<String, dynamic>;
            final remoteVersion = itemData['version'] as int? ?? 0;

            if (entity == 'form_entries') {
              final existing = await db.query('form_entries',
                where: 'id = ?',
                whereArgs: [itemData['id']],
              );
              if (existing.isNotEmpty) {
                final localVersion = (existing.first['version'] as int?) ?? 0;
                if (remoteVersion <= localVersion) continue;
              }
              await db.insert('form_entries', {
                'id': itemData['id'],
                'module': itemData['module'],
                'date': itemData['date'],
                'user_id': itemData['user_id'],
                'device_id': itemData['device_id'],
                'version': remoteVersion,
                'data_json': jsonEncode(itemData['data']),
                'checksum': itemData['checksum'] ?? '',
                'status': itemData['status'],
                'created_at': itemData['created_at'],
                'updated_at': itemData['updated_at'],
              }, conflictAlgorithm: ConflictAlgorithm.fail);
              pulled++;
            } else if (entity == 'day_closures') {
              await db.insert('day_closures', {
                'id': itemData['id'],
                'date': itemData['date'],
                'status': itemData['status'],
                'closed_by': itemData['closed_by'],
                'closed_at': itemData['closed_at'],
                'notes': itemData['notes'],
                'reopen_log_json': jsonEncode(itemData['reopen_log'] ?? []),
              }, conflictAlgorithm: ConflictAlgorithm.replace);
              pulled++;
            } else if (entity == 'month_closures') {
              // Administrative month closure pulled from server
              await db.insert('month_closures', {
                'id': itemData['id'],
                'year': itemData['year'],
                'month': itemData['month'],
                'status': itemData['status'],
                'closed_by': itemData['closed_by'],
                'closed_at': itemData['closed_at'],
                'notes': itemData['notes'],
                'days_total': itemData['days_total'] ?? 30,
                'days_closed': itemData['days_closed'] ?? 0,
                'reopen_log_json': jsonEncode(itemData['reopen_log'] ?? []),
              }, conflictAlgorithm: ConflictAlgorithm.replace);
              pulled++;
            }
          }

          await prefs.setString('last_sync_timestamp', resData['server_time'] ?? DateTime.now().toUtc().toIso8601String());
          _lastSync = DateTime.now();
          _syncCount++;
          _isOnline = true;

          _logSync('sync_complete', 'success', {
            'processed': processed.length,
            'conflicts': conflicts.length,
            'rejected': rejected.length,
            'pulled': pulled,
          });
        }
      } else {
        _logSync('sync_error', 'fail', {'status_code': response.statusCode, 'body': response.body.substring(0, min(response.body.length, 200))});
        _failedCount++;
      }
    } catch (e) {
      _isOnline = false;
      _failedCount++;
      _logSync('sync_exception', 'fail', {'error': e.toString()});
    } finally {
      _isSyncing = false;
      _safeNotify();
    }

    return _isOnline;
  }

  Future<bool> retryFailed() async {
    final wasFailed = _failedCount > 0;
    if (wasFailed) {
      _failedCount = 0;
      return synchronize();
    }
    return true;
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
        _logSync('lan_sync_fail', 'fail', {'peer': peer.hostname, 'error': e.toString()});
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
        body: jsonEncode({'entries': entries, 'device_id': 'lan-sync-${DateTime.now().millisecondsSinceEpoch}'}),
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
                  final remoteId = entry['id'] as String?;
                  final remoteVersion = entry['version'] as int? ?? 0;
                  if (remoteId != null) {
                    final existing = await db.query('form_entries',
                      where: 'id = ?',
                      whereArgs: [remoteId],
                    );
                    if (existing.isNotEmpty) {
                      final localVersion = (existing.first['version'] as int?) ?? 0;
                      if (remoteVersion <= localVersion) continue;
                    }
                  }
                  await db.insert('form_entries', {
                    'id': entry['id'],
                    'module': entry['module'] ?? '',
                    'date': entry['date'] ?? '',
                    'user_id': entry['user_id'] ?? '',
                    'device_id': entry['device_id'] ?? '',
                    'version': remoteVersion,
                    'data_json': entry['data_json'] is String
                        ? entry['data_json']
                        : jsonEncode(entry['data_json'] ?? {}),
                    'status': entry['status'] ?? 'pending',
                    'created_at': entry['created_at'] ?? '',
                    'updated_at': entry['updated_at'] ?? '',
                  }, conflictAlgorithm: ConflictAlgorithm.replace);
                  pulledCount++;
                } catch (e) {
                  debugPrint('SyncEngine: Pull insert error: $e');
                }
              }

              debugPrint('SyncEngine: Pulled $pulledCount entries from ${peer.hostname}');
              _syncCount++;
              _lastSync = DateTime.now();
              _logSync('lan_sync_complete', 'success', {'peer': peer.hostname, 'pushed': inserted, 'pulled': pulledCount});
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

int min(int a, int b) => a < b ? a : b;
