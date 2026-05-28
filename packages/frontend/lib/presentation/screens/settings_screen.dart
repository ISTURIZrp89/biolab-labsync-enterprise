import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _serverUrlCtrl = TextEditingController();
  final _dbPathCtrl = TextEditingController();
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _serverUrlCtrl.text = prefs.getString('server_url') ?? 'http://localhost:8000';
    _dbPathCtrl.text = prefs.getString('db_path') ?? '';
    if (mounted) setState(() {});
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('server_url', _serverUrlCtrl.text);
    await prefs.setString('db_path', _dbPathCtrl.text);
    setState(() => _saved = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _saved = false);
    });
  }

  @override
  void dispose() {
    _serverUrlCtrl.dispose();
    _dbPathCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configuracion')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Servidor', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _serverUrlCtrl,
              decoration: const InputDecoration(
                hintText: 'http://localhost:8000',
                prefixIcon: Icon(Icons.cloud),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            const Text('Ruta base de datos local', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _dbPathCtrl,
              decoration: const InputDecoration(
                hintText: 'Dejar vacio para usar ruta por defecto',
                prefixIcon: Icon(Icons.folder),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _save,
                icon: Icon(_saved ? Icons.check : Icons.save),
                label: Text(_saved ? 'Guardado' : 'Guardar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
