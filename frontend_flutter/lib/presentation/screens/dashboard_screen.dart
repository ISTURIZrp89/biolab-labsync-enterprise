import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../security/auth_service.dart';
import '../../sync/sync_engine.dart';
import '../../data/db.dart';
import 'form_entry_screen.dart';
import 'calendar_screen.dart';
import 'login_screen.dart';
import 'audit_screen.dart';
import 'settings_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with SingleTickerProviderStateMixin {
  int _pendingCount = 0;
  int _todayEntries = 0;
  int _totalEntries = 0;
  String _todayClosureStatus = 'ABIERTO';
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _animationController.forward();
    _loadStats();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    try {
      final db = await LocalDatabase.instance.database;
      final today = DateTime.now().toIso8601String().split('T')[0];

      final todayEntries = await db.query(
        'form_entries',
        where: 'date = ?',
        whereArgs: [today],
      );

      final totalEntries = await db.query('form_entries');

      final closures = await db.query(
        'day_closures',
        where: 'date = ?',
        whereArgs: [today],
      );

      final syncEngine = context.read<SyncEngine>();
      final pending = await syncEngine.getPendingCount();

      if (mounted) {
        setState(() {
          _pendingCount = pending;
          _todayEntries = todayEntries.length;
          _totalEntries = totalEntries.length;
          _todayClosureStatus = closures.isNotEmpty
              ? closures.first['status'] as String
              : 'ABIERTO';
        });
      }
    } catch (e) {
      debugPrint('Dashboard load error (offline mode): $e');
      if (mounted) {
        setState(() {
          _pendingCount = 0;
          _todayEntries = 0;
          _totalEntries = 0;
          _todayClosureStatus = 'ABIERTO';
        });
      }
    }
  }

  static const _modules = [
    {"module": "incubadoras", "label": "Incubadoras", "icon": Icons.thermostat, "color": Color(0xFFFF6B6B)},
    {"module": "autoclaves", "label": "Autoclaves", "icon": Icons.local_fire_department, "color": Color(0xFFFFA94D)},
    {"module": "ultracongeladores", "label": "Ultracongeladores", "icon": Icons.ac_unit, "color": Color(0xFF4DABF7)},
    {"module": "equipos", "label": "Equipos", "icon": Icons.precision_manufacturing, "color": Color(0xFF69DB7C)},
    {"module": "procesamiento", "label": "Procesamiento", "icon": Icons.biotech, "color": Color(0xFFB197FC)},
    {"module": "bitacora", "label": "Bitacora General", "icon": Icons.book, "color": Color(0xFFE91E63)},
  ];

  @override
  Widget build(BuildContext context) {
    final AuthService auth;
    final SyncEngine sync;
    try {
      auth = context.watch<AuthService>();
      sync = context.watch<SyncEngine>();
    } catch (e) {
      return Scaffold(
        backgroundColor: const Color(0xFF020617),
        body: Center(
          child: Text('Error: $e', style: const TextStyle(color: Colors.red)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Color(0xFF3B82F6), Color(0xFF6366F1)],
              ).createShader(bounds),
              child: const Text(
                'BioLab',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ),
            Text(
              auth.currentUser?.nombre ?? 'Dashboard',
              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
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
                if (_pendingCount > 0)
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFEF4444)]),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$_pendingCount',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.sync, size: 20),
            onPressed: () async {
              try {
                final success = await sync.synchronize();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(success ? 'Sincronizacion completada' : 'Sin conexion. Datos guardados localmente'),
                      backgroundColor: success ? const Color(0xFF1E293B) : const Color(0xFF1E293B),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  );
                  _loadStats();
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Modo offline activo'),
                    backgroundColor: const Color(0xFF1E293B),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  );
                }
              }
            },
            tooltip: 'Sincronizar',
          ),
          IconButton(
            icon: const Icon(Icons.settings, size: 20),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout, size: 20),
            onPressed: () {
              try {
                sync.stopPeriodicSync();
              } catch (_) {}
              auth.logout();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            },
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
        child: RefreshIndicator(
          onRefresh: _loadStats,
          color: const Color(0xFF3B82F6),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatsCard(),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildActionButton(
                          icon: Icons.calendar_month,
                          label: 'Calendario',
                          onTap: () => Navigator.push(
                            context,
                            PageRouteBuilder(
                              pageBuilder: (context, animation, secondaryAnimation) => const CalendarScreen(),
                              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                return FadeTransition(opacity: animation, child: child);
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildActionButton(
                          icon: Icons.history,
                          label: 'Auditoria',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const AuditScreen()),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Container(
                        width: 3,
                        height: 16,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF6366F1)]),
                          borderRadius: BorderRadius.all(Radius.circular(2)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Modulos de Bitacora',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.25,
                      ),
                      itemCount: _modules.length,
                      itemBuilder: (context, index) {
                        final m = _modules[index];
                        final delay = index * 0.08;
                        final animation = Tween<double>(begin: 0.0, end: 1.0).animate(
                          CurvedAnimation(
                            parent: _animationController,
                            curve: Interval(delay, (delay + 0.3).clamp(0.0, 1.0), curve: Curves.easeOutCubic),
                          ),
                        );
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(
                              CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
                            ),
                            child: _buildModuleCard(m),
                          ),
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({required IconData icon, required String label, required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: const Color(0xFF3B82F6)),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModuleCard(Map<String, dynamic> m) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => FormEntryScreen(
                module: m['module'] as String,
                moduleLabel: m['label'] as String,
              ),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return FadeTransition(opacity: animation, child: child);
              },
              transitionDuration: const Duration(milliseconds: 300),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF0F172A),
                (m['color'] as Color).withOpacity(0.08),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: (m['color'] as Color).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(m['icon'] as IconData, size: 24, color: m['color'] as Color),
                ),
                const SizedBox(height: 12),
                Text(
                  m['label'] as String,
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsCard() {
    final now = DateTime.now();
    final today = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3B82F6).withOpacity(0.05),
            blurRadius: 20,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                today,
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getClosureStatusColor(_todayClosureStatus).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _getClosureStatusColor(_todayClosureStatus).withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _getClosureStatusColor(_todayClosureStatus),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _todayClosureStatus,
                      style: TextStyle(
                        color: _getClosureStatusColor(_todayClosureStatus),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _statItem('Registros Hoy', '$_todayEntries', Icons.today_outlined)),
              const SizedBox(width: 12),
              Expanded(child: _statItem('Total', '$_totalEntries', Icons.folder_outlined)),
              const SizedBox(width: 12),
              Expanded(child: _statItem('Pendientes', '$_pendingCount', Icons.sync_outlined)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFF3B82F6), size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10, fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Color _getClosureStatusColor(String status) {
    switch (status) {
      case 'CERRADO':
        return const Color(0xFF22C55E);
      case 'CERRADO_CON_OBSERVACION':
      case 'CERRADO_OBSERVACION':
        return const Color(0xFF3B82F6);
      case 'COMPLETO':
        return const Color(0xFF22C55E);
      case 'PENDIENTE':
        return const Color(0xFFF59E0B);
      case 'REABIERTO':
        return const Color(0xFFF97316);
      default:
        return Colors.grey;
    }
  }
}
