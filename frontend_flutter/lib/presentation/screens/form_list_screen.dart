import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../data/repositories/form_repository_impl.dart';
import '../../domain/entities/form_entry.dart';
import '../../security/auth_service.dart';
import '../../sync/sync_engine.dart';
import '../../theme/omni_theme.dart';
import '../widgets/dynamic_form.dart';
import 'package:intl/intl.dart';

class FormListScreen extends StatefulWidget {
  final String module;
  final String moduleLabel;

  const FormListScreen({
    super.key,
    required this.module,
    required this.moduleLabel,
  });

  @override
  State<FormListScreen> createState() => _FormListScreenState();
}

class _FormListScreenState extends State<FormListScreen> {
  final FormRepositoryImpl _formRepo = FormRepositoryImpl();
  Map<String, dynamic>? _template;
  List<FormEntry> _entries = [];
  bool _loading = true;
  bool _isOnline = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    await _checkOnline();
    await _loadTemplate();
    await _loadEntries();
    setState(() => _loading = false);
  }

  Future<void> _checkOnline() async {
    try {
      final res = await http.get(
        Uri.parse('http://localhost:8000/api/health'),
      ).timeout(const Duration(seconds: 3));
      setState(() => _isOnline = res.statusCode == 200);
    } catch (_) {
      setState(() => _isOnline = false);
    }
  }

  Future<void> _loadTemplate() async {
    try {
      final tplRes = await http.get(
        Uri.parse('http://localhost:8000/api/templates/${widget.module}'),
      ).timeout(const Duration(seconds: 3));
      if (tplRes.statusCode == 200) {
        setState(() => _template = jsonDecode(tplRes.body));
      }
    } catch (_) {
      // Template not available offline, use cached if exists
    }
  }

  Future<void> _loadEntries() async {
    final entries = await _formRepo.getEntriesByModule(widget.module);
    setState(() => _entries = entries);
  }

  Future<void> _openForm({FormEntry? existing}) async {
    if (_template == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Plantilla no disponible. Verifique conexion')),
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _FormScreen(
          template: _template!,
          module: widget.module,
          existingEntry: existing,
        ),
      ),
    );
    _loadData();
  }

  Future<void> _syncNow() async {
    if (!mounted) return;
    final syncEngine = context.read<SyncEngine>();
    final success = await syncEngine.synchronize();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(success
            ? 'Sincronizacion completada'
            : 'Error al sincronizar. Datos guardados localmente')),
      );
      if (success) _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.moduleLabel),
        backgroundColor: OmniTheme.primary,
        foregroundColor: Colors.white,
        actions: [
          Consumer<SyncEngine>(
            builder: (context, sync, _) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    sync.isOnline ? Icons.wifi : Icons.wifi_off,
                    color: sync.isOnline ? Colors.greenAccent : Colors.redAccent,
                    size: 18,
                  ),
                  if (sync.isSyncing)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: _syncNow,
            tooltip: 'Sincronizar ahora',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (!_isOnline)
                  Container(
                    width: double.infinity,
                    color: Colors.orange.shade800,
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    child: const Row(
                      children: [
                        Icon(Icons.offline_bolt, color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Modo offline - Los datos se guardaran localmente',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                if (_template != null)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _openForm(),
                        icon: const Icon(Icons.add),
                        label: const Text('Nuevo Registro'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: OmniTheme.primary,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(48),
                        ),
                      ),
                    ),
                  ),
                Expanded(
                  child: _entries.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.folder_open, size: 64, color: Colors.white.withOpacity(0.3)),
                              const SizedBox(height: 16),
                              Text(
                                'Sin registros para ${widget.moduleLabel}',
                                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 16),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _entries.length,
                          itemBuilder: (context, index) {
                            final entry = _entries[index];
                            final data = entry.data;
                            final firstValue = data.values.firstWhere(
                              (v) => v.toString().isNotEmpty,
                              orElse: () => 'Sin datos',
                            );
                            final dateStr = _formatDate(entry.date);

                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              color: OmniTheme.bg950,
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: _getStatusColor(entry.status),
                                  child: Icon(Icons.check, color: Colors.white, size: 18),
                                ),
                                title: Text(
                                  dateStr,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                                ),
                                subtitle: Text(
                                  firstValue.toString(),
                                  style: TextStyle(color: Colors.white.withOpacity(0.6)),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (entry.version > 1)
                                      Padding(
                                        padding: const EdgeInsets.only(right: 8),
                                        child: Text(
                                          'v${entry.version}',
                                          style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11),
                                        ),
                                      ),
                                    IconButton(
                                      icon: const Icon(Icons.edit, color: Colors.white54),
                                      onPressed: () => _openForm(existing: entry),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd/MM/yyyy', 'es').format(date);
    } catch (_) {
      return dateStr;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'saved':
        return Colors.green;
      case 'synced':
        return Colors.blue;
      case 'excused':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}

class _FormScreen extends StatefulWidget {
  final Map<String, dynamic> template;
  final String module;
  final FormEntry? existingEntry;

  const _FormScreen({
    required this.template,
    required this.module,
    this.existingEntry,
  });

  @override
  State<_FormScreen> createState() => _FormScreenState();
}

class _FormScreenState extends State<_FormScreen> {
  final FormRepositoryImpl _formRepo = FormRepositoryImpl();
  bool _saving = false;

  Future<void> _save(Map<String, dynamic> formData) async {
    setState(() => _saving = true);
    final prefs = await SharedPreferences.getInstance();
    final deviceId = prefs.getString('device_id') ?? 'unknown';
    final auth = context.read<AuthService>();
    final userId = auth.currentUser?.id ?? 'usr-admin';
    final today = DateTime.now().toIso8601String().split('T')[0];

    try {
      if (widget.existingEntry != null) {
        final updated = FormEntry(
          id: widget.existingEntry!.id,
          module: widget.module,
          date: widget.existingEntry!.date,
          userId: userId,
          deviceId: deviceId,
          version: widget.existingEntry!.version + 1,
          data: formData,
          status: 'saved',
          createdAt: widget.existingEntry!.createdAt,
          updatedAt: DateTime.now().toUtc().toIso8601String(),
        );
        await _formRepo.saveEntry(updated);
      } else {
        await _formRepo.createEntry(
          module: widget.module,
          date: today,
          userId: userId,
          deviceId: deviceId,
          data: formData,
        );
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green),
                const SizedBox(width: 12),
                const Text('Bitacora guardada exitosamente'),
              ],
            ),
            backgroundColor: OmniTheme.bg950,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.template['name'] as String? ?? 'Formulario'),
        backgroundColor: OmniTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF001020), Color(0xFF000810)],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 500),
              child: _saving
                  ? const Center(child: CircularProgressIndicator())
                  : DynamicFormWidget(
                      template: widget.template,
                      initialData: widget.existingEntry?.data ?? {},
                      onSave: _save,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
