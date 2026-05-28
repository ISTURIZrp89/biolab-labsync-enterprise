import 'dart:io';
import 'dart:convert';

class LanDiscoveryService {
  static const int _port = 42069;
  RawDatagramSocket? _socket;

  Future<void> startDiscovery() async {
    _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, _port);
    _socket!.broadcastEnabled = true;

    final data = utf8.encode('BIOLAB_DISCOVERY');
    _socket!.send(data, InternetAddress('255.255.255.255'), _port);

    _socket!.listen((event) {
      if (event == RawSocketEvent.read) {
        final packet = _socket!.receive();
        if (packet != null) {
          final msg = utf8.decode(packet.data);
          if (msg.startsWith('BIOLAB_PEER:')) {
            // Parse peer info
          }
        }
      }
    });
  }

  void dispose() {
    _socket?.close();
    _socket = null;
  }
}
