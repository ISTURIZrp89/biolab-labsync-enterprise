import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

part 'sync_repository.g.dart';

class SyncRepository {
  final WebSocketChannel _channel;

  SyncRepository(this._channel);

  void sendChanges(List<Map<String, dynamic>> changes) {
    _channel.sink.add({'changes': changes});
  }

  Stream<dynamic> get changes => _channel.stream;

  void dispose() {
    _channel.sink.close();
  }
}

@riverpod
SyncRepository syncRepository(SyncRepositoryRef ref) {
  final channel = WebSocketChannel.connect(
    Uri.parse('ws://localhost:8000/sync/ws?device_id=desktop-01'),
  );
  return SyncRepository(channel);
}
