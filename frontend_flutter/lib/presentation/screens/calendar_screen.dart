import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../data/db.dart';
import '../../sync/sync_engine.dart';
import '../../data/repositories/form_repository_impl.dart';
import '../../domain/entities/form_entry.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> with SingleTickerProviderStateMixin {
  final LocalDatabase _localDb = LocalDatabase.instance;
  final FormRepositoryImpl _formRepo = FormRepositoryImpl();
  late DateTime _currentMonth;
  Map<String, int> _entryCounts = {};
  Map<String, String> _dayStatus = {};
  bool _loading = false;
  late AnimationController _animationController;


  @override
  void initState() {
    super.initState();
    _currentMonth = DateTime.now();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _loadMonth();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadMonth() async {
    setState(() => _loading = true);
    await _loadMonthData();
    setState(() => _loading = false);
  }

  Future<void> _loadMonthData() async {
    try {
      final db = await _localDb.database;
      final firstDay = DateTime(_currentMonth.year, _currentMonth.month, 1);
      final lastDay = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
      final firstStr = DateFormat('yyyy-MM-dd').format(firstDay);
      final lastStr = DateFormat('yyyy-MM-dd').format(lastDay);

      final entries = await db.query(
        'form_entries',
        where: 'date >= ? AND date <= ?',
        whereArgs: [firstStr, lastStr],
      );

      final closures = await db.query(
        'day_closures',
        where: 'date >= ? AND date <= ?',
        whereArgs: [firstStr, lastStr],
      );

      final Map<String, int> counts = {};
      final Map<String, String> status = {};

      for (int day = 1; day <= lastDay.day; day++) {
        final date = DateTime(_currentMonth.year, _currentMonth.month, day);
        final dateStr = DateFormat('yyyy-MM-dd').format(date);

        final dayEntries = entries.where((e) => e['date'] == dateStr).toList();
        counts[dateStr] = dayEntries.length;

        final dayClosures = closures.where((c) => c['date'] == dateStr).toList();
        if (dayClosures.isNotEmpty) {
          status[dateStr] = dayClosures.first['status'] as String;
        } else if (dayEntries.isNotEmpty) {
          final hasPending = dayEntries.any((e) => e['status'] != 'synced');
          status[dateStr] = hasPending ? 'PENDIENTE' : 'COMPLETO';
        } else {
          status[dateStr] = 'SIN_REGISTRO';
        }
      }

      if (mounted) {
        setState(() {
          _entryCounts = counts;
          _dayStatus = status;
        });
      }
    } catch (e) {
      debugPrint('Calendar load error: $e');
      if (mounted) {
        setState(() {
          _entryCounts = {};
          _dayStatus = {};
        });
      }
    }
  }

  void _goToPreviousMonth() {
    setState(() => _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1));
    _loadMonth();
  }

  void _goToNextMonth() {
    setState(() => _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1));
    _loadMonth();
  }

  void _goToToday() {
    setState(() => _currentMonth = DateTime.now());
    _loadMonth();
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'CERRADO':
      case 'COMPLETO':
        return const Color(0xFF22C55E);
      case 'CERRADO_CON_OBSERVACION':
      case 'CERRADO_OBSERVACION':
        return const Color(0xFF3B82F6);
      case 'PENDIENTE':
        return const Color(0xFFF59E0B);
      case 'REABIERTO':
        return const Color(0xFFF97316);
      default:
        return Colors.transparent;
    }
  }

  void _showDayDetail(String dateStr) {
    final entryCount = _entryCounts[dateStr] ?? 0;
    final status = _dayStatus[dateStr] ?? 'SIN_REGISTRO';
    final statusColor = _getStatusColor(status);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
        decoration: const BoxDecoration(
          color: Color(0xFF0F172A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          entryCount > 0 ? Icons.event_note : Icons.event_busy,
                          color: statusColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              DateFormat('EEEE, dd MMMM yyyy', 'es').format(DateTime.parse(dateStr)),
                              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: statusColor,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _getStatusLabel(status),
                                  style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3B82F6).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '$entryCount registro${entryCount != 1 ? 's' : ''}',
                          style: const TextStyle(color: Color(0xFF3B82F6), fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (entryCount > 0) ...[
                    Text(
                      'Registros del dia',
                      style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    FutureBuilder<List<FormEntry>>(
                      future: _getEntriesForDate(dateStr),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator(color: Color(0xFF3B82F6)));
                        }
                        if (!snapshot.hasData || snapshot.data!.isEmpty) {
                          return const SizedBox();
                        }
                        final entries = snapshot.data!;
                        return ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: entries.length,
                          separatorBuilder: (context, index) => const Divider(color: Colors.white10, height: 1),
                          itemBuilder: (context, index) {
                            final entry = entries[index];
                            return _buildEntryTile(entry);
                          },
                        );
                      },
                    ),
                  ] else ...[
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Column(
                          children: [
                            Icon(Icons.inbox_outlined, size: 48, color: Colors.white.withOpacity(0.15)),
                            const SizedBox(height: 8),
                            Text(
                              'Sin registros para este dia',
                              style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<List<FormEntry>> _getEntriesForDate(String dateStr) async {
    final db = await _localDb.database;
    final rows = await db.query(
      'form_entries',
      where: 'date = ?',
      whereArgs: [dateStr],
      orderBy: 'created_at DESC',
    );
    return rows.map((row) {
      return FormEntry(
        id: row['id'] as String,
        module: row['module'] as String,
        subModule: row['sub_module'] as String?,
        date: row['date'] as String,
        userId: row['user_id'] as String,
        deviceId: row['device_id'] as String,
        version: row['version'] as int,
        data: {},
        status: row['status'] as String,
        createdAt: row['created_at'] as String,
        updatedAt: row['updated_at'] as String,
      );
    }).toList();
  }

  Widget _buildEntryTile(FormEntry entry) {
    final moduleColor = _getModuleColor(entry.module);
    final moduleIcon = _getModuleIcon(entry.module);
    final moduleLabel = _getModuleLabel(entry.module);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: moduleColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(moduleIcon, size: 18, color: moduleColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  moduleLabel,
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                ),
                if (entry.subModule != null)
                  Text(
                    entry.subModule!,
                    style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _getEntryStatusColor(entry.status).withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              entry.status.toUpperCase(),
              style: TextStyle(color: _getEntryStatusColor(entry.status), fontSize: 10, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'CERRADO':
        return 'Dia Cerrado';
      case 'CERRADO_CON_OBSERVACION':
      case 'CERRADO_OBSERVACION':
        return 'Cerrado con Observaciones';
      case 'COMPLETO':
        return 'Completo';
      case 'PENDIENTE':
        return 'Pendiente';
      case 'REABIERTO':
        return 'Reabierto';
      default:
        return 'Sin Registro';
    }
  }

  Color _getModuleColor(String module) {
    switch (module) {
      case 'incubadoras':
        return const Color(0xFFFF6B6B);
      case 'autoclaves':
        return const Color(0xFFFFA94D);
      case 'ultracongeladores':
        return const Color(0xFF4DABF7);
      case 'equipos':
        return const Color(0xFF69DB7C);
      case 'procesamiento':
        return const Color(0xFFB197FC);
      case 'bitacora':
        return const Color(0xFFE91E63);
      default:
        return const Color(0xFF3B82F6);
    }
  }

  IconData _getModuleIcon(String module) {
    switch (module) {
      case 'incubadoras':
        return Icons.thermostat;
      case 'autoclaves':
        return Icons.local_fire_department;
      case 'ultracongeladores':
        return Icons.ac_unit;
      case 'equipos':
        return Icons.precision_manufacturing;
      case 'procesamiento':
        return Icons.biotech;
      case 'bitacora':
        return Icons.book;
      default:
        return Icons.folder;
    }
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
      case 'bitacora':
        return 'Bitacora General';
      default:
        return module;
    }
  }

  Color _getEntryStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'saved':
        return const Color(0xFF22C55E);
      case 'synced':
        return const Color(0xFF3B82F6);
      case 'pending':
        return const Color(0xFFF59E0B);
      default:
        return Colors.white54;
    }
  }

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final lastDay = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
    final startWeekday = (firstDay.weekday) % 7;
    final daysInMonth = lastDay.day;
    final today = DateTime.now();
    final isCurrentMonth = _currentMonth.year == today.year && _currentMonth.month == today.month;

    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      appBar: AppBar(
        title: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFF3B82F6), Color(0xFF6366F1)],
          ).createShader(bounds),
          child: const Text(
            'Calendario Operativo',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          Consumer<SyncEngine>(
            builder: (context, sync, _) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: sync.isOnline ? const Color(0xFF22C55E).withOpacity(0.15) : const Color(0xFFEF4444).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  sync.isOnline ? Icons.wifi : Icons.wifi_off,
                  color: sync.isOnline ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
                  size: 16,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF020617), Color(0xFF0F172A)],
          ),
        ),
        child: Column(
          children: [
            _buildMonthSelector(isCurrentMonth),
            _buildLegend(),
            const Divider(color: Colors.white10, height: 1),
            _buildWeekdays(),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF3B82F6)))
                  : _buildGrid(daysInMonth, startWeekday, today),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthSelector(bool isCurrentMonth) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, size: 28),
            onPressed: _goToPreviousMonth,
            color: Colors.white,
          ),
          Column(
            children: [
              Text(
                DateFormat('MMMM yyyy', 'es').format(_currentMonth),
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
              ),
              if (isCurrentMonth)
                Text(
                  'Mes actual',
                  style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11),
                ),
            ],
          ),
          Row(
            children: [
              if (!isCurrentMonth)
                TextButton(
                  onPressed: _goToToday,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  child: const Text('Hoy', style: TextStyle(color: Color(0xFF3B82F6), fontWeight: FontWeight.w600)),
                ),
              IconButton(
                icon: const Icon(Icons.chevron_right, size: 28),
                onPressed: _goToNextMonth,
                color: Colors.white,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _legendItem(const Color(0xFF22C55E), 'Completo'),
          const SizedBox(width: 16),
          _legendItem(const Color(0xFFF59E0B), 'Pendiente'),
          const SizedBox(width: 16),
          _legendItem(const Color(0xFF3B82F6), 'C/Observ.'),
          const SizedBox(width: 16),
          _legendItem(Colors.white24, 'Sin Registro'),
        ],
      ),
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11)),
      ],
    );
  }

  Widget _buildWeekdays() {
    const weekdays = ['Lun', 'Mar', 'Mie', 'Jue', 'Vie', 'Sab', 'Dom'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: weekdays.map((d) => Expanded(
          child: Center(
            child: Text(
              d,
              style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildGrid(int daysInMonth, int startWeekday, DateTime today) {
    final totalCells = startWeekday + daysInMonth;
    final rows = (totalCells / 7).ceil();

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: rows,
      itemBuilder: (context, rowIndex) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: List.generate(7, (colIndex) {
            final cellIndex = rowIndex * 7 + colIndex;
            if (cellIndex < startWeekday || cellIndex >= totalCells) {
              return const Expanded(child: SizedBox());
            }

            final day = cellIndex - startWeekday + 1;
            final dateStr = '${_currentMonth.year}-${_currentMonth.month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
            final entryCount = _entryCounts[dateStr] ?? 0;
            final status = _dayStatus[dateStr] ?? 'SIN_REGISTRO';
            final isToday = dateStr == '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
            final statusColor = _getStatusColor(status);
            final hasEntries = entryCount > 0;

            return Expanded(
              child: GestureDetector(
                onTap: () => _showDayDetail(dateStr),
                child: Container(
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: isToday
                        ? const Color(0xFF3B82F6).withOpacity(0.15)
                        : hasEntries
                            ? statusColor.withOpacity(0.08)
                            : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isToday
                          ? const Color(0xFF3B82F6).withOpacity(0.4)
                          : hasEntries
                              ? statusColor.withOpacity(0.2)
                              : Colors.white.withOpacity(0.04),
                      width: isToday ? 1.5 : 1,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$day',
                          style: TextStyle(
                            color: isToday ? const Color(0xFF3B82F6) : Colors.white.withOpacity(0.7),
                            fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                        const Spacer(),
                        if (hasEntries)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Center(
                              child: Text(
                                '$entryCount',
                                style: TextStyle(
                                  color: statusColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
