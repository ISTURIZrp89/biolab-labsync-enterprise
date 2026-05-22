import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/db.dart';
import '../../security/auth_service.dart';
import '../../sync/sync_engine.dart';
import '../../services/notification_service.dart';
import '../../services/closure_service.dart';
import '../../services/user_service.dart';
import '../../security/permission_service.dart';
import '../../security/edit_lock_service.dart';
import '../../ai/ai_service.dart';
import '../../domain/entities/user.dart';
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
  Set<String> _allowedModules = {};
  bool _permLoaded = false;

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
    _loadPermissions();
    _loadStats();
  }

  Future<void> _loadPermissions() async {
    try {
      final auth = context.read<AuthService>();
      final permService = context.read<PermissionService>();
      await permService.loadPermissions(auth);
      _allowedModules = permService.allowedModules;
    } catch (_) {
      _allowedModules = {'incubadoras', 'autoclaves', 'ultracongeladores', 'equipos', 'procesamiento', 'bitacora'};
    }
    if (mounted) setState(() => _permLoaded = true);
  }

  Future<void> _loadStats() async {
    try {
      final db = await LocalDatabase.instance.database;
      final today = _selectedDate.toIso8601String().split('T')[0];
      final counts = <String, int>{};

      for (final key in _moduleKeys) {
        if (key.isEmpty || !_allowedModules.contains(key)) continue;
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

      try {
        final closureService = context.read<ClosureService>();
        await closureService.loadMonthClosures(_selectedDate.year, _selectedDate.month);
        await closureService.loadDailyClosures(today);
      } catch (_) {}

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
    try {
      final permService = context.read<PermissionService>();
      if (!permService.canAccess(module)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('No tienes permiso para acceder a este modulo'),
            backgroundColor: OmniTheme.orange400,
          ));
        }
        return;
      }
    } catch (_) {}
    final auth = context.read<AuthService>();
    auth.recordActivity();
    Navigator.push(context, MaterialPageRoute(builder: (_) => FormEntryScreen(module: module, moduleLabel: label)));
  }

  List<int> _getFilteredIndices() {
    return [0, 1, 2, 3, 4, 5, 6, 7]
      .where((i) => i < 2 || _allowedModules.contains(_moduleKeys[i]))
      .toList();
  }

  Widget _buildNavRail(bool extended) {
    final auth = context.watch<AuthService>();
    final sync = context.watch<SyncEngine>();
    final filteredIndices = _getFilteredIndices();
    final filteredItems = filteredIndices.map((i) => _navItems[i]).toList();

    return NavigationRail(
      selectedIndex: filteredIndices.indexOf(_selectedIndex).clamp(0, filteredIndices.length - 1),
      onDestinationSelected: (pos) {
        final i = filteredIndices[pos];
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
            Text(auth.currentUser?.cargoOperativo.isNotEmpty == true ? auth.currentUser!.cargoOperativo : (auth.currentUser?.rol ?? ''), style: const TextStyle(fontSize: 7, color: OmniTheme.accentBlue), overflow: TextOverflow.ellipsis),
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
            _buildNotificationBell(),
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
      destinations: filteredItems.asMap().entries.map((entry) {
        final pos = entry.key;
        final item = entry.value;
        final origIdx = filteredIndices[pos];
        final isSelected = _selectedIndex == origIdx;
        return NavigationRailDestination(
          icon: Icon(item.icon, size: 18, color: OmniTheme.textMuted),
          selectedIcon: Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: _moduleColors[origIdx]?.withOpacity(0.15) ?? Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(item.selectedIcon, size: 18, color: _moduleColors[origIdx] ?? OmniTheme.accentBlue),
          ),
          label: Text(item.label, style: TextStyle(fontSize: 10, color: isSelected ? OmniTheme.accentBlue : OmniTheme.textMuted)),
        );
      }).toList(),
    );
  }

  Widget _buildNotificationBell() {
    final notif = context.watch<NotificationService>();
    final count = notif.unreadCount;
    return Stack(
      children: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined, size: 20),
          onPressed: () => _showNotificationDrawer(notif),
          color: count > 0 ? OmniTheme.accentBlue : OmniTheme.textMuted,
          tooltip: 'Notificaciones',
        ),
        if (count > 0)
          Positioned(
            right: 4, top: 4,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(color: OmniTheme.red400, shape: BoxShape.circle),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text('$count', style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white), textAlign: TextAlign.center),
            ),
          ),
      ],
    );
  }

  void _showNotificationDrawer(NotificationService notif) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: OmniTheme.bg900,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.4,
        maxChildSize: 0.7,
        minChildSize: 0.2,
        expand: false,
        builder: (_, scrollController) {
          final notifications = notif.notifications;
          return Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: OmniTheme.bg800))),
                child: Row(
                  children: [
                    const Text('Notificaciones', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: OmniTheme.textPrimary)),
                    const Spacer(),
                    if (notifications.isNotEmpty)
                      TextButton(
                        onPressed: () => notif.dismissAll(),
                        child: const Text('Limpiar', style: TextStyle(fontSize: 12, color: OmniTheme.textMuted)),
                      ),
                    IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(context)),
                  ],
                ),
              ),
              Expanded(
                child: notifications.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.notifications_none, size: 40, color: OmniTheme.bg700),
                          const SizedBox(height: 8),
                          const Text('Sin notificaciones', style: TextStyle(color: OmniTheme.textMuted, fontSize: 12)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.all(8),
                      itemCount: notifications.length,
                      itemBuilder: (_, i) {
                        final n = notifications[i];
                        return Dismissible(
                          key: Key(n.id),
                          onDismissed: (_) => notif.dismiss(n.id),
                          child: Card(
                            margin: const EdgeInsets.only(bottom: 4),
                            child: ListTile(
                              dense: true,
                              leading: Icon(n.icon, size: 18, color: n.color),
                              title: Text(n.title, style: const TextStyle(fontSize: 12, color: OmniTheme.textPrimary)),
                              subtitle: n.message.isNotEmpty
                                ? Text(n.message, style: const TextStyle(fontSize: 10, color: OmniTheme.textMuted))
                                : null,
                              trailing: IconButton(
                                icon: const Icon(Icons.close, size: 14, color: OmniTheme.textMuted),
                                onPressed: () => notif.dismiss(n.id),
                              ),
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

  Widget _buildSyncDot(SyncEngine sync) {
    return GestureDetector(
      onTap: () async {
        if (sync.isOnline) {
          try { await sync.synchronize(); _loadStats(); } catch (_) {}
        } else {
          await sync.checkOnline();
        }
      },
      onLongPress: () => _showSyncLog(sync),
      child: Container(
        width: 28, height: 28,
        decoration: BoxDecoration(color: OmniTheme.bg800, borderRadius: BorderRadius.circular(8)),
        child: Center(
          child: sync.isSyncing
              ? const SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 1.5, color: OmniTheme.accentBlue))
              : Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(
                    color: sync.isOnline ? OmniTheme.green400 : OmniTheme.red400,
                    shape: BoxShape.circle,
                    boxShadow: sync.isOnline ? [BoxShadow(color: OmniTheme.green400.withOpacity(0.4), blurRadius: 6)] : null,
                  ),
                ),
        ),
      ),
    );
  }

  void _showSyncLog(SyncEngine sync) {
    final log = sync.syncLog;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: OmniTheme.bg900,
        title: const Row(children: [
          Icon(Icons.sync, size: 18, color: OmniTheme.accentBlue),
          SizedBox(width: 8),
          Text('Sincronización', style: TextStyle(fontSize: 14, color: OmniTheme.textPrimary, fontWeight: FontWeight.bold)),
        ]),
        content: SizedBox(
          width: 400,
          height: 400,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                _statChip('En línea', sync.isOnline ? 'Sí' : 'No', sync.isOnline ? OmniTheme.green400 : OmniTheme.red400),
                const SizedBox(width: 8),
                _statChip('Exitosas', '${sync.syncCount}', OmniTheme.green400),
                const SizedBox(width: 8),
                _statChip('Fallidas', '${sync.failedCount}', OmniTheme.red400),
              ]),
              const SizedBox(height: 12),
              if (sync.lastSync != null)
                Text('Última sincronización: ${_formatTime(sync.lastSync!)}', style: const TextStyle(fontSize: 10, color: OmniTheme.textMuted)),
              const SizedBox(height: 12),
              const Text('Historial:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: OmniTheme.textPrimary)),
              const SizedBox(height: 4),
              Expanded(
                child: log.isEmpty
                    ? Center(
                        child: TextButton.icon(
                          icon: const Icon(Icons.sync, size: 16),
                          label: const Text('Sincronizar ahora', style: TextStyle(fontSize: 12)),
                          onPressed: () async {
                            await sync.synchronize();
                            if (ctx.mounted) Navigator.pop(ctx);
                          },
                        ),
                      )
                    : ListView.builder(
                        itemCount: log.length,
                        itemBuilder: (_, i) {
                          final item = log[i];
                          final status = item['status'] as String? ?? '';
                          return Container(
                            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                            margin: const EdgeInsets.only(bottom: 4),
                            decoration: BoxDecoration(
                              color: status == 'success' ? OmniTheme.green400.withOpacity(0.08) : OmniTheme.red400.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(children: [
                              Icon(
                                status == 'success' ? Icons.check_circle : Icons.error,
                                size: 12,
                                color: status == 'success' ? OmniTheme.green400 : OmniTheme.red400,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  item['action'] as String? ?? '',
                                  style: TextStyle(fontSize: 10, color: status == 'success' ? OmniTheme.green400 : OmniTheme.red400),
                                ),
                              ),
                              Text(_formatTime(DateTime.parse(item['timestamp'] as String)), style: const TextStyle(fontSize: 8, color: OmniTheme.textMuted)),
                            ]),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar', style: TextStyle(color: OmniTheme.textMuted))),
          if (sync.failedCount > 0)
            TextButton(
              onPressed: () async {
                await sync.retryFailed();
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Reintentar fallidos', style: TextStyle(color: OmniTheme.orange400)),
            ),
        ],
      ),
    );
  }

  Widget _statChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6), border: Border.all(color: color.withOpacity(0.2))),
      child: Column(children: [
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: TextStyle(fontSize: 8, color: color.withOpacity(0.8))),
      ]),
    );
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
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

  Color _statusColor(String status) {
    switch (status) {
      case 'CERRADO': return OmniTheme.green400;
      case 'REABIERTO': return OmniTheme.orange400;
      default: return OmniTheme.textMuted;
    }
  }

  Widget _buildCalendar(DateTime now, List<String> dayNames) {
    final firstDay = DateTime(_selectedDate.year, _selectedDate.month, 1);
    final lastDay = DateTime(_selectedDate.year, _selectedDate.month + 1, 0);
    final startWeekday = firstDay.weekday;
    final closureService = context.watch<ClosureService>();
    final closureStatuses = closureService.getDailyStatusesForMonth(_selectedDate.year, _selectedDate.month);
    final statusMap = <String, String>{};
    for (final s in closureStatuses) {
      statusMap[s['date'] as String] = s['status'] as String;
    }

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
                  final closureStatus = statusMap[dateStr] ?? 'ABIERTO';
                  final statusColor = _statusColor(closureStatus);
                  final hasData = entryCount > 0 || closureStatus == 'CERRADO';

                  Color? bgColor;
                  String statusIcon = '';
                  Color statusIconColor = OmniTheme.accentBlue;
                  if (closureStatus == 'CERRADO') {
                    bgColor = OmniTheme.green400.withOpacity(0.15);
                    statusIcon = '✓';
                    statusIconColor = OmniTheme.green400;
                  } else if (closureStatus == 'REABIERTO') {
                    bgColor = OmniTheme.orange400.withOpacity(0.15);
                    statusIcon = '↩';
                    statusIconColor = OmniTheme.orange400;
                  } else if (isToday) {
                    bgColor = OmniTheme.accentBlue.withOpacity(0.25);
                    statusIcon = '●';
                    statusIconColor = OmniTheme.accentBlue;
                  } else if (entryCount > 0) {
                    bgColor = OmniTheme.accentBlue.withOpacity(0.1);
                    statusIcon = '$entryCount';
                    statusIconColor = OmniTheme.accentBlue;
                  }

                  return GestureDetector(
                    onTap: () => _showDayEntries(dateStr),
                    child: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(8),
                        border: isToday ? Border.all(color: OmniTheme.accentBlue, width: 1.5) : null,
                      ),
                      child: Stack(
                        children: [
                          Center(child: Text('$day', style: TextStyle(
                            fontSize: 12, fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                            color: isToday ? OmniTheme.accentBlue : (hasData ? OmniTheme.textPrimary : OmniTheme.textMuted),
                          ))),
                          Positioned(
                            bottom: 1, right: 2,
                            child: Text(statusIcon, style: TextStyle(fontSize: 7, fontWeight: FontWeight.bold, color: statusIconColor)),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              );
            }),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _legendDot(OmniTheme.green400, 'Cerrado'),
              const SizedBox(width: 12),
              _legendDot(OmniTheme.orange400, 'Reabierto'),
              const SizedBox(width: 12),
              _legendDot(OmniTheme.accentBlue, 'Datos'),
              const SizedBox(width: 12),
              _legendDot(OmniTheme.accentBlue, 'Hoy'),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 9, color: OmniTheme.textMuted)),
    ]);
  }

  void _showDayEntries(String dateStr) {
    final entries = _dayEntries[dateStr] ?? [];
    final allModules = ['incubadoras', 'autoclaves', 'ultracongeladores', 'equipos', 'procesamiento', 'bitacora'];
    final modules = allModules.where((m) => _allowedModules.contains(m)).toList();
    final moduleLabels = ['Incubadoras', 'Autoclaves', 'Ultracongeladores', 'Equipos', 'Procesamiento', 'Bitacora'];

    final isDesktop = MediaQuery.of(context).size.width > 800;

    if (isDesktop) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: OmniTheme.bg900,
          contentPadding: EdgeInsets.zero,
          content: SizedBox(
            width: 600,
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                entries.isEmpty
                    ? Container(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inbox_outlined, size: 40, color: OmniTheme.bg700),
                            const SizedBox(height: 8),
                            const Text('Sin registros este dia', style: TextStyle(color: OmniTheme.textMuted, fontSize: 12)),
                          ],
                        ),
                      )
                    : SizedBox(
                        height: 400,
                        child: ListView.builder(
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
            ),
          ),
        ),
      );
    } else {
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
  }

  Widget _buildDailyStatus() {
    final auth = context.watch<AuthService>();
    final closureService = context.watch<ClosureService>();
    final today = DateTime.now().toIso8601String().split('T')[0];
    final todayClosure = closureService.getDayClosure(today);
    final isTodayClosed = todayClosure?.isClosed == true;
    final isTodayReopened = todayClosure?.isReopened == true;

    final allModules = [
      ('incubadoras', 'Incubadoras', Icons.thermostat_outlined, OmniTheme.red400),
      ('autoclaves', 'Autoclaves', Icons.local_fire_department_outlined, OmniTheme.orange400),
      ('ultracongeladores', 'Ultracongeladores', Icons.ac_unit_outlined, OmniTheme.accentBlue),
      ('equipos', 'Equipos', Icons.precision_manufacturing_outlined, OmniTheme.green400),
      ('procesamiento', 'Procesamiento', Icons.biotech_outlined, const Color(0xFFB197FC)),
      ('bitacora', 'Bitacora', Icons.book_outlined, const Color(0xFFF472B6)),
    ];
    final modules = allModules.where((m) => _allowedModules.contains(m.$1)).toList();

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
            const SizedBox(height: 8),
            Row(children: [
              Container(
                width: 8, height: 8,
                decoration: BoxDecoration(
                  color: isTodayClosed ? OmniTheme.green400 : (isTodayReopened ? OmniTheme.orange400 : OmniTheme.yellow400),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                isTodayReopened ? 'REABIERTO' : (isTodayClosed ? 'CERRADO' : 'ABIERTO'),
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isTodayClosed ? OmniTheme.green400 : (isTodayReopened ? OmniTheme.orange400 : OmniTheme.yellow400)),
              ),
              const Spacer(),
              if (auth.canClose && !isTodayClosed)
                TextButton.icon(
                  icon: const Icon(Icons.lock, size: 14),
                  label: const Text('Cerrar dia', style: TextStyle(fontSize: 11)),
                  onPressed: () => _confirmCloseDay(today, auth.currentUser!),
                  style: TextButton.styleFrom(foregroundColor: OmniTheme.green400),
                ),
              if (auth.canReopen && isTodayClosed)
                TextButton.icon(
                  icon: const Icon(Icons.lock_open, size: 14),
                  label: const Text('Reabrir', style: TextStyle(fontSize: 11)),
                  onPressed: () => _showReopenDialog(today, auth.currentUser!),
                  style: TextButton.styleFrom(foregroundColor: OmniTheme.orange400),
                ),
            ]),
            if (todayClosure?.notes != null && todayClosure!.notes!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('Notas: ${todayClosure.notes}', style: const TextStyle(fontSize: 10, color: OmniTheme.textMuted, fontStyle: FontStyle.italic)),
              ),
            const SizedBox(height: 8),
            ...modules.map((m) {
              final count = _moduleCounts[m.$1] ?? 0;
              return _buildModuleRow(m.$2, m.$3, m.$4, count, m.$1);
            }),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmCloseDay(String date, User user) async {
    try {
      final aiService = context.read<AiService>();
      final db = await LocalDatabase.instance.database;
      final entries = await db.query('form_entries', where: 'date = ?', whereArgs: [date]);
      final allIssues = <String>[];
      for (final row in entries) {
        Map<String, dynamic> data = {};
        try {
          data = jsonDecode(row['data_json'] as String) as Map<String, dynamic>;
        } catch (_) {}
        final issues = aiService.validateEntryForClosure(data);
        if (issues.isNotEmpty) {
          allIssues.add('${row['module']}: ${issues.join(", ")}');
        }
      }
      if (allIssues.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Observaciones: ${allIssues.take(3).join(" | ")}'),
            backgroundColor: OmniTheme.orange400,
            duration: const Duration(seconds: 4),
          ));
        }
      }
    } catch (_) {}

    final notesCtrl = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: OmniTheme.bg900,
        title: const Text('Cerrar dia', style: TextStyle(color: Colors.white)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Confirmar cierre del dia $date?', style: const TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 12),
          TextField(
            controller: notesCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Notas (opcional)',
              labelStyle: TextStyle(color: Colors.white54),
              border: OutlineInputBorder(),
            ),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: OmniTheme.green400),
            child: const Text('Confirmar cierre', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      try {
        await context.read<ClosureService>().closeDay(date, user, notes: notesCtrl.text);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Dia $date cerrado exitosamente'),
          backgroundColor: OmniTheme.green400,
        ));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: OmniTheme.red400,
        ));
      }
    }
  }

  Future<void> _showReopenDialog(String date, User user) async {
    final motivoCtrl = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: OmniTheme.bg900,
        title: const Text('Reabrir dia', style: TextStyle(color: Colors.white)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Reabrir el dia $date? (maximo 3 dias desde cierre)', style: const TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 12),
          TextField(
            controller: motivoCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Motivo de reapertura *',
              labelStyle: TextStyle(color: Colors.white54),
              border: OutlineInputBorder(),
            ),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            onPressed: motivoCtrl.text.isNotEmpty ? () => Navigator.pop(ctx, true) : null,
            style: ElevatedButton.styleFrom(backgroundColor: OmniTheme.orange400),
            child: const Text('Reabrir', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      try {
        await context.read<ClosureService>().reopenDay(date, user, motivo: motivoCtrl.text);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Dia $date reabierto'),
          backgroundColor: OmniTheme.orange400,
        ));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: OmniTheme.red400,
        ));
      }
    }
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
    if (_pendingCount <= 0 && context.read<SyncEngine>().failedCount <= 0) return const SizedBox.shrink();
    final sync = context.read<SyncEngine>();
    final isFailed = sync.failedCount > 0;
    final color = isFailed ? OmniTheme.red400 : OmniTheme.orange400;
    final icon = isFailed ? Icons.sync_problem : Icons.cloud_upload_outlined;
    final msg = isFailed
        ? '${sync.failedCount} sincronizaciones fallidas - toca para reintentar'
        : '$_pendingCount registros pendientes de sincronizar';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        dense: true,
        leading: Icon(icon, color: color, size: 18),
        title: Text(msg, style: TextStyle(fontSize: 11, color: color)),
        trailing: sync.isSyncing
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.sync, size: 16, color: OmniTheme.textMuted),
        onTap: () async {
          try {
            if (isFailed) {
              await sync.retryFailed();
            } else {
              await sync.synchronize();
            }
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
