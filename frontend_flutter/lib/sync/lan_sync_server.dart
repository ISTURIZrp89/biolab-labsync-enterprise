import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import '../data/db.dart';

class LanSyncServer extends ChangeNotifier {
  HttpServer? _server;
  bool _isRunning = false;
  int _port = 8766;
  bool _disposed = false;

  bool get isRunning => _isRunning;
  int get port => _port;

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> start({int port = 8766}) async {
    if (_isRunning) return;
    _port = port;

    try {
      _server = await HttpServer.bind(
        InternetAddress.anyIPv4,
        _port,
      );

      _isRunning = true;
      _server!.listen(_handleRequest);
      _safeNotify();
      debugPrint('LanSyncServer: Listening on port $_port');
    } catch (e) {
      debugPrint('LanSyncServer: Error starting: $e');
      _isRunning = false;
    }
  }

  void stop() {
    _server?.close();
    _server = null;
    _isRunning = false;
    _safeNotify();
  }

  void _handleRequest(HttpRequest request) {
    final path = request.uri.path;
    final method = request.method;

    switch ('$method $path') {
      case 'GET /health':
        _handleHealth(request);
        break;
      case 'POST /sync/push':
        _handlePush(request);
        break;
      case 'GET /sync/pull':
        _handlePull(request);
        break;
      default:
        request.response
          ..statusCode = 404
          ..write(jsonEncode({'error': 'Not found'}))
          ..close();
    }
  }

  void _handleHealth(HttpRequest request) async {
    final prefs = await SharedPreferences.getInstance();
    final deviceId = prefs.getString('device_id') ?? 'unknown';

    request.response
      ..statusCode = 200
      ..headers.contentType = ContentType.json
      ..write(jsonEncode({
        'status': 'ok',
        'device_id': deviceId,
        'hostname': Platform.localHostname,
      }))
      ..close();
  }

  void _handlePush(HttpRequest request) async {
    try {
      final body = await request.cast<List<int>>().transform(utf8.decoder).join();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final db = await LocalDatabase.instance.database;

      final entries = data['entries'] as List? ?? [];
      int inserted = 0;

      for (final entry in entries) {
        try {
          await db.insert('form_entries', {
            'id': entry['id'],
            'module': entry['module'],
            'date': entry['date'],
            'user_id': entry['user_id'],
            'device_id': entry['device_id'],
            'version': entry['version'] ?? 1,
            'data_json': jsonEncode(entry['data'] ?? entry['data_json'] ?? {}),
            'status': entry['status'] ?? 'pending',
            'created_at': entry['created_at'],
            'updated_at': entry['updated_at'],
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
          inserted++;
        } catch (e) {
          debugPrint('LanSyncServer: Insert error: $e');
        }
      }

      request.response
        ..statusCode = 200
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({'success': true, 'inserted': inserted}))
        ..close();
    } catch (e) {
      request.response
        ..statusCode = 400
        ..write(jsonEncode({'error': e.toString()}))
        ..close();
    }
  }

  void _handlePull(HttpRequest request) async {
    try {
      final since = request.uri.queryParameters['since'] ?? '';
      final db = await LocalDatabase.instance.database;

      List<Map<String, dynamic>> entries;
      if (since.isNotEmpty) {
        entries = await db.query(
          'form_entries',
          where: 'updated_at > ?',
          whereArgs: [since],
        );
      } else {
        entries = await db.query('form_entries');
      }

      request.response
        ..statusCode = 200
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({
          'success': true,
          'entries': entries,
        }))
        ..close();
    } catch (e) {
      request.response
        ..statusCode = 500
        ..write(jsonEncode({'error': e.toString()}))
        ..close();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    stop();
    super.dispose();
  }
}
