import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/logger.dart';

final _log = getLogger('LanDiscovery');

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

class LanDiscoveryState {
  final bool isRunning;
  final List<DiscoveredPeer> peers;

  const LanDiscoveryState({this.isRunning = false, this.peers = const []});

  LanDiscoveryState copyWith({bool? isRunning, List<DiscoveredPeer>? peers}) {
    return LanDiscoveryState(
      isRunning: isRunning ?? this.isRunning,
      peers: peers ?? this.peers,
    );
  }
}

class LanDiscoveryService extends Notifier<LanDiscoveryState> {
  RawDatagramSocket? _socket;

  @override
  LanDiscoveryState build() {
    ref.onDispose(() {
      _socket?.close();
      _socket = null;
    });
    return const LanDiscoveryState();
  }

  Future<void> startDiscovery({int port = 8765}) async {
    try {
      _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 42069);
      final socket = _socket;
      if (socket == null) return;

      socket.broadcastEnabled = true;
      state = state.copyWith(isRunning: true);

      final data = utf8.encode('BIOLAB_DISCOVERY');
      socket.send(data, InternetAddress('255.255.255.255'), 42069);

      socket.listen((event) {
        if (event == RawSocketEvent.read) {
          final packet = socket.receive();
          if (packet != null) {
            final msg = utf8.decode(packet.data);
            if (msg.startsWith('BIOLAB_PEER:')) {
              final parts = msg.split(':');
              if (parts.length >= 4) {
                final newPeer = DiscoveredPeer(
                  ip: packet.address.address,
                  port: int.tryParse(parts[2]) ?? port,
                  hostname: parts[1],
                  deviceId: parts[3],
                );
                final existingIds = state.peers.map((p) => p.deviceId).toSet();
                if (!existingIds.contains(newPeer.deviceId)) {
                  state = state.copyWith(peers: [...state.peers, newPeer]);
                }
              }
            }
          }
        }
      });
    } catch (e, st) {
      _log.error('LAN Discovery error', e, st);
      state = state.copyWith(isRunning: false);
    }
  }
}

final lanDiscoveryServiceProvider = NotifierProvider<LanDiscoveryService, LanDiscoveryState>(
  LanDiscoveryService.new,
);