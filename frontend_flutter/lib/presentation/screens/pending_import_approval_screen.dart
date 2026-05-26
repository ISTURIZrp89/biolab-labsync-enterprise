import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../../data/db.dart';
import '../../data/repositories/form_repository_impl.dart';
import '../../security/auth_service.dart';
import '../../theme/omni_theme.dart';

class PendingImportApprovalScreen extends StatefulWidget {
  const PendingImportApprovalScreen({super.key});

  @override
  State<PendingImportApprovalScreen> createState() => _PendingImportApprovalScreenState();
}

class _PendingImportApprovalScreenState extends State<PendingImportApprovalScreen> {
  List<Map<String, dynamic>> _pendingEntries = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPending();
  }

  Future<void> _loadPending() async {
    setState(() => _loading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList('pending_bitacora_imports') ?? [];
      _pendingEntries = raw.map((s) {
        final m = Map<String, dynamic>.from(jsonDecode(s) as Map);
        return m;
      }).where((m) => m['_approval_status'] == 'pending').toList();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _approveEntry(Map<String, dynamic> entry) async {
    try {
      final auth = context.read<AuthService>();
      final repo = context.read<FormRepositoryImpl>();
      final prefs = await SharedPreferences.getInstance();
      final deviceId = prefs.getString('device_id') ?? '';

      final fecha = entry['fecha']?.toString() ?? DateFormat('yyyy-MM-dd').format(DateTime.now());

      final data = <String, dynamic>{
        'fecha': fecha,
        'responsable': entry['responsable']?.toString() ?? auth.currentUser?.nombre ?? '',
        'hora_inicio': entry['hora_inicio']?.toString() ?? '',
        'hora_fin': entry['hora_fin']?.toString() ?? '',
        'incidencias': entry['incidencias']?.toString() ?? '',
        'acuerdos': '',
        'firma': '',
        '_actividades': [],
        '_recursos': [],
        '_cajas': [{
          'cajas': entry['cajas']?.toString() ?? '',
          'tipo_tejido': entry['tipo_tejido']?.toString() ?? '',
          'viales': entry['viales']?.toString() ?? '',
          'misid': entry['misid']?.toString() ?? '',
          'millones': entry['millones']?.toString() ?? '',
          'observaciones': entry['observaciones']?.toString() ?? '',
        }],
      };

      if (entry['actividad']?.toString().isNotEmpty == true || entry['descripcion']?.toString().isNotEmpty == true) {
        data['_actividades'] = [{
          'actividad': entry['actividad']?.toString() ?? '',
          'descripcion': entry['descripcion']?.toString() ?? '',
          'observaciones': entry['observaciones']?.toString() ?? '',
        }];
      }

      await repo.createEntry(
        module: 'bitacora',
        subModule: 'actividades',
        date: fecha,
        userId: auth.currentUser?.id ?? 'admin',
        deviceId: deviceId,
        data: data,
      );

      await _removePending(entry['_import_id']?.toString() ?? '');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Entrada aprobada y guardada'), backgroundColor: OmniTheme.green400));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: OmniTheme.red400));
      }
    }
  }

  Future<void> _rejectEntry(Map<String, dynamic> entry) async {
    await _removePending(entry['_import_id']?.toString() ?? '');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Entrada rechazada'), backgroundColor: OmniTheme.orange400));
    }
  }

  Future<void> _removePending(String importId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList('pending_bitacora_imports') ?? [];
      final updated = raw.where((s) {
        final m = Map<String, dynamic>.from(jsonDecode(s) as Map);
        return m['_import_id']?.toString() != importId;
      }).toList();
      await prefs.setStringList('pending_bitacora_imports', updated);
      _loadPending();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OmniTheme.bg950,
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back, size: 20), onPressed: () => Navigator.pop(context)),
        title: Text('Aprobar Importaciones (${_pendingEntries.length})', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        backgroundColor: OmniTheme.bg900, elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _pendingEntries.isEmpty
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.checklist, size: 64, color: OmniTheme.bg700),
                    const SizedBox(height: 16),
                    const Text('No hay importaciones pendientes', style: TextStyle(color: OmniTheme.textMuted, fontSize: 14)),
                    const SizedBox(height: 8),
                    const Text('Las entradas aprobadas se guardan automaticamente', style: TextStyle(color: OmniTheme.textMuted, fontSize: 12)),
                  ]),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _pendingEntries.length,
                  itemBuilder: (ctx, i) {
                    final entry = _pendingEntries[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: OmniTheme.orange400.withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
                                child: const Text('PENDIENTE', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: OmniTheme.orange400)),
                              ),
                              const Spacer(),
                              Text(entry['_import_date']?.toString() ?? '', style: const TextStyle(fontSize: 9, color: OmniTheme.textMuted)),
                            ]),
                            const SizedBox(height: 8),
                            _fieldRow('Fecha', entry['fecha']?.toString() ?? '-'),
                            _fieldRow('Responsable', entry['responsable']?.toString() ?? '-'),
                            if (entry['cajas']?.toString().isNotEmpty == true)
                              _fieldRow('Cajas', entry['cajas'].toString()),
                            if (entry['tipo_tejido']?.toString().isNotEmpty == true)
                              _fieldRow('Tejido', entry['tipo_tejido'].toString()),
                            if (entry['viales']?.toString().isNotEmpty == true)
                              _fieldRow('Viales', entry['viales'].toString()),
                            if (entry['misid']?.toString().isNotEmpty == true)
                              _fieldRow('MISID', entry['misid'].toString()),
                            if (entry['millones']?.toString().isNotEmpty == true)
                              _fieldRow('Mill Cel', entry['millones'].toString()),
                            if (entry['actividad']?.toString().isNotEmpty == true)
                              _fieldRow('Actividad', entry['actividad'].toString()),
                            if (entry['descripcion']?.toString().isNotEmpty == true)
                              _fieldRow('Descripcion', entry['descripcion'].toString()),
                            if (entry['observaciones']?.toString().isNotEmpty == true)
                              _fieldRow('Observaciones', entry['observaciones'].toString()),
                            const SizedBox(height: 8),
                            Row(children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.close, size: 14),
                                  label: const Text('Rechazar', style: TextStyle(fontSize: 11)),
                                  style: OutlinedButton.styleFrom(foregroundColor: OmniTheme.red400, side: BorderSide(color: OmniTheme.red400.withOpacity(0.4))),
                                  onPressed: () => _rejectEntry(entry),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.check, size: 14),
                                  label: const Text('Aprobar', style: TextStyle(fontSize: 11)),
                                  style: ElevatedButton.styleFrom(backgroundColor: OmniTheme.green400, foregroundColor: Colors.white),
                                  onPressed: () => _approveEntry(entry),
                                ),
                              ),
                            ]),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Widget _fieldRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 100, child: Text('$label:', style: const TextStyle(fontSize: 10, color: OmniTheme.textMuted))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 10, color: OmniTheme.textPrimary))),
        ],
      ),
    );
  }
}
