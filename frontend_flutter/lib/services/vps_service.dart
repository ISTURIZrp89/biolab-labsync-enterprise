import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum VpsConnectionState { disconnected, connecting, connected, error }

class VpsService extends ChangeNotifier {
  WebSocket? _socket;
  VpsConnectionState _state = VpsConnectionState.disconnected;
  String? _lastError;
  String? _vpsUrl;
  String? _deviceId;
  bool _authorized = false;
  Timer? _reconnectTimer;
  Timer? _heartbeatTimer;
  final List<Map<String, dynamic>> _messages = [];
  String? _remotePeerId;

  VpsConnectionState get state => _state;
  String? get lastError => _lastError;
  bool get authorized => _authorized;
  bool get connected => _state == VpsConnectionState.connected;
  String? get remotePeerId => _remotePeerId;
  List<Map<String, dynamic>> get messages => List.unmodifiable(_messages);

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _deviceId = prefs.getString('device_id');
    _vpsUrl = prefs.getString('vps_url');
    if (_vpsUrl != null && _vpsUrl!.isNotEmpty) {
      connect();
    }
  }

  Future<void> connect({String? url}) async {
    if (url != null) {
      _vpsUrl = url;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('vps_url', url);
    }
    if (_vpsUrl == null || _vpsUrl!.isEmpty) return;

    _state = VpsConnectionState.connecting;
    _lastError = null;
    notifyListeners();

    try {
      _socket = await WebSocket.connect(_vpsUrl!, headers: {
        'X-Device-Id': _deviceId ?? 'unknown',
      }).timeout(const Duration(seconds: 15));

      _state = VpsConnectionState.connected;
      notifyListeners();

      _socket!.listen(
        (data) => _onMessage(data),
        onError: (err) {
          _state = VpsConnectionState.error;
          _lastError = err.toString();
          notifyListeners();
          _scheduleReconnect();
        },
        onDone: () {
          _state = VpsConnectionState.disconnected;
          _authorized = false;
          notifyListeners();
          _scheduleReconnect();
        },
      );

      _heartbeatTimer?.cancel();
      _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        if (_socket != null && _state == VpsConnectionState.connected) {
          _send({'_type': 'ping', 'ts': DateTime.now().toIso8601String()});
        }
      });
    } catch (e) {
      _state = VpsConnectionState.error;
      _lastError = e.toString();
      notifyListeners();
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 30), () {
      if (_state != VpsConnectionState.connected) connect();
    });
  }

  void _onMessage(dynamic raw) {
    try {
      final msg = raw is String ? jsonDecode(raw) as Map<String, dynamic> : raw as Map<String, dynamic>;
      final type = msg['_type'] as String? ?? '';

      switch (type) {
        case 'authorized':
          _authorized = true;
          _remotePeerId = msg['peer_id'] as String?;
          notifyListeners();
          break;
        case 'unauthorized':
          _authorized = false;
          _lastError = msg['reason'] as String? ?? 'No autorizado';
          notifyListeners();
          break;
        case 'pong':
          break;
        case 'message':
          _messages.insert(0, msg);
          if (_messages.length > 200) _messages.removeRange(200, _messages.length);
          notifyListeners();
          break;
      }
    } catch (_) {}
  }

  void sendMessage(Map<String, dynamic> data) {
    _send({...data, '_type': 'message', 'from': _deviceId, 'ts': DateTime.now().toIso8601String()});
  }

  void _send(Map<String, dynamic> data) {
    if (_socket != null && _state == VpsConnectionState.connected) {
      _socket!.add(jsonEncode(data));
    }
  }

  Future<void> disconnect() async {
    _reconnectTimer?.cancel();
    _heartbeatTimer?.cancel();
    _authorized = false;
    await _socket?.close();
    _socket = null;
    _state = VpsConnectionState.disconnected;
    notifyListeners();
  }

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    _heartbeatTimer?.cancel();
    _socket?.close();
    super.dispose();
  }
}
