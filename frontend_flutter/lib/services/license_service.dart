import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class LicenseService {
  static const String _apiBase = 'https://api.github.com/repos/ISTURIZrp89/biolab-labsync-license/contents/';
  static const String _prefsTokenKey = 'license_github_token';

  static String? _runtimeToken;

  static String get _token {
    if (_runtimeToken != null && _runtimeToken!.isNotEmpty) return _runtimeToken!;
    final env = String.fromEnvironment('LICENSE_GITHUB_TOKEN');
    if (env.isNotEmpty) return env;
    return '';
  }

  static Future<void> loadTokenFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_prefsTokenKey);
    if (stored != null && stored.isNotEmpty) {
      _runtimeToken = stored;
    }
  }

  static Future<void> setToken(String token) async {
    _runtimeToken = token.isNotEmpty ? token : null;
    final prefs = await SharedPreferences.getInstance();
    if (token.isNotEmpty) {
      await prefs.setString(_prefsTokenKey, token);
    } else {
      await prefs.remove(_prefsTokenKey);
    }
  }

  static String? _lastFetchError;

  static Future<Map<String, dynamic>?> fetchPrivateFile(String path) async {
    final token = _token;
    _lastFetchError = null;
    if (token.isEmpty) {
      _lastFetchError = 'TOKEN_VACIO';
      return null;
    }
    try {
      final response = await http.get(
        Uri.parse('$_apiBase$path'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/vnd.github.v3+json',
          'Cache-Control': 'no-cache',
        },
      ).timeout(const Duration(seconds: 15));
      _lastFetchError = 'HTTP_${response.statusCode}';
      if (response.statusCode == 200) {
        try {
          final body = jsonDecode(response.body) as Map<String, dynamic>;
          if (body['encoding'] == 'base64' && body['content'] != null) {
            final decoded = utf8.decode(base64Decode(body['content']));
            return jsonDecode(decoded) as Map<String, dynamic>;
          }
          _lastFetchError = 'ENCODING_INESPERADO';
          return body;
        } catch (e) {
          _lastFetchError = 'PARSE_ERROR: $e';
          return null;
        }
      }
    } on SocketException catch (e) {
      _lastFetchError = 'RED: $e';
    } on HttpException catch (e) {
      _lastFetchError = 'HTTP: $e';
    } on TimeoutException {
      _lastFetchError = 'TIMEOUT';
    } catch (e) {
      _lastFetchError = 'EXCEPTION: $e';
    }
    return null;
  }
}
