import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/db.dart';
import '../../security/auth_service.dart';
import '../../sync/sync_engine.dart';
import '../../theme/omni_theme.dart';
import 'form_entry_screen.dart';
import 'settings_screen.dart';
import 'reports_screen.dart';
import 'login_screen.dart';

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _selectedIndex = 0;
  int _pendingCount = 0;
  DateTime _selectedDate = DateTime.now();
  Map<String, int> _moduleCounts = {};
  Map<String, int> _dayEntryCounts = {};
  Map<String, List<Map<String, dynamic>>> _dayEntries = {};
  bool _statsLoaded = false;

  static const _navItems = [
    _NavItem('Inicio', Icons.dashboard_outlined, Icons.dashboard),
    _NavItem('Reportes diarios', Icons.bar_chart_outlined, Icons.bar_chart),
    _NavItem('Incubadoras', Icons.thermostat_outlined, Icons.thermostat),
    _NavItem('Autoclaves', Icons.local_fire_department_outlined, Icons.local_fire_department),
    _NavItem('Ultracongeladores', Icons.ac_unit_outlined, Icons.ac_unit),
    _NavItem('Equipos', Icons.precision_manufacturing_outlined, Icons.precision_manufacturing),
    _NavItem('Procesamiento', Icons.biotech_outlined, Icons.biotech),
    _NavItem('Bitacora', Icons.book_outlined, Icons.book),
  ];

  static const _moduleKeys = ['', '', 'incubadoras', 'autoclaves', 'ultracongeladores', 'equipos', 'procesamiento', 'bitacora'];
  static const _moduleColors = [
    null,
    Color(0xFF34D399),
    OmniTheme.red400,
    OmniTheme.orange400,
    OmniTheme.accentBlue,
    OmniTheme.green400,
    Color(0xFFB197FC),
    Color(0xFFF472B6),
  ];

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final db = await LocalDatabase.instance.database;
      final today = _selectedDate.toIso8601String().split('T')[0];
      final counts = <String, int>{};

      for (final key in _moduleKeys) {
        if (key.isEmpty) continue;
        final result = await db.rawQuery(
          'SELECT COUNT(*) as cnt FROM form_entries WHERE module = ? AND date = ?',
          [key, today],
        );
        counts[key] = (result.isNotEmpty ? result.first['cnt'] as int? : null) ?? 0;
      }

      final firstDay = DateTime(_selectedDate.year, _selectedDate.month, 1);
      final lastDay = DateTime(_selectedDate.year, _selectedDate.month + 1, 0);
      final startStr = firstDay.toIso8601String().split('T')[0];
      final endStr = lastDay.toIso8601String().split('T')[0];

      final monthEntries = await db.query(
        'form_entries',
        where: 'date >= ? AND date <= ?',
        whereArgs: [startStr, endStr],
        orderBy: 'date ASC',
      );

      final dayCounts = <String, int>{};
      final dayEntries = <String, List<Map<String, dynamic>>>{};
      for (final e in monthEntries) {
        final d = (e['date'] as String? ?? '').substring(0, 10);
        dayCounts[d] = (dayCounts[d] ?? 0) + 1;
        dayEntries.putIfAbsent(d, () => []).add(e);
      }

      final sync = context.read<SyncEngine>();
      final pending = await sync.getPendingCount();

      if (mounted) setState(() {
        _moduleCounts = counts;
        _pendingCount = pending;
        _dayEntryCounts = dayCounts;
        _dayEntries = dayEntries;
        _statsLoaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => _statsLoaded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 800;

    Widget content;
    if (_selectedIndex == 0) {
      content = _buildDashboard();
    } else {
      content = const SizedBox.shrink();
    }

    return Scaffold(
      backgroundColor: OmniTheme.bg950,
      body: Row(
        children: [
          _buildNavRail(isDesktop),
          const VerticalDivider(width: 1, color: OmniTheme.bg800),
          Expanded(child: content),
        ],
      ),
    );
  }

  void _openModule(String module, String label) {
    if (module.isEmpty) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => FormEntryScreen(module: module, moduleLabel: label)));
  }

  Widget _buildNavRail(bool extended) {
    final auth = context.watch<AuthService>();
    final sync = context.watch<SyncEngine>();

    return NavigationRail(
      selectedIndex: _selectedIndex.clamp(0, _navItems.length - 1),
      onDestinationSelected: (i) {
        if (i == 0) {
          setState(() => _selectedIndex = i);
          _loadStats();
        } else if (i == 1) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportsScreen()));
        } else {
          _openModule(_moduleKeys[i], _navItems[i].label);
        }
      },
      labelType: NavigationRailLabelType.all,
      backgroundColor: OmniTheme.bg900,
      minWidth: extended ? 80 : 64,
      groupAlignment: -1,
      leading: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [OmniTheme.accentBlue, OmniTheme.accentIndigo]),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.person, color: Colors.white, size: 20),
            ),
            const SizedBox(height: 4),
            Text(auth.currentUser?.nombre ?? '', style: const TextStyle(fontSize: 8, color: OmniTheme.textPrimary), overflow: TextOverflow.ellipsis),
            Text(auth.currentUser?.rol ?? '', style: const TextStyle(fontSize: 7, color: OmniTheme.accentBlue), overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
      trailing: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSyncDot(sync),
            const SizedBox(height: 4),
            IconButton(
              icon: const Icon(Icons.settings_outlined, size: 20),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
              color: OmniTheme.textMuted,
              tooltip: 'Configuracion',
            ),
            const SizedBox(height: 4),
            IconButton(
              icon: const Icon(Icons.logout, size: 20),
              onPressed: () {
                try { sync.stopPeriodicSync(); } catch (_) {}
                auth.logout();
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
              },
              color: OmniTheme.red400,
              tooltip: 'Cerrar sesion',
            ),
          ],
        ),
      ),
      destinations: _navItems.asMap().entries.map((entry) {
        final i = entry.key;
        final item = entry.value;
        final isSelected = _selectedIndex == i;
        return NavigationRailDestination(
          icon: Icon(item.icon, size: 18, color: OmniTheme.textMuted),
          selectedIcon: Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: _moduleColors[i]?.withOpacity(0.15) ?? Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(item.selectedIcon, size: 18, color: _moduleColors[i] ?? OmniTheme.accentBlue),
          ),
          label: Text(item.label, style: TextStyle(fontSize: 10, color: isSelected ? OmniTheme.accentBlue : OmniTheme.textMuted)),
        );
      }).toList(),
    );
  }

  Widget _buildSyncDot(SyncEngine sync) {
    return GestureDetector(
      onTap: sync.isOnline ? () async {
        try { await sync.synchronize(); _loadStats(); } catch (_) {}
      } : null,
      child: Container(
        width: 28, height: 28,
        decoration: BoxDecoration(color: OmniTheme.bg800, borderRadius: BorderRadius.circular(8)),
        child: Center(child: Container(
          width: 8, height: 8,
          decoration: BoxDecoration(
            color: sync.isOnline ? OmniTheme.green400 : OmniTheme.red400,
            shape: BoxShape.circle,
            boxShadow: sync.isOnline ? [BoxShadow(color: OmniTheme.green400.withOpacity(0.4), blurRadius: 6)] : null,
          ),
        )),
      ),
    );
  }

  Widget _buildDashboard() {
    final now = DateTime.now();
    final todayStr = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
    final dayNames = ['Lun', 'Mar', 'Mie', 'Jue', 'Vie', 'Sab', 'Dom'];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Panel de Hoy', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: OmniTheme.textPrimary)),
                const SizedBox(height: 4),
                Text(todayStr, style: const TextStyle(fontSize: 12, color: OmniTheme.textMuted)),
              ]),
              const Spacer(),
              _buildMonthNav(now),
            ],
          ),
          const SizedBox(height: 20),
          _buildCalendar(now, dayNames),
          const SizedBox(height: 20),
          _buildDailyStatus(),
          const SizedBox(height: 20),
          _buildPendingBar(),
        ],
      ),
    );
  }

  Widget _buildMonthNav(DateTime now) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left, size: 20),
          onPressed: () => setState(() {
            _selectedDate = DateTime(_selectedDate.year, _selectedDate.month - 1, 1);
            _loadStats();
          }),
          color: OmniTheme.textMuted,
        ),
        Text('${_monthName(_selectedDate.month)} ${_selectedDate.year}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: OmniTheme.textPrimary)),
        IconButton(
          icon: const Icon(Icons.chevron_right, size: 20),
          onPressed: () => setState(() {
            _selectedDate = DateTime(_selectedDate.year, _selectedDate.month + 1, 1);
            _loadStats();
          }),
          color: OmniTheme.textMuted,
        ),
      ],
    );
  }

  Widget _buildCalendar(DateTime now, List<String> dayNames) {
    final firstDay = DateTime(_selectedDate.year, _selectedDate.month, 1);
    final lastDay = DateTime(_selectedDate.year, _selectedDate.month + 1, 0);
    final startWeekday = firstDay.weekday;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: dayNames.map((d) => SizedBox(
                width: 36,
                child: Text(d, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: OmniTheme.textMuted)),
              )).toList(),
            ),
            const SizedBox(height: 8),
            ...List.generate(_weeksCount(firstDay, lastDay), (week) {
              return Row(mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(7, (weekday) {
                  final day = week * 7 + weekday - startWeekday + 2;
                  if (day < 1 || day > lastDay.day) return const SizedBox(width: 36, height: 36);
                  final isToday = now.year == _selectedDate.year && now.month == _selectedDate.month && now.day == day;
                  final dateStr = '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
                  final entryCount = _dayEntryCounts[dateStr] ?? 0;
                  return GestureDetector(
                    onTap: () => _showDayEntries(dateStr),
                    child: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: isToday ? OmniTheme.accentBlue.withOpacity(0.2) : (entryCount > 0 ? OmniTheme.green400.withOpacity(0.08) : null),
                        borderRadius: BorderRadius.circular(8),
                        border: isToday ? Border.all(color: OmniTheme.accentBlue, width: 1.5) : null,
                      ),
                      child: Stack(
                        children: [
                          Center(child: Text('$day', style: TextStyle(
                            fontSize: 12, fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                            color: isToday ? OmniTheme.accentBlue : (entryCount > 0 ? OmniTheme.textPrimary : OmniTheme.textMuted),
                          ))),
                          if (entryCount > 0)
                            Positioned(
                              bottom: 1, right: 1,
                              child: Container(
                                width: 12, height: 12,
                                decoration: BoxDecoration(color: OmniTheme.green400, shape: BoxShape.circle),
                                child: Center(child: Text('$entryCount', style: const TextStyle(fontSize: 7, fontWeight: FontWeight.bold, color: Colors.white))),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                }),
              );
            }),
          ],
        ),
      ),
    );
  }

  void _showDayEntries(String dateStr) {
    final entries = _dayEntries[dateStr] ?? [];
    final modules = ['incubadoras', 'autoclaves', 'ultracongeladores', 'equipos', 'procesamiento', 'bitacora'];
    final moduleLabels = ['Incubadoras', 'Autoclaves', 'Ultracongeladores', 'Equipos', 'Procesamiento', 'Bitacora'];

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
                    Text(dateStr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: OmniTheme.textPrimary)),
                    const Spacer(),
                    Text('${entries.length} registros', style: const TextStyle(fontSize: 12, color: OmniTheme.textMuted)),
                    const SizedBox(width: 12),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.add, size: 18, color: OmniTheme.accentBlue),
                      tooltip: 'Nuevo registro',
                      color: OmniTheme.bg800,
                      onSelected: (module) {
                        Navigator.pop(context);
                        Navigator.push(context, MaterialPageRoute(builder: (_) => FormEntryScreen(module: module, moduleLabel: moduleLabels[modules.indexOf(module)])));
                      },
                      itemBuilder: (_) => modules.asMap().entries.map((e) => PopupMenuItem(value: e.value, child: Text(moduleLabels[e.key], style: const TextStyle(fontSize: 12, color: OmniTheme.textPrimary)))).toList(),
                    ),
                    IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(context)),
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
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: entries.length,
                        itemBuilder: (ctx, index) {
                          final entry = entries[index];
                          Map<String, dynamic> data = {};
                          try { data = jsonDecode(entry['data_json'] as String); } catch (_) {}
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    Container(width: 4, height: 16, decoration: BoxDecoration(
                                      color: entry['status'] == 'synced' ? OmniTheme.green400 : OmniTheme.orange400,
                                      borderRadius: BorderRadius.circular(2),
                                    )),
                                    const SizedBox(width: 8),
                                    Text(entry['module']?.toString().toUpperCase() ?? '', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: OmniTheme.textMuted, letterSpacing: 1)),
                                  ]),
                                  const SizedBox(height: 8),
                                  ...data.entries.take(4).map((e) => Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Row(children: [
                                      Text('${e.key}: ', style: const TextStyle(fontSize: 12, color: OmniTheme.textMuted)),
                                      Expanded(child: Text(e.value?.toString() ?? '-', style: const TextStyle(fontSize: 12, color: OmniTheme.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis)),
                                    ]),
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

  Widget _buildDailyStatus() {
    final modules = [
      ('incubadoras', 'Incubadoras', Icons.thermostat_outlined, OmniTheme.red400),
      ('autoclaves', 'Autoclaves', Icons.local_fire_department_outlined, OmniTheme.orange400),
      ('ultracongeladores', 'Ultracongeladores', Icons.ac_unit_outlined, OmniTheme.accentBlue),
      ('equipos', 'Equipos', Icons.precision_manufacturing_outlined, OmniTheme.green400),
      ('procesamiento', 'Procesamiento', Icons.biotech_outlined, const Color(0xFFB197FC)),
      ('bitacora', 'Bitacora', Icons.book_outlined, const Color(0xFFF472B6)),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Estado del Dia', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: OmniTheme.textPrimary)),
                const Spacer(),
                Text('${modules.where((m) => (_moduleCounts[m.$1] ?? 0) > 0).length}/${modules.length}', style: const TextStyle(fontSize: 12, color: OmniTheme.textMuted)),
              ],
            ),
            const SizedBox(height: 12),
            ...modules.map((m) {
              final count = _moduleCounts[m.$1] ?? 0;
              return _buildModuleRow(m.$2, m.$3, m.$4, count, m.$1);
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildModuleRow(String label, IconData icon, Color color, int count, String moduleKey) {
    final filled = count > 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: () => _openModule(moduleKey, label),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: filled ? color.withOpacity(0.05) : OmniTheme.bg800.withOpacity(0.3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Container(
                width: 8, height: 8,
                decoration: BoxDecoration(color: filled ? color : OmniTheme.bg700, shape: BoxShape.circle),
              ),
              const SizedBox(width: 12),
              Icon(icon, size: 16, color: filled ? color : OmniTheme.bg700),
              const SizedBox(width: 10),
              Expanded(child: Text(label, style: TextStyle(fontSize: 12, color: filled ? OmniTheme.textPrimary : OmniTheme.textMuted))),
              if (count > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
                  child: Text('$count', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
                )
              else
                const Text('Pendiente', style: TextStyle(fontSize: 10, color: OmniTheme.textMuted)),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, size: 14, color: OmniTheme.textMuted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPendingBar() {
    if (_pendingCount <= 0) return const SizedBox.shrink();
    return Card(
      child: ListTile(
        leading: const Icon(Icons.sync_problem, color: OmniTheme.orange400),
        title: Text('$_pendingCount registros pendientes de sincronizar', style: const TextStyle(fontSize: 13, color: OmniTheme.textPrimary)),
        trailing: const Icon(Icons.sync, size: 18, color: OmniTheme.textMuted),
        onTap: () async {
          try {
            final sync = context.read<SyncEngine>();
            await sync.synchronize();
            _loadStats();
          } catch (_) {}
        },
      ),
    );
  }

  int _weeksCount(DateTime first, DateTime last) {
    final totalDays = last.day;
    final startWeekday = first.weekday;
    return ((totalDays + startWeekday - 1) / 7).ceil();
  }

  String _monthName(int m) {
    const months = ['Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'];
    return months[m - 1];
  }
}

class _NavItem {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  const _NavItem(this.label, this.icon, this.selectedIcon);
}
