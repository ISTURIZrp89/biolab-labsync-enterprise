import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../data/db.dart';
import '../../security/auth_service.dart';
import '../../sync/sync_engine.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final LocalDatabase _localDb = LocalDatabase.instance;
  late DateTime _currentMonth;
  Map<String, Map<String, dynamic>> _dayStatus = {};
  bool _loading = false;
  bool _isOnline = false;

  @override
  void initState() {
    super.initState();
    _currentMonth = DateTime.now();
    _loadMonth();
  }

  Future<void> _loadMonth() async {
    setState(() => _loading = true);
    await _checkOnline();
    await _loadMonthData();
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

  Future<void> _loadMonthData() async {
    final db = await _localDb.database;

    final firstDay = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final lastDay = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);

    final closures = await db.query(
      'day_closures',
      where: 'date >= ? AND date <= ?',
      whereArgs: [
        DateFormat('yyyy-MM-dd').format(firstDay),
        DateFormat('yyyy-MM-dd').format(lastDay),
      ],
    );

    final entries = await db.query(
      'form_entries',
      where: 'date >= ? AND date <= ?',
      whereArgs: [
        DateFormat('yyyy-MM-dd').format(firstDay),
        DateFormat('yyyy-MM-dd').format(lastDay),
      ],
    );

    final Map<String, Map<String, dynamic>> status = {};

    for (int day = 1; day <= lastDay.day; day++) {
      final dateStr = DateFormat('yyyy-MM-dd').format(
        DateTime(_currentMonth.year, _currentMonth.month, day),
      );

      final dayClosures = closures.where((c) => c['date'] == dateStr).toList();
      final dayEntries = entries.where((e) => e['date'] == dateStr).toList();

      final modules = <String, String>{};
      const moduleList = ['incubadoras', 'autoclaves', 'ultracongeladores', 'equipos', 'procesamiento'];

      for (final mod in moduleList) {
        final modEntries = dayEntries.where((e) => e['module'] == mod).toList();
        if (modEntries.isEmpty) {
          modules[mod] = 'SIN_REGISTRO';
        } else {
          final allComplete = modEntries.every((e) => e['status'] == 'saved');
          modules[mod] = allComplete ? 'COMPLETO' : 'PENDIENTE';
        }
      }

      String closureStatus = 'ABIERTO';
      String notes = '';
      String reopenLog = '[]';
      String closedBy = '';

      if (dayClosures.isNotEmpty) {
        closureStatus = dayClosures.first['status'] as String;
        notes = dayClosures.first['notes'] as String? ?? '';
        reopenLog = dayClosures.first['reopen_log_json'] as String? ?? '[]';
        closedBy = dayClosures.first['closed_by'] as String? ?? '';
      }

      String overall;
      if (closureStatus.startsWith('CERRADO')) {
        overall = closureStatus;
      } else if (modules.values.every((s) => s == 'COMPLETO')) {
        overall = 'COMPLETO';
      } else if (modules.values.any((s) => s != 'SIN_REGISTRO')) {
        overall = 'PENDIENTE';
      } else {
        overall = 'SIN_REGISTRO';
      }

      status[dateStr] = {
        'date': dateStr,
        'closure_status': closureStatus,
        'closed_by': closedBy,
        'notes': notes,
        'reopen_log': jsonDecode(reopenLog),
        'modules': modules,
        'overall': overall,
      };
    }

    if (_isOnline) {
      try {
        final res = await http.get(
          Uri.parse('http://localhost:8000/api/calendar/month?year=${_currentMonth.year}&month=${_currentMonth.month}'),
        ).timeout(const Duration(seconds: 5));

        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          for (var day in data['days']) {
            status[day['date']] = day;
          }
        }
      } catch (_) {
        // Use local data if server fails
      }
    }

    setState(() => _dayStatus = status);
  }

  Color _getColor(String overall, String closureStatus) {
    if (closureStatus == 'CERRADO') return Colors.green;
    if (closureStatus == 'CERRADO_CON_OBSERVACION' || closureStatus == 'CERRADO_OBSERVACION') return Colors.blue;
    if (closureStatus == 'REABIERTO') return Colors.orange.shade300;
    if (closureStatus == 'ABIERTO' && overall == 'COMPLETO') return Colors.green.shade300;
    if (overall == 'PENDIENTE') return Colors.orange;
    if (overall == 'SIN_REGISTRO') return Colors.grey.shade600;
    return Colors.white24;
  }

  Future<void> _closeDay(String dateStr, String status, String notes) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('jwt_username') ?? 'usr-admin';
    final deviceId = prefs.getString('device_id') ?? 'unknown';
    final now = DateTime.now().toUtc().toIso8601String();

    final db = await _localDb.database;
    final closureId = 'dc-$dateStr';

    await db.insert(
      'day_closures',
      {
        'id': closureId,
        'date': dateStr,
        'status': status,
        'closed_by': userId,
        'closed_at': now,
        'notes': notes,
        'reopen_log_json': '[]',
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    await _localDb.queueSyncAction(
      action: 'UPDATE',
      entity: 'day_closures',
      entityId: closureId,
      data: {
        'id': closureId,
        'date': dateStr,
        'status': status,
        'closed_by': userId,
        'notes': notes,
        'reopen_log': [],
      },
    );

    if (_isOnline) {
      try {
        await http.post(
          Uri.parse('http://localhost:8000/api/calendar/close-day'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'date': dateStr,
            'status': status,
            'closed_by': userId,
            'notes': notes,
          }),
        ).timeout(const Duration(seconds: 5));
      } catch (_) {}
    }

    _loadMonth();
  }

  void _showDayDetail(String dateStr) {
    final dayData = _dayStatus[dateStr];
    if (dayData == null) return;

    final modules = dayData['modules'] as Map<String, dynamic>? ?? {};
    final notes = dayData['notes'] as String? ?? '';
    final reopenLog = dayData['reopen_log'] as List? ?? [];
    final closureStatus = dayData['closure_status'] as String? ?? 'ABIERTO';

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF001830),
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              DateFormat('dd/MM/yyyy', 'es').format(DateTime.parse(dateStr)),
              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _getColor(dayData['overall'] as String, closureStatus),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Estado: $closureStatus',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Notas: $notes', style: const TextStyle(color: Colors.white54)),
            ],
            const SizedBox(height: 16),
            const Text('Modulos:', style: TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 8),
            ...modules.entries.map((e) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: e.value == 'COMPLETO'
                          ? Colors.green
                          : e.value == 'PENDIENTE'
                              ? Colors.orange
                              : Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${_getModuleLabel(e.key)}: ${e.value}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            )),
            if (reopenLog.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Historial de reaperturas:', style: TextStyle(color: Colors.white54, fontSize: 12)),
              ...reopenLog.map((log) => Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '${log['timestamp']} - ${log['reopened_by']}: ${log['reason']}',
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              )),
            ],
            const SizedBox(height: 16),
            if (!closureStatus.startsWith('CERRADO'))
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _showCloseDialog(dateStr),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF004A99),
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: const Text('Cerrar Dia', style: TextStyle(color: Colors.white)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _getModuleLabel(String module) {
    switch (module) {
      case 'incubadoras':
        return 'Incubadoras';
      case 'autoclaves':
        return 'Autoclaves';
      case 'ultracongeladores':
        return 'Ultracongeladores';
      case 'equipos':
        return 'Equipos';
      case 'procesamiento':
        return 'Procesamiento';
      default:
        return module;
    }
  }

  void _showCloseDialog(String dateStr) {
    final statuses = ['COMPLETO', 'CERRADO', 'CERRADO_CON_OBSERVACION'];
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          String selectedStatus = 'COMPLETO';
          String notes = '';
          return AlertDialog(
            backgroundColor: const Color(0xFF001830),
            title: const Text('Cerrar Dia', style: TextStyle(color: Colors.white)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ...statuses.map((s) => RadioListTile<String>(
                  title: Text(s, style: const TextStyle(color: Colors.white)),
                  activeColor: Colors.white,
                  value: s,
                  groupValue: selectedStatus,
                  onChanged: (v) => setDialogState(() => selectedStatus = v!),
                )),
                TextField(
                  decoration: const InputDecoration(
                    hintText: 'Observaciones (opcional)',
                    hintStyle: TextStyle(color: Colors.white38),
                  ),
                  style: const TextStyle(color: Colors.white),
                  onChanged: (v) => notes = v,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _closeDay(dateStr, selectedStatus, notes);
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF004A99)),
                child: const Text('Confirmar', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final lastDay = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
    final startWeekday = firstDay.weekday % 7;
    final daysInMonth = lastDay.day;

    return Scaffold(
      appBar: AppBar(
        title: Text(DateFormat('MMMM yyyy', 'es').format(_currentMonth)),
        backgroundColor: const Color(0xFF004A99),
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
                  const SizedBox(width: 4),
                  Text(
                    _isOnline ? 'Online' : 'Offline',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              setState(() => _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1));
              _loadMonth();
            },
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward),
            onPressed: () {
              setState(() => _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1));
              _loadMonth();
            },
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF001020), Color(0xFF000810)],
          ),
        ),
        child: Column(
          children: [
            _buildLegend(),
            _buildWeekdays(),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildGrid(daysInMonth, startWeekday),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _legendItem(Colors.green, 'Completo'),
          _legendItem(Colors.orange, 'Pendiente'),
          _legendItem(Colors.blue, 'C/Observ.'),
          _legendItem(Colors.grey.shade600, 'S/Registro'),
        ],
      ),
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: Colors.white54, fontSize: 11)),
      ],
    );
  }

  Widget _buildWeekdays() {
    const weekdays = ['Dom', 'Lun', 'Mar', 'Mie', 'Jue', 'Vie', 'Sab'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: weekdays.map((d) => Expanded(
          child: Center(child: Text(d, style: const TextStyle(color: Colors.white38, fontSize: 12))),
        )).toList(),
      ),
    );
  }

  Widget _buildGrid(int daysInMonth, int startWeekday) {
    final today = DateTime.now().toIso8601String().split('T')[0];
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 1,
      ),
      itemCount: startWeekday + daysInMonth,
      itemBuilder: (context, index) {
        if (index < startWeekday) return const SizedBox();
        final day = index - startWeekday + 1;
        final dateStr = '${_currentMonth.year}-${_currentMonth.month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
        final dayData = _dayStatus[dateStr];
        final isToday = dateStr == today;

        Color bg = Colors.white10;
        if (dayData != null) {
          bg = _getColor(dayData['overall'] as String? ?? '', dayData['closure_status'] as String? ?? '');
        }

        return GestureDetector(
          onTap: () => _showDayDetail(dateStr),
          child: Container(
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(8),
              border: isToday ? Border.all(color: Colors.white, width: 2) : null,
            ),
            child: Center(
              child: Text(
                '$day',
                style: TextStyle(
                  color: isToday ? Colors.white : Colors.white70,
                  fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
