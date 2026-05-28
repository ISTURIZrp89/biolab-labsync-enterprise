import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/user.dart';
import '../../services/auth_service.dart';

class UsersScreen extends ConsumerStatefulWidget {
  const UsersScreen({super.key});

  @override
  ConsumerState<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends ConsumerState<UsersScreen> {
  List<User> _users = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _loading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      final serverUrl = prefs.getString('server_url') ?? 'http://localhost:8000';
      final response = await http.get(
        Uri.parse('$serverUrl/api/users'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final list = jsonDecode(response.body) as List;
        _users = list.map((e) => User.fromJson(e)).toList();
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Usuarios')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _users.isEmpty
              ? const Center(child: Text('No hay usuarios'))
              : ListView.builder(
                  itemCount: _users.length,
                  itemBuilder: (_, i) {
                    final u = _users[i];
                    return ListTile(
                      leading: CircleAvatar(child: Text(u.nombre[0])),
                      title: Text(u.nombre),
                      subtitle: Text('${u.rol} - ${u.area}'),
                      trailing: Icon(
                        u.activo ? Icons.check_circle : Icons.cancel,
                        color: u.activo ? Colors.green : Colors.red,
                      ),
                    );
                  },
                ),
    );
  }
}
