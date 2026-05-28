import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/repositories/sync_repository.dart';

part 'sync_engine.g.dart';

class SyncEngine {
  final SyncRepository _repo;
  Timer? _timer;

  SyncEngine(this._repo);

  void start(Duration interval) {
    _timer = Timer.periodic(interval, (_) => _sync());
  }

  Future<void> _sync() async {
    // Pull changes from server
    // Push local changes from SyncQueue
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }
}

@riverpod
SyncEngine syncEngine(SyncEngineRef ref) {
  final repo = ref.watch(syncRepositoryProvider);
  return SyncEngine(repo);
}
