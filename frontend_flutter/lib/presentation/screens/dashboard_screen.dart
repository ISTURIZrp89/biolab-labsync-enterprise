import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../security/auth_service.dart';
import '../../sync/sync_engine.dart';
import '../../data/db.dart';
import 'form_list_screen.dart';
import 'calendar_screen.dart';
import 'login_screen.dart';
import 'audit_screen.dart';
import 'settings_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _pendingCount = 0;
  int _todayEntries = 0;
  int _totalEntries = 0;
  String _todayClosureStatus = 'ABIERTO';
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadStats();
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
  ];

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final sync = context.watch<SyncEngine>();

    return Scaffold(
      backgroundColor: const Color(0xFF001020),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('BioLab'),
            Text(
              auth.currentUser?.nombre ?? 'Dashboard',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF004A99),
        foregroundColor: Colors.white,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  sync.isOnline ? Icons.wifi : Icons.wifi_off,
                  color: sync.isOnline ? Colors.greenAccent : Colors.redAccent,
                  size: 20,
                ),
                if (_pendingCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$_pendingCount',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: () async {
              try {
                final success = await sync.synchronize();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(success
                        ? 'Sincronizacion completada'
                        : 'Sin conexion. Datos guardados localmente')),
                  );
                  _loadStats();
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Modo offline activo')),
                  );
                }
              }
            },
            tooltip: 'Sincronizar',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
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
            colors: [Color(0xFF001020), Color(0xFF000810)],
          ),
        ),
        child: RefreshIndicator(
          onRefresh: _loadStats,
          color: const Color(0xFF004A99),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatsCard(),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const CalendarScreen()),
                      ),
                      icon: const Icon(Icons.calendar_month),
                      label: const Text('Calendario Operativo'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0066CC),
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(56),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const AuditScreen()),
                          ),
                          icon: const Icon(Icons.history),
                          label: const Text('Auditoria'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF001830),
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Modulo en desarrollo')),
                            );
                          },
                          icon: const Icon(Icons.picture_as_pdf),
                          label: const Text('Reportes'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF001830),
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Modulos de Bitacora',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.2,
                  ),
                  itemCount: _modules.length,
                  itemBuilder: (context, index) {
                    final m = _modules[index];
                    return Card(
                      color: const Color(0xFF001830),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => FormListScreen(
                                module: m['module'] as String,
                                moduleLabel: m['label'] as String,
                              ),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(m['icon'] as IconData, size: 40, color: m['color'] as Color),
                              const SizedBox(height: 12),
                              Text(
                                m['label'] as String,
                                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
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

  Widget _buildStatsCard() {
    final today = DateFormat('dd/MM/yyyy', 'es').format(DateTime.now());

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF001830),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                today,
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _getClosureStatusColor(_todayClosureStatus),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _todayClosureStatus,
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _statItem('Registros Hoy', '$_todayEntries', Icons.today),
              ),
              Expanded(
                child: _statItem('Total Registros', '$_totalEntries', Icons.folder),
              ),
              Expanded(
                child: _statItem('Pendientes Sync', '$_pendingCount', Icons.sync),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFF004A99), size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Color _getClosureStatusColor(String status) {
    switch (status) {
      case 'CERRADO':
        return Colors.green;
      case 'CERRADO_CON_OBSERVACION':
      case 'CERRADO_OBSERVACION':
        return Colors.blue;
      case 'COMPLETO':
        return Colors.green.shade700;
      case 'PENDIENTE':
        return Colors.orange;
      case 'REABIERTO':
        return Colors.orange.shade300;
      default:
        return Colors.grey;
    }
  }
}
