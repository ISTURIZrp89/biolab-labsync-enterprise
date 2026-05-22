import 'package:flutter/material.dart';
import 'dart:convert';
import '../../data/db.dart';
import '../../domain/form_definitions.dart';
import '../../theme/omni_theme.dart';
import 'form_entry_screen.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  Map<String, int> _entryCounts = {};
  Map<String, List<Map<String, dynamic>>> _dayEntries = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadMonthData();
  }

  Future<void> _loadMonthData() async {
    setState(() => _loading = true);
    try {
      final db = await LocalDatabase.instance.database;
      final year = _focusedMonth.year;
      final month = _focusedMonth.month;
      final start = '$year-${month.toString().padLeft(2, '0')}-01';
      final daysInMonth = DateTime(year, month + 1, 0).day;
      final end = '$year-${month.toString().padLeft(2, '0')}-${daysInMonth.toString().padLeft(2, '0')}';

      final entries = await db.query(
        'form_entries',
        where: 'date >= ? AND date <= ?',
        whereArgs: [start, end],
        orderBy: 'date ASC',
      );

      final counts = <String, int>{};
      final dayEntries = <String, List<Map<String, dynamic>>>{};

      for (final entry in entries) {
        final date = entry['date']?.toString() ?? '';
        final dateKey = date.length >= 10 ? date.substring(0, 10) : date;
        counts[dateKey] = (counts[dateKey] ?? 0) + 1;
        dayEntries.putIfAbsent(dateKey, () => []).add(entry);
      }

      if (mounted) {
        setState(() {
          _entryCounts = counts;
          _dayEntries = dayEntries;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Calendar load error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _prevMonth() {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1, 1);
    });
    _loadMonthData();
  }

  void _nextMonth() {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 1);
    });
    _loadMonthData();
  }

  void _goToToday() {
    setState(() {
      _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
    });
    _loadMonthData();
  }

  @override
  Widget build(BuildContext context) {
    final year = _focusedMonth.year;
    final month = _focusedMonth.month;
    final monthName = _getMonthName(month);
    final firstDayOfWeek = DateTime(year, month, 1).weekday;
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final today = DateTime.now();
    final isCurrentMonth = today.year == year && today.month == month;

    final dayHeaders = ['LUN', 'MAR', 'MIE', 'JUE', 'VIE', 'SAB', 'DOM'];

    return Scaffold(
      backgroundColor: OmniTheme.bg950,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Calendario Operativo'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildMonthHeader(monthName, year, isCurrentMonth),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: dayHeaders.map((d) => Expanded(
                      child: Center(
                        child: Text(
                          d,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: OmniTheme.textMuted,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    )).toList(),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.all(8),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 7,
                      childAspectRatio: 1,
                    ),
                    itemCount: 42,
                    itemBuilder: (context, index) {
                      final dayOffset = index - (firstDayOfWeek - 1);
                      if (dayOffset < 1 || dayOffset > daysInMonth) {
                        return const SizedBox.shrink();
                      }

                      final day = dayOffset;
                      final dateStr = '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
                      final entryCount = _entryCounts[dateStr] ?? 0;
                      final isToday = isCurrentMonth && day == today.day;

                      return GestureDetector(
                        onTap: () => _showDayEntries(dateStr),
                        child: Container(
                          margin: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: isToday
                                ? OmniTheme.accentBlue.withOpacity(0.15)
                                : entryCount > 0
                                    ? OmniTheme.bg800
                                    : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: isToday
                                ? Border.all(color: OmniTheme.accentBlue, width: 1.5)
                                : null,
                          ),
                          child: Stack(
                            children: [
                              Center(
                                child: Text(
                                  '$day',
                                  style: TextStyle(
                                    fontFamily: 'Outfit',
                                    fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                                    fontSize: 14,
                                    color: isToday
                                        ? OmniTheme.accentBlue
                                        : entryCount > 0
                                            ? OmniTheme.textPrimary
                                            : OmniTheme.textMuted,
                                  ),
                                ),
                              ),
                              if (entryCount > 0)
                                Positioned(
                                  bottom: 4,
                                  left: 0,
                                  right: 0,
                                  child: Center(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: OmniTheme.green400.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '$entryCount',
                                        style: const TextStyle(
                                          fontSize: 8,
                                          fontWeight: FontWeight.bold,
                                          color: OmniTheme.green400,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                _buildLegend(),
              ],
            ),
    );
  }

  Widget _buildMonthHeader(String monthName, int year, bool isCurrentMonth) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, size: 24),
            onPressed: _prevMonth,
          ),
          Expanded(
            child: Center(
              child: Text(
                '$monthName $year',
                style: const TextStyle(
                  fontFamily: 'Outfit',
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: OmniTheme.textPrimary,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, size: 24),
            onPressed: _nextMonth,
          ),
          if (!isCurrentMonth) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: _goToToday,
              child: const Text(
                'HOY',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: OmniTheme.accentBlue,
                  letterSpacing: 1,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: OmniTheme.bg800)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _legendItem('Con registros', OmniTheme.green400),
          const SizedBox(width: 24),
          _legendItem('Hoy', OmniTheme.accentBlue),
        ],
      ),
    );
  }

  Widget _legendItem(String label, Color color) {
    return Row(
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
        Text(label, style: const TextStyle(fontSize: 11, color: OmniTheme.textMuted)),
      ],
    );
  }

  void _showDayEntries(String dateStr) {
    final entries = _dayEntries[dateStr] ?? [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: OmniTheme.bg900,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        maxChildSize: 0.8,
        minChildSize: 0.3,
        expand: false,
        builder: (_, scrollController) {
          return Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: OmniTheme.bg800)),
                ),
                child: Row(
                  children: [
                    Text(
                      dateStr,
                      style: const TextStyle(
                        fontFamily: 'Outfit',
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: OmniTheme.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${entries.length} registros',
                      style: const TextStyle(fontSize: 12, color: OmniTheme.textMuted),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      icon: const Icon(Icons.add, size: 18, color: OmniTheme.accentBlue),
                      tooltip: 'Nuevo registro',
                      onPressed: () {
                        Navigator.pop(context);
                        _navigateToCreateEntry(dateStr);
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: entries.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inbox_outlined, size: 40, color: OmniTheme.bg700),
                            const SizedBox(height: 8),
                            const Text('Sin registros este dia', style: TextStyle(color: OmniTheme.textMuted, fontSize: 12)),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('Nuevo registro'),
                              onPressed: () { Navigator.pop(context); _navigateToCreateEntry(dateStr); },
                              style: ElevatedButton.styleFrom(backgroundColor: OmniTheme.accentBlue, foregroundColor: Colors.white),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: entries.length,
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    Map<String, dynamic> data = {};
                    try {
                      data = jsonDecode(entry['data_json'] as String);
                    } catch (_) {}

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 4,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    color: entry['status'] == 'synced'
                                        ? OmniTheme.green400
                                        : OmniTheme.orange400,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  entry['module']?.toString().toUpperCase() ?? '',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: OmniTheme.textMuted,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ...data.entries.take(4).map((e) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                children: [
                                  Text(
                                    '${e.key}: ',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: OmniTheme.textMuted,
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      e.value?.toString() ?? '-',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: OmniTheme.textPrimary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            )),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _navigateToCreateEntry(String dateStr) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: OmniTheme.bg900,
        title: const Text('Seleccionar modulo', style: TextStyle(fontSize: 14, color: OmniTheme.textPrimary)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: formModules.map((m) {
              final label = m['label'] as String? ?? m['module'] as String;
              return ListTile(
                dense: true,
                title: Text(label, style: const TextStyle(fontSize: 13, color: OmniTheme.textPrimary)),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => FormEntryScreen(module: m['module'] as String, moduleLabel: label)));
                },
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: OmniTheme.textMuted))),
        ],
      ),
    );
  }

  String _getMonthName(int month) {
    const names = [
      'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
    ];
    return names[month - 1];
  }
}
