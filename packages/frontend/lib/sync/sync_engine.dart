import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/logger.dart';
import '../data/database/database_provider.dart';
import '../data/database/app_database.dart';

final _log = getLogger('SyncEngine');

class SyncState {
  final bool isSyncing;
  final bool isOnline;
  final int syncCount;
  final int failedCount;
  final DateTime? lastSync;

  const SyncState({
    this.isSyncing = false,
    this.isOnline = false,
    this.syncCount = 0,
    this.failedCount = 0,
    this.lastSync,
  });

  SyncState copyWith({
    bool? isSyncing,
    bool? isOnline,
    int? syncCount,
    int? failedCount,
    DateTime? lastSync,
  }) {
    return SyncState(
      isSyncing: isSyncing ?? this.isSyncing,
      isOnline: isOnline ?? this.isOnline,
      syncCount: syncCount ?? this.syncCount,
      failedCount: failedCount ?? this.failedCount,
      lastSync: lastSync ?? this.lastSync,
    );
  }
}

class SyncEngine extends Notifier<SyncState> {
  Timer? _periodicTimer;
  AppDatabase? _db;

  @override
  SyncState build() {
    _db = ref.watch(databaseProvider);
    ref.onDispose(() {
      _periodicTimer?.cancel();
      _periodicTimer = null;
    });
    return const SyncState();
  }

  void startPeriodicSync({Duration interval = const Duration(minutes: 5)}) {
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(interval, (_) => synchronize());
    synchronize();
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
          .get(Uri.parse('$backendUrl/health'))
          .timeout(const Duration(seconds: 5));
      state = state.copyWith(isOnline: response.statusCode == 200);
    } catch (e) {
      state = state.copyWith(isOnline: false);
    }
    return state.isOnline;
  }

  Future<bool> synchronize() async {
    if (state.isSyncing) return false;
    state = state.copyWith(isSyncing: true);

    try {
      await checkOnline();
      if (!state.isOnline) {
        state = state.copyWith(isSyncing: false);
        return false;
      }

      if (_db == null) {
        state = state.copyWith(isSyncing: false, isOnline: false);
        return false;
      }

      final prefs = await SharedPreferences.getInstance();
      final deviceId = prefs.getString('device_id') ?? 'dev-unknown';
      final lastSync = prefs.getString('last_sync_timestamp') ?? '';
      final backendUrl = prefs.getString('backend_url') ?? 'http://localhost:8000';

      final queueItems = await _db!.getSyncQueue();

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
            await _db!.deleteQueueItem(id as int);
          }

          final updates = (resData['updates_to_pull'] as List?) ?? [];
          for (final update in updates) {
            final entity = update['entity'] as String;
            final itemData = update['data'] as Map<String, dynamic>;
            if (entity == 'form_entries') {
              final now = DateTime.now();
              await _db!.into(_db!.formEntries).insertOnConflictUpdate(
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
          state = state.copyWith(
            syncCount: state.syncCount + 1,
            lastSync: DateTime.now(),
          );
        }
      } else {
        state = state.copyWith(failedCount: state.failedCount + 1);
      }
    } catch (e, st) {
      state = state.copyWith(isOnline: false, failedCount: state.failedCount + 1);
      _log.error('Sync error', e, st);
    } finally {
      state = state.copyWith(isSyncing: false);
    }

    return state.isOnline;
  }
}

final syncEngineProvider = NotifierProvider<SyncEngine, SyncState>(SyncEngine.new);