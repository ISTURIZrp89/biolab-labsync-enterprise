import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/vps_service.dart';
import '../../services/audit_service.dart';
import '../../services/license_service.dart';
import '../../security/auth_service.dart';
import '../../theme/omni_theme.dart';
import '../../sync/lan_discovery_service.dart';

class RemoteAccessScreen extends StatefulWidget {
  const RemoteAccessScreen({super.key});

  @override
  State<RemoteAccessScreen> createState() => _RemoteAccessScreenState();
}

class _RemoteAccessScreenState extends State<RemoteAccessScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final _vpsUrlCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _vpsUrlCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vps = context.watch<VpsService>();
    final audit = context.watch<AuditService>();
    final discovery = context.watch<LanDiscoveryService>();

    return Scaffold(
      backgroundColor: OmniTheme.bg950,
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back, size: 20), onPressed: () => Navigator.pop(context)),
        title: const Text('Acceso Remoto y Auditoria', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        backgroundColor: OmniTheme.bg900, elevation: 0,
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: OmniTheme.accentBlue,
          labelColor: OmniTheme.accentBlue,
          unselectedLabelColor: OmniTheme.textMuted,
          labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: 'VPS Remoto'),
            Tab(text: 'Auditoria'),
            Tab(text: 'Red LAN'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _buildVpsTab(vps),
          _buildAuditTab(audit),
          _buildLanTab(discovery),
        ],
      ),
    );
  }

  Widget _buildVpsTab(VpsService vps) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: OmniTheme.bg900, borderRadius: BorderRadius.circular(10)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Conexion VPS', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: OmniTheme.textPrimary)),
            const SizedBox(height: 4),
            Text('Configura una VPS para conectar dispositivos fuera de la red WiFi', style: TextStyle(fontSize: 10, color: OmniTheme.textMuted)),
            const SizedBox(height: 12),
            Row(children: [
              Container(
                width: 8, height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: vps.connected ? OmniTheme.green400 : (vps.state == VpsConnectionState.error ? OmniTheme.red400 : OmniTheme.orange400),
                ),
              ),
              const SizedBox(width: 6),
              Text(_vpsStateLabel(vps), style: TextStyle(fontSize: 11, color: vps.connected ? OmniTheme.green400 : OmniTheme.textMuted)),
            ]),
            if (vps.lastError != null) ...[
              const SizedBox(height: 6),
              Text(vps.lastError!, style: TextStyle(fontSize: 10, color: OmniTheme.red400)),
            ],
            if (vps.authorized) ...[
              const SizedBox(height: 6),
              Row(children: [
                Icon(Icons.check_circle, size: 12, color: OmniTheme.green400),
                const SizedBox(width: 4),
                Text('Autorizado - Peer: ${vps.remotePeerId ?? "N/A"}', style: TextStyle(fontSize: 10, color: OmniTheme.green400)),
              ]),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _vpsUrlCtrl,
              style: const TextStyle(color: OmniTheme.textPrimary, fontSize: 12),
              decoration: InputDecoration(
                hintText: 'wss://tu-vps.com/ws',
                hintStyle: TextStyle(color: OmniTheme.textMuted.withOpacity(0.5), fontSize: 12),
                filled: true, fillColor: OmniTheme.bg800,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                label: const Text('URL de VPS', style: TextStyle(fontSize: 11, color: OmniTheme.textMuted)),
              ),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: Icon(vps.connected ? Icons.link_off : Icons.link, size: 14),
                  label: Text(vps.connected ? 'Desconectar' : 'Conectar', style: const TextStyle(fontSize: 11)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: vps.connected ? OmniTheme.red400 : OmniTheme.accentBlue,
                    side: BorderSide(color: (vps.connected ? OmniTheme.red400 : OmniTheme.accentBlue).withOpacity(0.4)),
                  ),
                  onPressed: () {
                    if (vps.connected) {
                      vps.disconnect();
                    } else {
                      vps.connect(url: _vpsUrlCtrl.text.trim());
                    }
                  },
                ),
              ),
            ]),
          ]),
        ),
        if (vps.messages.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: OmniTheme.bg900, borderRadius: BorderRadius.circular(10)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Mensajes (${vps.messages.length})', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: OmniTheme.textPrimary)),
              const SizedBox(height: 8),
              ...vps.messages.take(20).map((m) => Container(
                padding: const EdgeInsets.all(6),
                margin: const EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(color: OmniTheme.bg800, borderRadius: BorderRadius.circular(4)),
                child: Text(m.toString(), style: const TextStyle(fontSize: 9, color: OmniTheme.textMuted)),
              )),
            ]),
          ),
        ],
      ]),
    );
  }

  String _vpsStateLabel(VpsService vps) {
    switch (vps.state) {
      case VpsConnectionState.disconnected: return 'Desconectado';
      case VpsConnectionState.connecting: return 'Conectando...';
      case VpsConnectionState.connected: return 'Conectado';
      case VpsConnectionState.error: return 'Error de conexion';
    }
  }

  Widget _buildAuditTab(AuditService audit) {
    return Column(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(children: [
          Text('${audit.entries.length} eventos registrados', style: const TextStyle(fontSize: 11, color: OmniTheme.textMuted)),
          const Spacer(),
          if (audit.entries.isNotEmpty)
            TextButton.icon(
              icon: const Icon(Icons.delete_sweep, size: 14),
              label: const Text('Limpiar', style: TextStyle(fontSize: 10)),
              style: TextButton.styleFrom(foregroundColor: OmniTheme.red400, padding: const EdgeInsets.symmetric(horizontal: 8)),
              onPressed: () async {
                final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
                  backgroundColor: OmniTheme.bg900,
                  title: const Text('Limpiar auditoria', style: TextStyle(fontSize: 14, color: OmniTheme.textPrimary)),
                  content: const Text('¿Eliminar todos los registros de auditoria?', style: TextStyle(fontSize: 12, color: OmniTheme.textMuted)),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar', style: TextStyle(fontSize: 11))),
                    TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Limpiar', style: TextStyle(fontSize: 11, color: OmniTheme.red400))),
                  ],
                ));
                if (ok == true) await audit.clearAll();
              },
            ),
        ]),
      ),
      Expanded(
        child: audit.entries.isEmpty
            ? Center(child: Text('No hay eventos registrados', style: TextStyle(fontSize: 12, color: OmniTheme.textMuted)))
            : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: audit.entries.length,
                itemBuilder: (ctx, i) {
                  final e = audit.entries[i];
                  final icon = _auditIcon(e.type);
                  return Container(
                    padding: const EdgeInsets.all(8),
                    margin: const EdgeInsets.only(bottom: 4),
                    decoration: BoxDecoration(color: OmniTheme.bg900, borderRadius: BorderRadius.circular(6)),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Icon(icon, size: 14, color: OmniTheme.accentBlue),
                      const SizedBox(width: 8),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(e.action, style: const TextStyle(fontSize: 11, color: OmniTheme.textPrimary, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 2),
                        Text('${e.userName} (${e.userId})', style: TextStyle(fontSize: 9, color: OmniTheme.textMuted)),
                        if (e.details != null && e.details!.isNotEmpty)
                          Text(e.details!, style: TextStyle(fontSize: 9, color: OmniTheme.textMuted.withOpacity(0.7))),
                        if (e.deviceId != null || e.ipAddress != null)
                          Text('${e.deviceId ?? ""} ${e.ipAddress ?? ""}', style: TextStyle(fontSize: 8, color: OmniTheme.textMuted.withOpacity(0.5))),
                      ])),
                      Text(_formatTime(e.timestamp), style: TextStyle(fontSize: 8, color: OmniTheme.textMuted)),
                    ]),
                  );
                },
              ),
      ),
    ]);
  }

  IconData _auditIcon(String type) {
    switch (type) {
      case 'login': return Icons.login;
      case 'logout': return Icons.logout;
      case 'create': return Icons.add_circle;
      case 'update': return Icons.edit;
      case 'delete': return Icons.delete;
      case 'sync': return Icons.sync;
      case 'remote': return Icons.public;
      case 'admin': return Icons.admin_panel_settings;
      case 'license': return Icons.vpn_key;
      default: return Icons.info;
    }
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'ahora';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  Widget _buildLanTab(LanDiscoveryService discovery) {
    return Column(children: [
      Container(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          Icon(discovery.isRunning ? Icons.wifi : Icons.wifi_off, size: 16, color: discovery.isRunning ? OmniTheme.green400 : OmniTheme.red400),
          const SizedBox(width: 8),
          Text('${discovery.peers.length} dispositivos en red', style: const TextStyle(fontSize: 11, color: OmniTheme.textMuted)),
        ]),
      ),
      Expanded(
        child: discovery.peers.isEmpty
            ? Center(child: Text('Buscando dispositivos...', style: TextStyle(fontSize: 12, color: OmniTheme.textMuted)))
            : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: discovery.peers.length,
                itemBuilder: (ctx, i) {
                  final peer = discovery.peers[i];
                  return Container(
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 4),
                    decoration: BoxDecoration(color: OmniTheme.bg900, borderRadius: BorderRadius.circular(6)),
                    child: Row(children: [
                      Container(width: 6, height: 6, decoration: const BoxDecoration(color: OmniTheme.accentBlue, shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(peer.hostname, style: const TextStyle(fontSize: 11, color: OmniTheme.textPrimary))),
                      Text(peer.ip, style: TextStyle(fontSize: 9, color: OmniTheme.textMuted)),
                    ]),
                  );
                },
              ),
      ),
    ]);
  }
}
