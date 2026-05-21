import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  final String baseUrl;

  ApiClient({this.baseUrl = "http://localhost:8000"});

  Future<String?> _getToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('jwt_token');
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, String>> _getHeaders({bool requiresAuth = false}) async {
    final headers = {'Content-Type': 'application/json'};
    if (requiresAuth) {
      final token = await _getToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  Future<http.Response> get(
    String path, {
    bool requiresAuth = false,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final headers = await _getHeaders(requiresAuth: requiresAuth);
    return await http.get(
      Uri.parse('$baseUrl$path'),
      headers: headers,
    ).timeout(timeout);
  }

  Future<http.Response> post(
    String path, {
    Map<String, dynamic>? body,
    bool requiresAuth = false,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final headers = await _getHeaders(requiresAuth: requiresAuth);
    return await http.post(
      Uri.parse('$baseUrl$path'),
      headers: headers,
      body: body != null ? jsonEncode(body) : null,
    ).timeout(timeout);
  }

  Future<http.Response> put(
    String path, {
    Map<String, dynamic>? body,
    bool requiresAuth = false,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final headers = await _getHeaders(requiresAuth: requiresAuth);
    return await http.put(
      Uri.parse('$baseUrl$path'),
      headers: headers,
      body: body != null ? jsonEncode(body) : null,
    ).timeout(timeout);
  }

  Future<http.Response> delete(
    String path, {
    bool requiresAuth = false,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final headers = await _getHeaders(requiresAuth: requiresAuth);
    return await http.delete(
      Uri.parse('$baseUrl$path'),
      headers: headers,
    ).timeout(timeout);
  }
}
