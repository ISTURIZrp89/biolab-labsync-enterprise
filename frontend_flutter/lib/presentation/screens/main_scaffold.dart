import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../security/auth_service.dart';
import '../../sync/sync_engine.dart';
import '../../theme/omni_theme.dart';
import 'form_entry_screen.dart';
import 'calendar_screen.dart';
import 'settings_screen.dart';
import 'login_screen.dart';

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _selectedIndex = 0;
  int _pendingCount = 0;

  static const _navItems = [
    _NavItem('Inicio', Icons.dashboard_outlined, Icons.dashboard),
    _NavItem('Incubadoras', Icons.thermostat_outlined, Icons.thermostat),
    _NavItem('Autoclaves', Icons.local_fire_department_outlined, Icons.local_fire_department),
    _NavItem('Ultracongeladores', Icons.ac_unit_outlined, Icons.ac_unit),
    _NavItem('Equipos', Icons.precision_manufacturing_outlined, Icons.precision_manufacturing),
    _NavItem('Procesamiento', Icons.biotech_outlined, Icons.biotech),
    _NavItem('Bitacora', Icons.book_outlined, Icons.book),
    _NavItem('Calendario', Icons.calendar_month_outlined, Icons.calendar_month),
  ];

  static const _moduleKeys = ['', 'incubadoras', 'autoclaves', 'ultracongeladores', 'equipos', 'procesamiento', 'bitacora', ''];

  @override
  void initState() {
    super.initState();
    _loadPending();
  }

  Future<void> _loadPending() async {
    try {
      final sync = context.read<SyncEngine>();
      final pending = await sync.getPendingCount();
      if (mounted) setState(() => _pendingCount = pending);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 800;

    Widget content;
    if (_selectedIndex == 0) {
      content = _buildDashboard();
    } else {
      content = const CalendarScreen();
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
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FormEntryScreen(module: module, moduleLabel: label),
      ),
    );
  }

  Widget _buildNavRail(bool extended) {
    final auth = context.watch<AuthService>();
    final sync = context.watch<SyncEngine>();

    return NavigationRail(
      selectedIndex: _selectedIndex.clamp(0, _navItems.length - 1),
      onDestinationSelected: (i) {
        if (i == 0 || i == _navItems.length - 1) {
          setState(() => _selectedIndex = i);
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
              child: const Icon(Icons.biotech, color: Colors.white, size: 20),
            ),
            const SizedBox(height: 4),
            Text(auth.currentUser?.nombre ?? '', style: const TextStyle(fontSize: 8, color: OmniTheme.textMuted), overflow: TextOverflow.ellipsis),
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
      destinations: _navItems.map((item) {
        final isSelected = _navItems[_selectedIndex] == item;
        return NavigationRailDestination(
          icon: Icon(item.icon, size: 18, color: OmniTheme.textMuted),
          selectedIcon: Icon(item.selectedIcon, size: 18, color: OmniTheme.accentBlue),
          label: Text(item.label, style: TextStyle(fontSize: 10, color: isSelected ? OmniTheme.accentBlue : OmniTheme.textMuted)),
        );
      }).toList(),
    );
  }

  Widget _buildSyncDot(SyncEngine sync) {
    return GestureDetector(
      onTap: () async {
        try {
          await sync.synchronize();
          _loadPending();
        } catch (_) {}
      },
      child: Container(
        width: 28, height: 28,
        decoration: BoxDecoration(
          color: OmniTheme.bg800,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Container(
            width: 8, height: 8,
            decoration: BoxDecoration(
              color: sync.isOnline ? OmniTheme.green400 : OmniTheme.red400,
              shape: BoxShape.circle,
              boxShadow: sync.isOnline
                  ? [BoxShadow(color: OmniTheme.green400.withOpacity(0.4), blurRadius: 6)]
                  : null,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDashboard() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Panel Principal', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: OmniTheme.textPrimary)),
          const SizedBox(height: 8),
          Text('Selecciona un modulo en la barra lateral', style: TextStyle(fontSize: 12, color: OmniTheme.textMuted)),
          const SizedBox(height: 24),
          _buildQuickGrid(),
        ],
      ),
    );
  }

  Widget _buildQuickGrid() {
    final quickItems = _navItems.sublist(1, _navItems.length - 1);
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: quickItems.map((item) {
        final idx = _navItems.indexOf(item);
        final moduleKey = _moduleKeys[idx];
        return _QuickCard(
          label: item.label,
          icon: item.icon,
          onTap: () => _openModule(moduleKey, item.label),
        );
      }).toList(),
    );
  }
}

class _NavItem {
  final String label;
  final IconData icon;
  final IconData selectedIcon;

  const _NavItem(this.label, this.icon, this.selectedIcon);
}

class _QuickCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _QuickCard({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Icon(icon, size: 32, color: OmniTheme.accentBlue),
                const SizedBox(height: 8),
                Text(label, style: const TextStyle(fontSize: 13, color: OmniTheme.textPrimary), textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
