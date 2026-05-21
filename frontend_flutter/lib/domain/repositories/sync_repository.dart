abstract class SyncRepository {
  Future<bool> synchronize();
  Future<DateTime?> getLastSyncTimestamp();
}
