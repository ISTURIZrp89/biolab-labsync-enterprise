import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DiscoveredPeer {
  final String deviceId;
  final String hostname;
  String ip;
  final int port;
  DateTime lastSeen;

  DiscoveredPeer({
    required this.deviceId,
    required this.hostname,
    required this.ip,
    required this.port,
    DateTime? lastSeen,
  }) : lastSeen = lastSeen ?? DateTime.now();

  bool get isExpired => DateTime.now().difference(lastSeen).inSeconds > 90;

  Map<String, dynamic> toJson() => {
    'device_id': deviceId,
    'hostname': hostname,
    'ip': ip,
    'port': port,
    'last_seen': lastSeen.toIso8601String(),
  };
}

class LanDiscoveryService extends ChangeNotifier {
  RawDatagramSocket? _socket;
  Timer? _broadcastTimer;
  Timer? _cleanupTimer;
  bool _isRunning = false;
  String _deviceId = 'unknown';
  String _hostname = '';
  int _port = 8765;
  final List<DiscoveredPeer> _peers = [];

  bool _disposed = false;

  List<DiscoveredPeer> get peers => List.unmodifiable(_peers);
  bool get isRunning => _isRunning;

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> start({int port = 8765}) async {
    if (_isRunning) return;
    _port = port;

    final prefs = await SharedPreferences.getInstance();
    _deviceId = prefs.getString('device_id') ?? 'unknown';
    _hostname = Platform.localHostname;

    try {
      _socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        _port,
        reusePort: true,
        reuseAddress: true,
      );
      _socket!.broadcastEnabled = true;

      _isRunning = true;
      _socket!.listen(_onPacket);

      _broadcastTimer = Timer.periodic(const Duration(seconds: 15), (_) => _broadcastPresence());
      _cleanupTimer = Timer.periodic(const Duration(seconds: 30), (_) => _cleanupExpired());

      await _broadcastPresence();
      _safeNotify();
    } catch (e) {
      debugPrint('LanDiscovery: Error starting: $e');
      _isRunning = false;
    }
  }

  void stop() {
    _broadcastTimer?.cancel();
    _broadcastTimer = null;
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
    _socket?.close();
    _socket = null;
    _isRunning = false;
    _peers.clear();
    _safeNotify();
  }

  Future<void> _broadcastPresence() async {
    if (_socket == null) return;
    try {
      final msg = utf8.encode(jsonEncode({
        'type': 'labsync_discovery',
        'device_id': _deviceId,
        'hostname': _hostname,
        'port': _port,
      }));

      _socket!.send(msg, InternetAddress('255.255.255.255'), _port);
    } catch (e) {
      debugPrint('LanDiscovery: Broadcast error: $e');
    }
  }

  void _onPacket(RawSocketEvent event) {
    if (event != RawSocketEvent.read) return;
    final datagram = _socket!.receive();
    if (datagram == null) return;

    try {
      final msg = jsonDecode(utf8.decode(datagram.data)) as Map<String, dynamic>;
      if (msg['type'] != 'labsync_discovery') return;

      final peerDeviceId = msg['device_id'] as String?;
      if (peerDeviceId == null || peerDeviceId == _deviceId) return;

      final peerHostname = msg['hostname'] as String? ?? 'Unknown';
      final peerPort = msg['port'] as int? ?? _port;
      final peerIp = datagram.address.address;

      final existing = _peers.indexWhere((p) => p.deviceId == peerDeviceId);
      final now = DateTime.now();

      if (existing >= 0) {
        _peers[existing].lastSeen = now;
        _peers[existing].ip = peerIp;
      } else {
        _peers.add(DiscoveredPeer(
          deviceId: peerDeviceId,
          hostname: peerHostname,
          ip: peerIp,
          port: peerPort,
          lastSeen: now,
        ));
      }

      _safeNotify();
    } catch (e) {
      debugPrint('LanDiscovery: Parse error: $e');
    }
  }

  void _cleanupExpired() {
    final before = _peers.length;
    _peers.removeWhere((p) => p.isExpired);
    if (_peers.length != before) _safeNotify();
  }

  @override
  void dispose() {
    _disposed = true;
    stop();
    super.dispose();
  }
}
