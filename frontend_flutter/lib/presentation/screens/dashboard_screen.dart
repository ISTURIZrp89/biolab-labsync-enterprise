import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../security/auth_service.dart';
import '../../sync/sync_engine.dart';
import '../../data/db.dart';
import '../../theme/omni_theme.dart';
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
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _animController.forward();
    _loadStats();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    try {
      final db = await LocalDatabase.instance.database;
      final today = DateTime.now().toIso8601String().split('T')[0];

      final todayEntries = await db.query('form_entries', where: 'date = ?', whereArgs: [today]);
      final totalEntries = await db.query('form_entries');
      final closures = await db.query('day_closures', where: 'date = ?', whereArgs: [today]);

      final syncEngine = context.read<SyncEngine>();
      final pending = await syncEngine.getPendingCount();

      if (mounted) {
        setState(() {
          _pendingCount = pending;
          _todayEntries = todayEntries.length;
          _totalEntries = totalEntries.length;
          _todayClosureStatus = closures.isNotEmpty ? closures.first['status'] as String : 'ABIERTO';
        });
      }
    } catch (e) {
      debugPrint('Dashboard load error: $e');
    }
  }

  static const _modules = [
    {"module": "incubadoras", "label": "Incubadoras", "icon": Icons.thermostat_outlined, "color": OmniTheme.red400},
    {"module": "autoclaves", "label": "Autoclaves", "icon": Icons.local_fire_department_outlined, "color": OmniTheme.orange400},
    {"module": "ultracongeladores", "label": "Ultracongeladores", "icon": Icons.ac_unit_outlined, "color": OmniTheme.accentBlue},
    {"module": "equipos", "label": "Equipos", "icon": Icons.precision_manufacturing_outlined, "color": OmniTheme.green400},
    {"module": "procesamiento", "label": "Procesamiento", "icon": Icons.biotech_outlined, "color": Color(0xFFB197FC)},
    {"module": "bitacora", "label": "Bitacora", "icon": Icons.book_outlined, "color": Color(0xFFF472B6)},
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
        backgroundColor: OmniTheme.bg950,
        body: Center(child: Text('Error: $e', style: const TextStyle(color: OmniTheme.red400))),
      );
    }

    return Scaffold(
      backgroundColor: OmniTheme.bg950,
      appBar: _buildAppBar(auth, sync),
      body: Stack(
        children: [
          const _BackgroundEffect(),
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatsSection(),
                const SizedBox(height: 24),
                _buildActivitySection(),
                const SizedBox(height: 24),
                _buildModulesGrid(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(AuthService auth, SyncEngine sync) {
    return AppBar(
      title: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [OmniTheme.accentBlue, OmniTheme.accentIndigo]),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(color: OmniTheme.accentBlue.withOpacity(0.2), blurRadius: 12, offset: const Offset(0, 2)),
              ],
            ),
            child: const Icon(Icons.biotech, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [OmniTheme.accentBlue, OmniTheme.accentIndigo],
                ).createShader(bounds),
                child: const Text(
                  'BioLab',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              Text(
                auth.currentUser?.nombre ?? 'Dashboard',
                style: const TextStyle(fontSize: 10, color: OmniTheme.textMuted, letterSpacing: 1),
              ),
            ],
          ),
        ],
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: OmniTheme.bg900,
            border: Border.all(color: OmniTheme.bg800),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: sync.isOnline ? OmniTheme.green400 : OmniTheme.red400,
                  shape: BoxShape.circle,
                  boxShadow: sync.isOnline
                      ? [BoxShadow(color: OmniTheme.green400, blurRadius: 6)]
                      : null,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                sync.isOnline ? 'ONLINE' : 'OFFLINE',
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: OmniTheme.textSecondary),
              ),
              if (_pendingCount > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: OmniTheme.orange400.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$_pendingCount',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: OmniTheme.orange400),
                  ),
                ),
              ],
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
                    content: Text(success ? 'Sincronizacion completada' : 'Sin conexion'),
                    backgroundColor: OmniTheme.bg800,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                );
                _loadStats();
              }
            } catch (_) {}
          },
        ),
        IconButton(
          icon: const Icon(Icons.settings_outlined, size: 20),
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
        ),
        IconButton(
          icon: const Icon(Icons.logout, size: 20),
          onPressed: () {
            try { sync.stopPeriodicSync(); } catch (_) {}
            auth.logout();
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
          },
        ),
      ],
    );
  }

  Widget _buildStatsSection() {
    final now = DateTime.now();
    final today = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [OmniTheme.accentBlue, OmniTheme.accentIndigo],
              ).createShader(bounds),
              child: const Text(
                'Pipeline de Datos v1.0.0',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Row(
              children: [
                Expanded(child: _StatusCard(title: 'Registros Hoy', value: '0', status: 'OK', color: OmniTheme.green400)),
                SizedBox(width: 12),
                Expanded(child: _StatusCard(title: 'Total Registros', value: '0', status: 'OK', color: OmniTheme.green400)),
                SizedBox(width: 12),
                Expanded(child: _StatusCard(title: 'Pendientes Sync', value: '0', status: 'Clear', color: OmniTheme.textMuted)),
                SizedBox(width: 12),
                Expanded(child: _StatusCard(title: 'Cierre del Dia', value: 'ABIERTO', status: 'Active', color: OmniTheme.accentBlue)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivitySection() {
    return Card(
      child: SizedBox(
        height: 200,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: OmniTheme.bg800)),
              ),
              child: const Row(
                children: [
                  Text(
                    'Actividad Reciente',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                      color: OmniTheme.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.inbox_outlined, size: 32, color: OmniTheme.bg700),
                    const SizedBox(height: 8),
                    const Text(
                      'No hay actividad reciente en el pipeline.',
                      style: TextStyle(color: OmniTheme.bg700, fontSize: 12, fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModulesGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.4,
      ),
      itemCount: _modules.length,
      itemBuilder: (context, index) {
        final m = _modules[index];
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: Duration(milliseconds: 400 + (index * 100)),
          curve: Curves.easeOutCubic,
          builder: (_, value, child) {
            return Transform.translate(
              offset: Offset(0, 20 * (1 - value)),
              child: Opacity(opacity: value, child: child),
            );
          },
          child: _ModuleCard(
            label: m['label'] as String,
            icon: m['icon'] as IconData,
            color: m['color'] as Color,
            onTap: () => Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (_, __, ___) => FormEntryScreen(
                  module: m['module'] as String,
                  moduleLabel: m['label'] as String,
                ),
                transitionsBuilder: (_, animation, __, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
                transitionDuration: const Duration(milliseconds: 300),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StatusCard extends StatelessWidget {
  final String title;
  final String value;
  final String status;
  final Color color;

  const _StatusCard({required this.title, required this.value, required this.status, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: OmniTheme.textMuted,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontFamily: 'Outfit',
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: OmniTheme.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              status,
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModuleCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ModuleCard({required this.label, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: OmniTheme.bg900,
            border: Border.all(color: OmniTheme.bg800),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(height: 10),
                Text(
                  label,
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: OmniTheme.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BackgroundEffect extends StatelessWidget {
  const _BackgroundEffect();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _RadialGradientPainter(),
    );
  }
}

class _RadialGradientPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, 0),
      width: size.width,
      height: size.height,
    );
    final gradient = RadialGradient(
      center: Alignment.topCenter,
      radius: 0.8,
      colors: [
        OmniTheme.accentBlue.withOpacity(0.04),
        Colors.transparent,
      ],
    );
    final paint = Paint()..shader = gradient.createShader(rect);
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
