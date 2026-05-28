import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DiscoveredPeer {
  final String ip;
  final int port;
  final String hostname;
  final String deviceId;

  DiscoveredPeer({
    required this.ip,
    required this.port,
    required this.hostname,
    required this.deviceId,
  });
}

class LanDiscoveryService {
  static const int _port = 42069;
  RawDatagramSocket? _socket;
  bool _isRunning = false;
  final List<DiscoveredPeer> _peers = [];

  bool get isRunning => _isRunning;
  List<DiscoveredPeer> get peers => List.unmodifiable(_peers);

  Future<void> startDiscovery({int port = 8765}) async {
    try {
      _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, _port);
      _socket!.broadcastEnabled = true;
      _isRunning = true;

      final data = utf8.encode('BIOLAB_DISCOVERY');
      _socket!.send(data, InternetAddress('255.255.255.255'), _port);

      _socket!.listen((event) {
        if (event == RawSocketEvent.read) {
          final packet = _socket!.receive();
          if (packet != null) {
            final msg = utf8.decode(packet.data);
            if (msg.startsWith('BIOLAB_PEER:')) {
              final parts = msg.split(':');
              if (parts.length >= 4) {
                _peers.add(DiscoveredPeer(
                  ip: packet.address.address,
                  port: int.tryParse(parts[2]) ?? port,
                  hostname: parts[1],
                  deviceId: parts[3],
                ));
              }
            }
          }
        }
      });
    } catch (e) {
      debugPrint('LAN Discovery error: $e');
      _isRunning = false;
    }
  }

  void dispose() {
    _socket?.close();
    _socket = null;
    _isRunning = false;
    _peers.clear();
  }
}

final lanDiscoveryServiceProvider = Provider<LanDiscoveryService>((ref) {
  return LanDiscoveryService();
});
