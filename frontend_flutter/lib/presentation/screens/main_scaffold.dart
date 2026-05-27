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
import '../../services/update_service.dart';
import '../../services/license_service.dart';
import '../../services/audit_service.dart';
import '../../sync/lan_discovery_service.dart';
import '../../security/permission_service.dart';
import '../../security/edit_lock_service.dart';
import '../../ai/ai_service.dart';
import '../../ai/distributed/model_manager.dart';
import '../../domain/entities/user.dart';
import '../../theme/omni_theme.dart';
import 'form_entry_screen.dart';
import 'settings_screen.dart';
import 'reports_screen.dart';
import 'login_screen.dart';
import 'ai/model_manager_screen.dart';
import 'ai/ai_terminal_screen.dart';
import '../widgets/update_dialog.dart';
import 'report_cover_preview_screen.dart';

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
  String? _selectedDayDate;
  List<Map<String, dynamic>> _selectedDayEntries = [];
  bool _statsLoaded = false;
  Set<String> _allowedModules = {};
  bool _permLoaded = false;

  static const _navItems = [
    _NavItem('Inicio', Icons.dashboard_outlined, Icons.dashboard),
    _NavItem('Reportes', Icons.bar_chart_outlined, Icons.bar_chart),
    _NavItem('Bitácora', Icons.book_outlined, Icons.book),
    _NavItem('Procesamiento', Icons.biotech_outlined, Icons.biotech),
    _NavItem('Incubadoras', Icons.thermostat_outlined, Icons.thermostat),
    _NavItem('Ultracongeladores', Icons.ac_unit_outlined, Icons.ac_unit),
    _NavItem('Equipos', Icons.precision_manufacturing_outlined, Icons.precision_manufacturing),
    _NavItem('Autoclaves', Icons.local_fire_department_outlined, Icons.local_fire_department),
    _NavItem('Cobre', Icons.science_outlined, Icons.science),
    _NavItem('Muestras', Icons.biotech_outlined, Icons.biotech),
    _NavItem('Modelos IA', Icons.auto_awesome_outlined, Icons.auto_awesome),
    _NavItem('Terminal IA', Icons.terminal_outlined, Icons.terminal),
  ];

  static const _moduleKeys = ['', '', 'bitacora', 'procesamiento', 'incubadoras', 'ultracongeladores', 'equipos', 'autoclaves', 'solucion_cobre', 'muestras', '', ''];
  static const _moduleColors = [
    null,
    Color(0xFF34D399),
    Color(0xFFF472B6),
    Color(0xFFB197FC),
    OmniTheme.red400,
    OmniTheme.accentBlue,
    OmniTheme.green400,
    OmniTheme.orange400,
    Color(0xFF00BCD4),
    Color(0xFFFF6B35),
    Color(0xFFA855F7),
    Color(0xFF00FF41),
  ];

  @override
  void initState() {
    super.initState();
    _loadPermissions();
    _loadStats();
    _checkUpdates();
  }

  void _checkUpdates() async {
    try {
      final updateService = context.read<UpdateService>();
      await updateService.checkForUpdates();
      if (mounted && updateService.hasUpdate) {
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => StatefulBuilder(
              builder: (ctx, setDialogState) {
                updateService.addListener(() {
                  if (ctx.mounted) setDialogState(() {});
                });
                return AlertDialog(
                  backgroundColor: OmniTheme.bg900,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  title: Row(children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: OmniTheme.primary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.system_update, color: OmniTheme.primary, size: 20),
                    ),
                    const SizedBox(width: 10),
                    const Text('Actualizacion disponible', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                  ]),
                  content: SizedBox(
                    width: 360,
                    child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('v${updateService.currentVersion}  →  v${updateService.latestVersion}', style: const TextStyle(color: OmniTheme.textSecondary, fontSize: 13)),
                      if (updateService.releaseNotes.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: OmniTheme.bg800.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(updateService.releaseNotes, style: const TextStyle(color: OmniTheme.textMuted, fontSize: 11), maxLines: 6, overflow: TextOverflow.ellipsis),
                        ),
                      ],
                      if (updateService.isDownloading) ...[
                        const SizedBox(height: 16),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: updateService.downloadProgress > 0 ? updateService.downloadProgress : null,
                            backgroundColor: OmniTheme.bg800,
                            valueColor: const AlwaysStoppedAnimation<Color>(OmniTheme.primary),
                            minHeight: 6,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(updateService.statusMessage, style: const TextStyle(color: OmniTheme.textMuted, fontSize: 10)),
                      ],
                    ]),
                  ),
                  actions: [
                    if (!updateService.isDownloading) ...[
                      if (!updateService.isMandatory)
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Despues', style: TextStyle(color: OmniTheme.textMuted)),
                        ),
                      ElevatedButton(
                        onPressed: () {
                          if (!updateService.isDownloading) {
                            updateService.installNow();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: OmniTheme.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: Text(updateService.isDownloading ? 'Descargando...' : 'Actualizar', style: const TextStyle(color: Colors.white)),
                      ),
                    ],
                  ],
                );
              },
            ),
          );
        }
      }
    } catch (_) {}
  }

  Future<void> _loadPermissions() async {
    try {
      final auth = context.read<AuthService>();
      final permService = context.read<PermissionService>();
      await permService.loadPermissions(auth);
      _allowedModules = permService.allowedModules;
    } catch (_) {
      _allowedModules = {'incubadoras', 'autoclaves', 'ultracongeladores', 'equipos', 'procesamiento', 'bitacora', 'solucion_cobre', 'muestras'};
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 800;
        final isCompact = constraints.maxWidth < 600;

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
              _buildNavRail(isDesktop, isCompact),
              const VerticalDivider(width: 1, color: OmniTheme.bg800),
              Expanded(child: content),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openModule(String module, String label) async {
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
    await Navigator.push(context, _smoothRoute(FormEntryScreen(module: module, moduleLabel: label)));
    if (mounted) _loadStats();
  }

  Route _smoothRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, a, __, child) => FadeTransition(
        opacity: Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
        child: child,
      ),
      transitionDuration: const Duration(milliseconds: 350),
    );
  }

  List<int> _getFilteredIndices() {
    final auth = context.read<AuthService>();
    final isDev = auth.isAdmin || auth.isOwner;
    return [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]
      .where((i) => i < 2 || (i == 10 && isDev) || (i == 11 && isDev && auth.canUseAI) || _allowedModules.contains(_moduleKeys[i]) || (i == 9 && isDev))
      .toList();
  }

  Widget _buildNavRail(bool extended, bool isCompact) {
    final auth = context.watch<AuthService>();
    final sync = context.watch<SyncEngine>();
    final filteredIndices = _getFilteredIndices();
    final filteredItems = filteredIndices.map((i) => _navItems[i]).toList();
    final railWidth = isCompact ? 56.0 : (extended ? 100.0 : 80.0);

    return Container(
      width: railWidth,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [OmniTheme.bg900, OmniTheme.bg950],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            _buildLeading(auth, railWidth),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: filteredItems.length,
                itemBuilder: (ctx, pos) {
                  final i = filteredIndices[pos];
                  final item = filteredItems[pos];
                  final isSelected = _selectedIndex == i;
                  final color = _moduleColors[i] ?? OmniTheme.primary;
                  return _buildNavItem(item, isSelected, color, i, railWidth);
                },
              ),
            ),
            _buildTrailing(sync, auth, railWidth),
          ],
        ),
      ),
    );
  }

  Widget _buildLeading(AuthService auth, double railWidth) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [OmniTheme.primary, OmniTheme.secondary]),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(color: OmniTheme.primary.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2)),
              ],
            ),
            child: const Icon(Icons.biotech, color: Colors.white, size: 22),
          ),
          const SizedBox(height: 4),
          Text(auth.currentUser?.nombre ?? '', style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w600, color: OmniTheme.textPrimary), overflow: TextOverflow.ellipsis, maxLines: 1),
          Text(auth.currentUser?.cargoOperativo.isNotEmpty == true ? auth.currentUser!.cargoOperativo : (auth.currentUser?.rol ?? ''), style: const TextStyle(fontSize: 7, color: OmniTheme.primaryLight), overflow: TextOverflow.ellipsis, maxLines: 1),
        ],
      ),
    );
  }

  Widget _buildNavItem(_NavItem item, bool isSelected, Color color, int origIdx, double railWidth) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          if (origIdx == 0) {
            setState(() => _selectedIndex = origIdx);
            _loadStats();
          } else if (origIdx == 1) {
            Navigator.push(context, _smoothRoute(const ReportsScreen()));
          } else if (origIdx == 10) {
            Navigator.push(context, _smoothRoute(const ModelManagerScreen()));
          } else if (origIdx == 11) {
            Navigator.push(context, _smoothRoute(const AiTerminalScreen()));
          } else {
            _openModule(_moduleKeys[origIdx], _navItems[origIdx].label);
          }
        },
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: isSelected ? Border.all(color: color.withOpacity(0.2), width: 0.5) : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(isSelected ? item.selectedIcon : item.icon, size: 18, color: isSelected ? color : OmniTheme.textMuted),
              const SizedBox(height: 2),
              Text(item.label, style: TextStyle(
                fontSize: 9,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? color : OmniTheme.textMuted,
              ), overflow: TextOverflow.ellipsis, maxLines: 1),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLicenseBadge() {
    final license = context.watch<LicenseService>();
    if (!license.offlineMode) return const SizedBox.shrink();
    return Tooltip(
      message: 'Modo offline - La licencia no pudo verificarse',
      child: Container(
        width: 32, height: 20,
        decoration: BoxDecoration(
          color: OmniTheme.orange400.withOpacity(0.15),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Center(child: Icon(Icons.wifi_off, size: 12, color: OmniTheme.orange400)),
      ),
    );
  }

  Widget _buildNetworkDevicesBtn() {
    return Tooltip(
      message: 'Dispositivos en red',
      child: IconButton(
        icon: const Icon(Icons.devices, size: 18),
        onPressed: () => _showNetworkDevices(),
        color: OmniTheme.textMuted,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      ),
    );
  }

  void _showNetworkDevices() {
    final discovery = context.read<LanDiscoveryService>();
    final peers = discovery.peers;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: OmniTheme.bg900,
        title: Row(children: [
          const Icon(Icons.devices, size: 18, color: OmniTheme.accentBlue),
          const SizedBox(width: 8),
          Text('Dispositivos en Red (${peers.length + 1})', style: const TextStyle(fontSize: 14, color: OmniTheme.textPrimary, fontWeight: FontWeight.bold)),
        ]),
        content: SizedBox(
          width: 360,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.only(bottom: 4),
              decoration: BoxDecoration(color: OmniTheme.green400.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
              child: Row(children: [
                Container(width: 6, height: 6, decoration: const BoxDecoration(color: OmniTheme.green400, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                const Text('Este equipo', style: TextStyle(fontSize: 11, color: OmniTheme.textPrimary)),
              ]),
            ),
            if (peers.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text('No se detectaron otros dispositivos', style: TextStyle(fontSize: 11, color: OmniTheme.textMuted)),
              )
            else
              ...peers.map((p) => Container(
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(color: OmniTheme.bg800, borderRadius: BorderRadius.circular(6)),
                child: Row(children: [
                  Container(width: 6, height: 6, decoration: BoxDecoration(color: OmniTheme.accentBlue, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(p.toString(), style: const TextStyle(fontSize: 11, color: OmniTheme.textPrimary))),
                ]),
              )),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar', style: TextStyle(fontSize: 11))),
        ],
      ),
    );
  }

  Widget _buildTrailing(SyncEngine sync, AuthService auth, double railWidth) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Divider(height: 1, color: OmniTheme.bg800),
          const SizedBox(height: 6),
          _buildSyncDot(sync),
          const SizedBox(height: 4),
          _buildLicenseBadge(),
          const SizedBox(height: 4),
          _buildNetworkDevicesBtn(),
          const SizedBox(height: 4),
          _buildNotificationBell(),
          const SizedBox(height: 4),
          IconButton(
            icon: const Icon(Icons.settings_outlined, size: 20),
            onPressed: () => Navigator.push(context, _smoothRoute(const SettingsScreen())),
            color: OmniTheme.textMuted,
            tooltip: 'Configuracion',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          const SizedBox(height: 4),
          IconButton(
            icon: const Icon(Icons.logout, size: 20),
            onPressed: () {
              try {
                final user = auth.currentUser;
                if (user != null) {
                  context.read<AuditService>().log(
                    action: 'Cierre de sesion',
                    type: 'logout',
                    userId: user.id,
                    userName: user.nombre,
                  );
                }
              } catch (_) {}
              try { sync.stopPeriodicSync(); } catch (_) {}
              auth.logout();
              Navigator.pushReplacement(context, _smoothRoute(const LoginScreen()));
            },
            color: OmniTheme.red400,
            tooltip: 'Cerrar sesion',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
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
    showDialog(
      context: context,
      builder: (ctx) {
        final notifications = notif.notifications;
        return AlertDialog(
          backgroundColor: OmniTheme.bg900,
          contentPadding: EdgeInsets.zero,
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: OmniTheme.bg800)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: OmniTheme.accentBlue.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.notifications, size: 18, color: OmniTheme.accentBlue),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text('Notificaciones',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: OmniTheme.textPrimary)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: OmniTheme.bg800,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text('${notifications.length}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: OmniTheme.textMuted)),
                      ),
                      const SizedBox(width: 8),
                      if (notifications.isNotEmpty)
                        TextButton(
                          onPressed: () { notif.dismissAll(); if (ctx.mounted) Navigator.pop(ctx); },
                          child: const Text('Limpiar', style: TextStyle(fontSize: 11, color: OmniTheme.textMuted)),
                        ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18, color: OmniTheme.textMuted),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                notifications.isEmpty
                  ? Container(
                      padding: const EdgeInsets.symmetric(vertical: 48),
                      child: Column(
                        children: [
                          Icon(Icons.notifications_none, size: 48, color: OmniTheme.bg700),
                          const SizedBox(height: 8),
                          const Text('Sin notificaciones', style: TextStyle(color: OmniTheme.textMuted, fontSize: 12)),
                        ],
                      ),
                    )
                  : SizedBox(
                      height: 360,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: notifications.length,
                        itemBuilder: (_, i) {
                          final n = notifications[i];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 6),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () => notif.dismiss(n.id),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: n.color.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(n.icon, size: 16, color: n.color),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(n.title,
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: OmniTheme.textPrimary)),
                                          if (n.message.isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Text(n.message,
                                              style: const TextStyle(fontSize: 10, color: OmniTheme.textMuted)),
                                          ],
                                          const SizedBox(height: 4),
                                          Text(
                                            '${n.timestamp.hour.toString().padLeft(2, '0')}:${n.timestamp.minute.toString().padLeft(2, '0')}',
                                            style: const TextStyle(fontSize: 8, color: OmniTheme.bg700),
                                          ),
                                        ],
                                      ),
                                    ),
                                    InkWell(
                                      onTap: () => notif.dismiss(n.id),
                                      child: const Padding(
                                        padding: EdgeInsets.all(4),
                                        child: Icon(Icons.close, size: 14, color: OmniTheme.textMuted),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
              ],
            ),
          ),
        );
      },
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
          if (_selectedDayDate != null) ...[
            const SizedBox(height: 16),
            _buildSelectedDayPanel(),
          ],
        ],
      ),
    );
  }

  Widget _buildMonthNav(DateTime now) {
    final auth = context.read<AuthService>();
    return Row(
      children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, size: 20),
            onPressed: () => setState(() {
              _selectedDate = DateTime(_selectedDate.year, _selectedDate.month - 1, 1);
              _selectedDayDate = null;
              _selectedDayEntries = [];
              _loadStats();
            }),
            color: OmniTheme.textMuted,
          ),
          Text('${_monthName(_selectedDate.month)} ${_selectedDate.year}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: OmniTheme.textPrimary)),
          IconButton(
            icon: const Icon(Icons.chevron_right, size: 20),
            onPressed: () => setState(() {
              _selectedDate = DateTime(_selectedDate.year, _selectedDate.month + 1, 1);
              _selectedDayDate = null;
              _selectedDayEntries = [];
              _loadStats();
            }),
            color: OmniTheme.textMuted,
          ),
        if (auth.canClose) ...[
          const SizedBox(width: 8),
          TextButton.icon(
            icon: const Icon(Icons.lock, size: 14),
            label: const Text('Cerrar mes', style: TextStyle(fontSize: 11)),
            onPressed: () => _confirmCloseMonth(_selectedDate.year, _selectedDate.month, auth.currentUser!),
            style: TextButton.styleFrom(foregroundColor: OmniTheme.green400),
          ),
        ],
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

  Widget _buildSelectedDayPanel() {
    final dateStr = _selectedDayDate!;
    final entries = _selectedDayEntries;
    final auth = context.watch<AuthService>();
    final closureService = context.watch<ClosureService>();
    final isClosed = closureService.isDayClosed(dateStr);
    final allModules = ['bitacora', 'procesamiento', 'incubadoras', 'ultracongeladores', 'equipos', 'autoclaves', 'solucion_cobre'];
    final modules = allModules.where((m) => _allowedModules.contains(m)).toList();
    final moduleLabels = ['Bitacora', 'Procesamiento', 'Incubadoras', 'Ultracongeladores', 'Equipos', 'Autoclaves', 'Cobre'];
    final canCloseDay = auth.canClose;
    final dayNum = dateStr.split('-').last;
    final monthNum = dateStr.split('-')[1];
    final yearNum = dateStr.split('-')[0];
    final dateDisplay = '$dayNum/$monthNum/$yearNum';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: OmniTheme.accentBlue.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.calendar_today, size: 16, color: OmniTheme.accentBlue),
                ),
                const SizedBox(width: 10),
                Text(dateDisplay, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: OmniTheme.textPrimary)),
                if (isClosed) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: OmniTheme.green400.withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
                    child: const Text('Cerrado', style: TextStyle(fontSize: 10, color: OmniTheme.green400, fontWeight: FontWeight.bold)),
                  ),
                ],
                const Spacer(),
                Text('${entries.length} registros', style: const TextStyle(fontSize: 12, color: OmniTheme.textMuted)),
                const SizedBox(width: 12),
                if (!isClosed)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.add, size: 18, color: OmniTheme.accentBlue),
                    tooltip: 'Nuevo registro',
                    color: OmniTheme.bg800,
                    onSelected: (module) {
                      Navigator.push(context, MaterialPageRoute(
                        builder: (_) => FormEntryScreen(module: module, moduleLabel: moduleLabels[modules.indexOf(module)]),
                      )).then((_) => _loadStats());
                    },
                    itemBuilder: (_) => modules.asMap().entries.map((e) =>
                      PopupMenuItem(value: e.value, child: Text(moduleLabels[e.key], style: const TextStyle(fontSize: 12, color: OmniTheme.textPrimary)))
                    ).toList(),
                  ),
                if (canCloseDay && !isClosed) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.lock, size: 16, color: OmniTheme.green400),
                    tooltip: 'Cerrar dia',
                    onPressed: () => _confirmCloseDay(dateStr, auth.currentUser!),
                  ),
                ],
                if (isClosed && canCloseDay) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.lock_open, size: 16, color: OmniTheme.orange400),
                    tooltip: 'Reabrir dia',
                    onPressed: () => _showReopenDialog(dateStr, auth.currentUser!),
                  ),
                ],
                IconButton(
                  icon: const Icon(Icons.close, size: 20, color: OmniTheme.textMuted),
                  onPressed: () => setState(() {
                    _selectedDayDate = null;
                    _selectedDayEntries = [];
                  }),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (entries.isEmpty && !isClosed)
              _buildEmptyDayModules(modules, moduleLabels)
            else if (entries.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text('Dia cerrado sin registros', style: TextStyle(color: OmniTheme.textMuted, fontSize: 12))),
              )
            else
              SizedBox(
                height: 300,
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: entries.length,
                  itemBuilder: (ctx, index) {
                    final entry = entries[index];
                    Map<String, dynamic> data = {};
                    try { data = jsonDecode(entry['data_json'] as String); } catch (_) {}
                    final moduleKey = entry['module']?.toString() ?? '';
                    final modIdx = modules.indexOf(moduleKey);
                    final label = modIdx >= 0 ? moduleLabels[modIdx] : moduleKey.toUpperCase();
                      return Card(
                      margin: const EdgeInsets.only(bottom: 6),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(
                            builder: (_) => FormEntryScreen(module: moduleKey, moduleLabel: label),
                          )).then((_) => _loadStats());
                        },
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
                                Text(label.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: OmniTheme.textMuted, letterSpacing: 1)),
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
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyDayModules(List<String> modules, List<String> labels) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: modules.asMap().entries.map((e) {
        final colors = [OmniTheme.accentBlue, OmniTheme.red400, OmniTheme.green400, OmniTheme.orange400, const Color(0xFFF472B6), const Color(0xFFB197FC), const Color(0xFF00BCD4)];
        final icons = [Icons.book_outlined, Icons.biotech_outlined, Icons.thermostat_outlined, Icons.ac_unit_outlined, Icons.precision_manufacturing_outlined, Icons.local_fire_department_outlined, Icons.science_outlined];
        return ActionChip(
          avatar: Icon(icons[e.key % icons.length], size: 14, color: colors[e.key % colors.length]),
          label: Text(labels[e.key], style: const TextStyle(fontSize: 11)),
          onPressed: () {
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => FormEntryScreen(module: e.value, moduleLabel: labels[e.key]),
            )).then((_) => _loadStats());
          },
        );
      }).toList(),
    );
  }

  void _showDayEntries(String dateStr) {
    setState(() {
      _selectedDayDate = dateStr;
      _selectedDayEntries = _dayEntries[dateStr] ?? [];
    });
    final entries = _selectedDayEntries;
    final allModules = ['bitacora', 'procesamiento', 'incubadoras', 'ultracongeladores', 'equipos', 'autoclaves', 'solucion_cobre'];
    final modules = allModules.where((m) => _allowedModules.contains(m)).toList();
    final moduleLabels = ['Bitacora', 'Procesamiento', 'Incubadoras', 'Ultracongeladores', 'Equipos', 'Autoclaves', 'Cobre'];
    final auth = context.read<AuthService>();
    final closureService = context.read<ClosureService>();
    final canCloseDay = auth.canClose;
    final isClosed = closureService.isDayClosed(dateStr);
    final isDesktop = MediaQuery.of(context).size.width > 800;
    final dayNum = dateStr.split('-').last;
    final monthNum = dateStr.split('-')[1];
    final yearNum = dateStr.split('-')[0];
    final dateDisplay = '$dayNum/$monthNum/$yearNum';

    Widget buildHeader() {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: OmniTheme.bg800)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isClosed ? OmniTheme.green400.withOpacity(0.15) : OmniTheme.accentBlue.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(isClosed ? Icons.lock : Icons.calendar_today, size: 18, color: isClosed ? OmniTheme.green400 : OmniTheme.accentBlue),
            ),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(dateDisplay, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: OmniTheme.textPrimary)),
              Text('${entries.length} registros', style: const TextStyle(fontSize: 11, color: OmniTheme.textMuted)),
            ]),
            if (isClosed) ...[
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: OmniTheme.green400.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                child: const Text('CERRADO', style: TextStyle(fontSize: 10, color: OmniTheme.green400, fontWeight: FontWeight.bold)),
              ),
            ],
            const Spacer(),
            if (!isClosed)
              PopupMenuButton<String>(
                icon: const Icon(Icons.add_circle_outline, size: 20, color: OmniTheme.accentBlue),
                tooltip: 'Nuevo registro',
                color: OmniTheme.bg800,
                onSelected: (module) {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => FormEntryScreen(module: module, moduleLabel: moduleLabels[modules.indexOf(module)]))).then((_) => _loadStats());
                },
                itemBuilder: (_) => modules.asMap().entries.map((e) => PopupMenuItem(value: e.value, child: Text(moduleLabels[e.key], style: const TextStyle(fontSize: 12, color: OmniTheme.textPrimary)))).toList(),
              ),
            if (canCloseDay && !isClosed) ...[
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.lock, size: 18, color: OmniTheme.green400),
                tooltip: 'Cerrar dia',
                onPressed: () { Navigator.pop(context); _confirmCloseDay(dateStr, auth.currentUser!); },
              ),
            ],
            if (canCloseDay && isClosed) ...[
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.lock_open, size: 18, color: OmniTheme.orange400),
                tooltip: 'Reabrir dia',
                onPressed: () { Navigator.pop(context); _showReopenDialog(dateStr, auth.currentUser!); },
              ),
            ],
            if (isDesktop) IconButton(icon: const Icon(Icons.close, size: 20, color: OmniTheme.textMuted), onPressed: () => Navigator.pop(context)),
          ],
        ),
      );
    }

    Widget buildEntryCard(Map<String, dynamic> entry) {
      Map<String, dynamic> data = {};
      try { data = jsonDecode(entry['data_json'] as String); } catch (_) {}
      final moduleKey = entry['module']?.toString() ?? '';
      final modIdx = modules.indexOf(moduleKey);
      final label = modIdx >= 0 ? moduleLabels[modIdx] : moduleKey.toUpperCase();
      final modColors = [const Color(0xFFF472B6), const Color(0xFFB197FC), OmniTheme.red400, OmniTheme.accentBlue, OmniTheme.green400, OmniTheme.orange400, const Color(0xFF00BCD4)];
      final modColor = modIdx >= 0 ? modColors[modIdx] : OmniTheme.textMuted;
      final modIcons = [Icons.book_outlined, Icons.biotech_outlined, Icons.thermostat_outlined, Icons.ac_unit_outlined, Icons.precision_manufacturing_outlined, Icons.local_fire_department_outlined, Icons.science_outlined];
      final modIcon = modIdx >= 0 ? modIcons[modIdx] : Icons.article_outlined;
      final responsable = data['responsable'] as String? ?? data['usuario'] as String? ?? data['nombre'] as String? ?? '-';
      final createdAt = entry['created_at'] as String? ?? '';
      final timeStr = createdAt.length >= 16 ? createdAt.substring(11, 16) : '';

      return Card(
        margin: const EdgeInsets.only(bottom: 6),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _showEntryDetail(entry, moduleKey, label, dateStr),
          onLongPress: () => _confirmDeleteEntry(entry),
          child: Container(
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: modColor, width: 3)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(modIcon, size: 14, color: modColor),
                    const SizedBox(width: 6),
                    Text(label.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: modColor, letterSpacing: 1)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: entry['status'] == 'synced' ? OmniTheme.green400.withOpacity(0.1) : OmniTheme.orange400.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(entry['status'] == 'synced' ? Icons.cloud_done : Icons.cloud_off, size: 10, color: entry['status'] == 'synced' ? OmniTheme.green400 : OmniTheme.orange400),
                        const SizedBox(width: 3),
                        Text(entry['status'] == 'synced' ? 'Synced' : 'Pend.', style: TextStyle(fontSize: 8, color: entry['status'] == 'synced' ? OmniTheme.green400 : OmniTheme.orange400)),
                      ]),
                    ),
                    if (timeStr.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Text(timeStr, style: const TextStyle(fontSize: 9, color: OmniTheme.textMuted)),
                    ],
                  ]),
                  const SizedBox(height: 6),
                  Row(children: [
                    Icon(Icons.person_outline, size: 12, color: OmniTheme.textMuted),
                    const SizedBox(width: 4),
                    Text(responsable, style: const TextStyle(fontSize: 11, color: OmniTheme.textSecondary)),
                  ]),
                  const SizedBox(height: 4),
                  ...data.entries.take(3).map((e) {
                    if (e.key == 'responsable' || e.key == 'usuario' || e.key == 'nombre') return const SizedBox.shrink();
                    final val = e.value?.toString() ?? '';
                    if (val.isEmpty) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Row(children: [
                        Text('${e.key}: ', style: const TextStyle(fontSize: 11, color: OmniTheme.textMuted)),
                        Expanded(child: Text(val, style: const TextStyle(fontSize: 11, color: OmniTheme.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis)),
                      ]),
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
      );
    }

    Widget buildContent() {
      return entries.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox_outlined, size: 48, color: OmniTheme.bg700),
                  const SizedBox(height: 12),
                  const Text('Sin registros este dia', style: TextStyle(color: OmniTheme.textMuted, fontSize: 13)),
                  const SizedBox(height: 8),
                  if (!isClosed) Text('Selecciona un modulo para crear un registro', style: TextStyle(color: OmniTheme.textMuted.withOpacity(0.7), fontSize: 11)),
                  if (!isClosed) ...[
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8, runSpacing: 8,
                      children: modules.asMap().entries.map((e) {
                        final modColors = [const Color(0xFFF472B6), const Color(0xFFB197FC), OmniTheme.red400, OmniTheme.accentBlue, OmniTheme.green400, OmniTheme.orange400, const Color(0xFF00BCD4)];
                        final modIcons = [Icons.book_outlined, Icons.biotech_outlined, Icons.thermostat_outlined, Icons.ac_unit_outlined, Icons.precision_manufacturing_outlined, Icons.local_fire_department_outlined, Icons.science_outlined];
                        return ActionChip(
                          avatar: Icon(modIcons[e.key % modIcons.length], size: 14, color: modColors[e.key % modColors.length]),
                          label: Text(moduleLabels[e.key], style: const TextStyle(fontSize: 11)),
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.push(context, MaterialPageRoute(builder: (_) => FormEntryScreen(module: e.value, moduleLabel: moduleLabels[e.key]))).then((_) => _loadStats());
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: entries.length,
                    itemBuilder: (ctx, index) => buildEntryCard(entries[index]),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: OmniTheme.bg800)),
                  ),
                  child: Row(children: [
                    Icon(Icons.assignment, size: 14, color: OmniTheme.accentBlue),
                    const SizedBox(width: 6),
                    Text('$entries.length registros', style: const TextStyle(fontSize: 11, color: OmniTheme.textSecondary)),
                    const SizedBox(width: 16),
                    Icon(Icons.category, size: 14, color: OmniTheme.green400),
                    const SizedBox(width: 6),
                    Text('${entries.map((e) => e['module']).toSet().length} modulos', style: const TextStyle(fontSize: 11, color: OmniTheme.textSecondary)),
                    if (!isClosed) ...[
                      const Spacer(),
                      Text('Mantén presionado para eliminar', style: TextStyle(fontSize: 9, color: OmniTheme.textMuted.withOpacity(0.6))),
                    ],
                  ]),
                ),
              ],
            );
    }

    if (isDesktop) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: OmniTheme.bg900,
          contentPadding: EdgeInsets.zero,
          content: SizedBox(
            width: 620,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                buildHeader(),
                SizedBox(
                  height: 440,
                  child: buildContent(),
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
          maxChildSize: 0.85,
          minChildSize: 0.3,
          expand: false,
          builder: (_, scrollController) {
            return Column(
              children: [
                buildHeader(),
                Expanded(child: buildContent()),
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
      ('bitacora', 'Bitacora', Icons.book_outlined, const Color(0xFFF472B6)),
      ('procesamiento', 'Procesamiento', Icons.biotech_outlined, const Color(0xFFB197FC)),
      ('incubadoras', 'Incubadoras', Icons.thermostat_outlined, OmniTheme.red400),
      ('ultracongeladores', 'Ultracongeladores', Icons.ac_unit_outlined, OmniTheme.accentBlue),
      ('equipos', 'Equipos', Icons.precision_manufacturing_outlined, OmniTheme.green400),
      ('autoclaves', 'Autoclaves', Icons.local_fire_department_outlined, OmniTheme.orange400),
      ('solucion_cobre', 'Cobre', Icons.science_outlined, const Color(0xFF00BCD4)),
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
    final aiService = context.read<AiService>();
    final closureService = context.read<ClosureService>();
    final db = await LocalDatabase.instance.database;
    final entries = await db.query('form_entries', where: 'date = ?', whereArgs: [date]);

    final allIssues = <String>[];
    final moduleCount = <String, int>{};
    for (final row in entries) {
      final mod = row['module'] as String? ?? '';
      moduleCount[mod] = (moduleCount[mod] ?? 0) + 1;
      Map<String, dynamic> data = {};
      try { data = jsonDecode(row['data_json'] as String) as Map<String, dynamic>; } catch (_) {}
      final issues = aiService.validateEntryForClosure(data);
      if (issues.isNotEmpty) {
        allIssues.add('$mod: ${issues.join(", ")}');
      }
    }

    final notesCtrl = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: OmniTheme.bg900,
          title: Row(children: [
            const Icon(Icons.summarize, color: OmniTheme.accentBlue, size: 20),
            const SizedBox(width: 8),
            Text('Resumen del dia $date', style: const TextStyle(color: Colors.white, fontSize: 15)),
          ]),
          content: SizedBox(
            width: 380,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${entries.length} registro(s) en total', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 8),
                ...moduleCount.entries.map((e) => Padding(
                  padding: const EdgeInsets.only(left: 8, top: 2),
                  child: Text('${e.key}: ${e.value} entrada(s)', style: const TextStyle(color: OmniTheme.textSecondary, fontSize: 11)),
                )),
                if (allIssues.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text('Observaciones:', style: TextStyle(color: OmniTheme.orange400, fontSize: 12, fontWeight: FontWeight.bold)),
                  ...allIssues.take(5).map((i) => Padding(
                    padding: const EdgeInsets.only(left: 8, top: 2),
                    child: Text('! $i', style: const TextStyle(color: OmniTheme.orange400, fontSize: 10)),
                  )),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Notas (opcional)',
                    labelStyle: TextStyle(color: Colors.white54),
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 8),
                if (allIssues.isNotEmpty)
                  Text('Revise las observaciones antes de cerrar.', style: const TextStyle(color: OmniTheme.orange400, fontSize: 10)),
              ]),
            ),
          ),
          actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: OmniTheme.green400),
              child: const Text('Cerrar dia', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
    if (confirm == true && mounted) {
      try {
        await closureService.closeDay(date, user, notes: notesCtrl.text);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Dia $date cerrado exitosamente'),
            backgroundColor: OmniTheme.green400,
          ));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e'),
            backgroundColor: OmniTheme.red400,
          ));
        }
      }
    }
  }

  Future<void> _confirmCloseMonth(int year, int month, User user) async {
    final key = '$year-${month.toString().padLeft(2, '0')}';

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            width: 500,
            height: MediaQuery.of(context).size.height * 0.85,
            child: ReportCoverPreviewScreen(
              year: year,
              month: month,
              user: user,
              onConfirm: () {
                Navigator.pop(ctx);
                _doCloseMonth(year, month, user, key);
              },
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _doCloseMonth(int year, int month, User user, String key) async {
    final notesCtrl = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: OmniTheme.bg900,
        title: const Text('Confirmar Cierre de Mes', style: TextStyle(color: Colors.white)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Cerrar ${_monthName(month)} $year?', style: const TextStyle(color: Colors.white70, fontSize: 13)),
          Text('Se generara el reporte PDF automaticamente.', style: const TextStyle(color: Colors.white54, fontSize: 11)),
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
            child: const Text('Confirmar cierre de mes', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      try {
        await context.read<ClosureService>().closeMonth(year, month, user, notes: notesCtrl.text);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Mes $key cerrado exitosamente'),
          backgroundColor: OmniTheme.green400,
        ));
        _loadStats();
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
      builder: (ctx) {
        var motivoValido = motivoCtrl.text.trim().isNotEmpty;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: OmniTheme.bg900,
              title: const Text('Reabrir dia', style: TextStyle(color: Colors.white)),
              content: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('Reabrir el dia $date? (maximo 24h desde cierre)', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 12),
                TextField(
                  controller: motivoCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Motivo de reapertura *',
                    labelStyle: TextStyle(color: Colors.white54),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setDialogState(() => motivoValido = motivoCtrl.text.trim().isNotEmpty),
                ),
              ]),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar', style: TextStyle(color: Colors.white54))),
                ElevatedButton(
                  onPressed: motivoValido ? () => Navigator.pop(ctx, true) : null,
                  style: ElevatedButton.styleFrom(backgroundColor: OmniTheme.orange400),
                  child: const Text('Reabrir', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
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

  Future<void> _confirmDeleteEntry(Map<String, dynamic> entry) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: OmniTheme.bg900,
        title: const Text('Eliminar registro', style: TextStyle(color: Colors.white)),
        content: Text('Eliminar registro de ${entry['module']} del dia ${entry['date']}?', style: const TextStyle(color: Colors.white70, fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: OmniTheme.red400),
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      try {
        final db = await LocalDatabase.instance.database;
        await db.delete('form_entries', where: 'id = ?', whereArgs: [entry['id']]);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Registro eliminado'),
          backgroundColor: OmniTheme.green400,
        ));
        _loadStats();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: OmniTheme.red400,
        ));
      }
    }
  }

  void _showEntryDetail(Map<String, dynamic> entry, String moduleKey, String moduleLabel, String dateStr) {
    Map<String, dynamic> data = {};
    try { data = jsonDecode(entry['data_json'] as String); } catch (_) {}
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: OmniTheme.bg900,
        titlePadding: EdgeInsets.zero,
        contentPadding: EdgeInsets.zero,
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: OmniTheme.bg800))),
                child: Row(children: [
                  Expanded(child: Text(moduleLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: OmniTheme.textPrimary))),
                  IconButton(icon: const Icon(Icons.close, size: 20, color: OmniTheme.textMuted), onPressed: () => Navigator.pop(ctx)),
                ]),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 400),
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: data.entries.map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(width: 140, child: Text('${e.key}:', style: const TextStyle(fontSize: 12, color: OmniTheme.textMuted))),
                        Expanded(child: Text(e.value?.toString() ?? '-', style: const TextStyle(fontSize: 12, color: OmniTheme.textPrimary))),
                      ],
                    ),
                  )).toList(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(context, MaterialPageRoute(builder: (_) => FormEntryScreen(module: moduleKey, moduleLabel: moduleLabel))).then((_) => _loadStats());
            },
            child: const Text('Editar', style: TextStyle(color: OmniTheme.accentBlue)),
          ),
        ],
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
