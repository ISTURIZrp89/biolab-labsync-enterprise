import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum NodeRole { leader, worker, observer }
enum NodeStatus { online, offline, busy, error }

class NodeInfo {
  final String id;
  final String hostname;
  final String ip;
  final int port;
  final NodeRole role;
  final NodeStatus status;
  final int score;
  final String platform;
  final String modelId;
  final double load;
  final DateTime lastSeen;
  final int version;

  NodeInfo({
    required this.id,
    required this.hostname,
    this.ip = '',
    this.port = 0,
    this.role = NodeRole.worker,
    this.status = NodeStatus.offline,
    this.score = 0,
    this.platform = '',
    this.modelId = '',
    this.load = 0,
    DateTime? lastSeen,
    this.version = 1,
  }) : lastSeen = lastSeen ?? DateTime.now();

  NodeInfo copyWith({
    String? id, String? hostname, String? ip, int? port,
    NodeRole? role, NodeStatus? status, int? score,
    String? platform, String? modelId, double? load,
    DateTime? lastSeen, int? version,
  }) => NodeInfo(
    id: id ?? this.id, hostname: hostname ?? this.hostname,
    ip: ip ?? this.ip, port: port ?? this.port,
    role: role ?? this.role, status: status ?? this.status,
    score: score ?? this.score, platform: platform ?? this.platform,
    modelId: modelId ?? this.modelId, load: load ?? this.load,
    lastSeen: lastSeen ?? this.lastSeen, version: version ?? this.version,
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'hostname': hostname, 'ip': ip, 'port': port,
    'role': role.index, 'status': status.index, 'score': score,
    'platform': platform, 'modelId': modelId, 'load': load,
    'lastSeen': lastSeen.toIso8601String(), 'version': version,
  };
}

class NodeManager extends ChangeNotifier {
  final List<NodeInfo> _nodes = [];
  NodeInfo? _localNode;
  WebSocket? _serverSocket;
  HttpServer? _httpServer;
  Timer? _heartbeatTimer;
  Timer? _electionTimer;
  bool _isRunning = false;
  int _electionTerm = 0;
  String _localId = '';

  List<NodeInfo> get nodes => List.unmodifiable(_nodes);
  NodeInfo? get localNode => _localNode;
  NodeInfo? get leader => _nodes.where((n) => n.role == NodeRole.leader).firstOrNull;
  bool get isRunning => _isRunning;

  NodeManager() {
    _localId = 'node_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}';
  }

  Future<void> start({
    required String hostname,
    required int port,
    required int score,
    required String platform,
    required String modelId,
  }) async {
    _localNode = NodeInfo(
      id: _localId, hostname: hostname, ip: '127.0.0.1',
      port: port, role: NodeRole.leader, status: NodeStatus.online,
      score: score, platform: platform, modelId: modelId, version: 1,
    );
    _nodes.add(_localNode!);
    _isRunning = true;
    _startHeartbeat();
    _startElectionTimer();
    notifyListeners();
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      final now = DateTime.now();
      for (int i = _nodes.length - 1; i >= 0; i--) {
        if (now.difference(_nodes[i].lastSeen).inSeconds > 60) {
          if (_nodes[i].id != _localId) {
            _nodes[i] = _nodes[i].copyWith(status: NodeStatus.offline);
          }
        }
      }
      notifyListeners();
    });
  }

  void _startElectionTimer() {
    _electionTimer?.cancel();
    _electionTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (leader == null || leader!.status == NodeStatus.offline) {
        _holdElection();
      }
    });
  }

  void _holdElection() {
    _electionTerm++;
    final online = _nodes.where((n) => n.status == NodeStatus.online).toList();
    if (online.isEmpty) return;
    online.sort((a, b) => b.score.compareTo(a.score));
    final newLeader = online.first;

    for (int i = 0; i < _nodes.length; i++) {
      final newRole = _nodes[i].id == newLeader.id ? NodeRole.leader : NodeRole.worker;
      _nodes[i] = _nodes[i].copyWith(role: newRole, status: NodeStatus.online, version: _electionTerm);
    }
    if (_localNode != null) {
      _localNode = _nodes.where((n) => n.id == _localId).firstOrNull;
    }
    notifyListeners();
  }

  Future<void> registerPeer(NodeInfo peer) async {
    final idx = _nodes.indexWhere((n) => n.id == peer.id);
    if (idx >= 0) {
      _nodes[idx] = peer.copyWith(status: NodeStatus.online, lastSeen: DateTime.now());
    } else {
      _nodes.add(peer.copyWith(lastSeen: DateTime.now()));
    }
    notifyListeners();
  }

  Future<void> requestSupport(String task, Map<String, dynamic> payload) async {
    final online = _nodes.where((n) =>
        n.status == NodeStatus.online && n.id != _localId).toList();
    if (online.isEmpty) return;
    online.sort((a, b) => b.score.compareTo(a.score));
    final target = online.first;
    debugPrint('[NodeManager] Solicitando apoyo a ${target.hostname} para: $task');
  }

  void stop() {
    _heartbeatTimer?.cancel();
    _electionTimer?.cancel();
    _serverSocket?.close();
    _httpServer?.close();
    _isRunning = false;
    _nodes.clear();
    _localNode = null;
    notifyListeners();
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
