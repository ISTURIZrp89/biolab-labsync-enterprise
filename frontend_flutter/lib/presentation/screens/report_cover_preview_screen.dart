import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../ai/ai_service.dart';
import '../../domain/entities/user.dart';
import '../../services/report_cover_service.dart';
import '../../theme/omni_theme.dart';

class ReportCoverPreviewScreen extends StatefulWidget {
  final int year;
  final int month;
  final User user;
  final VoidCallback onConfirm;

  const ReportCoverPreviewScreen({
    super.key,
    required this.year,
    required this.month,
    required this.user,
    required this.onConfirm,
  });

  @override
  State<ReportCoverPreviewScreen> createState() => _ReportCoverPreviewScreenState();
}

class _ReportCoverPreviewScreenState extends State<ReportCoverPreviewScreen> {
  final _nombreCtrl = TextEditingController();
  final _cargoCtrl = TextEditingController();
  final _areaCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ReportCoverService>().loadForMonth(widget.year, widget.month);
    });
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _cargoCtrl.dispose();
    _areaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<ReportCoverService>();
    return Scaffold(
      backgroundColor: OmniTheme.bg950,
      appBar: AppBar(
        title: const Text('Portada del Reporte Mensual'),
        backgroundColor: OmniTheme.bg900,
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.check_circle, color: OmniTheme.green400),
            label: const Text('Cerrar mes', style: TextStyle(color: OmniTheme.green400)),
            onPressed: svc.loading ? null : widget.onConfirm,
          ),
        ],
      ),
      body: svc.loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _buildPreviewCard(svc),
                const SizedBox(height: 16),
                _buildPersonnelSection(svc),
              ]),
            ),
    );
  }

  Widget _buildPreviewCard(ReportCoverService svc) {
    final monthNames = ['', 'ENERO', 'FEBRERO', 'MARZO', 'ABRIL', 'MAYO', 'JUNIO',
      'JULIO', 'AGOSTO', 'SEPTIEMBRE', 'OCTUBRE', 'NOVIEMBRE', 'DICIEMBRE'];
    final active = svc.personnel;
    return Card(
      color: OmniTheme.bg900,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          Icon(Icons.description, size: 48, color: OmniTheme.accentBlue.withOpacity(0.5)),
          const SizedBox(height: 12),
          Text('BIOLAB LABSYNC', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: OmniTheme.accentBlue)),
          const SizedBox(height: 4),
          Container(width: 60, height: 3, color: OmniTheme.accentBlue),
          const SizedBox(height: 16),
          Text('BITACORA DE ${monthNames[widget.month]} ${widget.year}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: OmniTheme.textPrimary)),
          const SizedBox(height: 20),
          _previewRow('Mes:', '${monthNames[widget.month]} ${widget.year}'),
          _previewRow('Periodo:', '01/${widget.month.toString().padLeft(2, '0')}/${widget.year} - ${DateTime(widget.year, widget.month + 1, 0).day}/${widget.month.toString().padLeft(2, '0')}/${widget.year}'),
          _previewRow('Personal:', '${active.length} persona(s)'),
          _previewRow('Cerrado por:', widget.user.nombre),
          const SizedBox(height: 16),
          if (active.isNotEmpty) ...[
            const Divider(color: OmniTheme.bg800),
            const SizedBox(height: 8),
            Text('Personal Responsable:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: OmniTheme.textSecondary)),
            const SizedBox(height: 4),
            ...active.map((p) => Padding(
              padding: const EdgeInsets.only(left: 8, top: 2),
              child: Text('  - ${p.nombre}${p.cargo.isNotEmpty ? ' (${p.cargo})' : ''}',
                  style: const TextStyle(fontSize: 11, color: OmniTheme.textMuted)),
            )),
          ],
        ]),
      ),
    );
  }

  Widget _previewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        SizedBox(width: 80, child: Text(label, style: const TextStyle(fontSize: 12, color: OmniTheme.textMuted))),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 12, color: OmniTheme.textPrimary))),
      ]),
    );
  }

  Widget _buildPersonnelSection(ReportCoverService svc) {
    return Card(
      color: OmniTheme.bg900,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.people, size: 18, color: OmniTheme.accentBlue),
            const SizedBox(width: 8),
            const Text('Personal del Mes', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: OmniTheme.textPrimary)),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.add_circle, color: OmniTheme.green400, size: 20),
              onPressed: () => _showAddPersonnelDialog(svc),
              tooltip: 'Agregar personal',
            ),
          ]),
          const SizedBox(height: 8),
          if (svc.allPersonnel.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No hay personal registrado. Agregue personal o use los usuarios registrados.',
                  style: TextStyle(color: OmniTheme.textMuted, fontSize: 12)),
            )
          else
            ...svc.allPersonnel.map((p) => _buildPersonnelTile(svc, p)),
        ]),
      ),
    );
  }

  Widget _buildPersonnelTile(ReportCoverService svc, ReportPersonnel p) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: p.activo ? OmniTheme.bg800 : OmniTheme.bg800.withOpacity(0.4),
        borderRadius: BorderRadius.circular(6),
      ),
      child: ListTile(
        dense: true,
        leading: Icon(p.activo ? Icons.person : Icons.person_off, color: p.activo ? OmniTheme.green400 : OmniTheme.textMuted, size: 18),
        title: Text(p.nombre, style: TextStyle(fontSize: 13, color: p.activo ? OmniTheme.textPrimary : OmniTheme.textMuted)),
        subtitle: p.cargo.isNotEmpty
            ? Text('${p.cargo}${p.area.isNotEmpty ? ' - ${p.area}' : ''}',
                style: TextStyle(fontSize: 10, color: p.activo ? OmniTheme.textSecondary : OmniTheme.textMuted))
            : null,
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(
            icon: const Icon(Icons.edit, size: 14, color: OmniTheme.accentBlue),
            onPressed: () => _showEditPersonnelDialog(svc, p),
          ),
          IconButton(
            icon: Icon(p.activo ? Icons.visibility_off : Icons.visibility, size: 14,
                color: p.activo ? OmniTheme.orange400 : OmniTheme.green400),
            onPressed: () => svc.updatePersonnel(p.id, activo: !p.activo),
            tooltip: p.activo ? 'Desactivar' : 'Activar',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 14, color: OmniTheme.red400),
            onPressed: () => svc.removePersonnel(p.id),
          ),
        ]),
      ),
    );
  }

  void _showAddPersonnelDialog(ReportCoverService svc) {
    _nombreCtrl.clear();
    _cargoCtrl.clear();
    _areaCtrl.clear();
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: OmniTheme.bg900,
          title: const Text('Agregar Personal', style: TextStyle(color: Colors.white)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: _nombreCtrl, style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Nombre', labelStyle: TextStyle(color: Colors.white54), border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(controller: _cargoCtrl, style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Cargo / Puesto', labelStyle: TextStyle(color: Colors.white54), border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(controller: _areaCtrl, style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Area (opcional)', labelStyle: TextStyle(color: Colors.white54), border: OutlineInputBorder())),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.auto_fix_high, size: 14, color: OmniTheme.accentBlue),
                label: const Text('Sugerir cargo (IA)', style: TextStyle(fontSize: 11, color: OmniTheme.accentBlue)),
                onPressed: () async {
                  final nombre = _nombreCtrl.text.trim();
                  if (nombre.isEmpty) return;
                  final area = _areaCtrl.text.trim();
                  final ai = ctx.read<AiService>();
                  final prompt = 'Sugiere un cargo/puesto de laboratorio para $nombre'
                      '${area.isNotEmpty ? ' en el area de $area' : ''}. Responde solo el nombre del cargo.';
                  final result = await ai.getSuggestions('cargo_operativo', prompt);
                  if (result.isNotEmpty && _cargoCtrl.text.isEmpty) {
                    setDialogState(() => _cargoCtrl.text = result.first);
                  }
                },
                style: OutlinedButton.styleFrom(side: const BorderSide(color: OmniTheme.accentBlue)),
              ),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: Colors.white54))),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                svc.addPersonnel(_nombreCtrl.text.trim(), _cargoCtrl.text.trim(), _areaCtrl.text.trim());
              },
              style: ElevatedButton.styleFrom(backgroundColor: OmniTheme.green400),
              child: const Text('Agregar', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditPersonnelDialog(ReportCoverService svc, ReportPersonnel p) {
    _nombreCtrl.text = p.nombre;
    _cargoCtrl.text = p.cargo;
    _areaCtrl.text = p.area;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: OmniTheme.bg900,
        title: const Text('Editar Personal', style: TextStyle(color: Colors.white)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: _nombreCtrl, style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(labelText: 'Nombre', labelStyle: TextStyle(color: Colors.white54), border: OutlineInputBorder())),
          const SizedBox(height: 8),
          TextField(controller: _cargoCtrl, style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(labelText: 'Cargo / Puesto', labelStyle: TextStyle(color: Colors.white54), border: OutlineInputBorder())),
          const SizedBox(height: 8),
          TextField(controller: _areaCtrl, style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(labelText: 'Area (opcional)', labelStyle: TextStyle(color: Colors.white54), border: OutlineInputBorder())),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              svc.updatePersonnel(p.id,
                nombre: _nombreCtrl.text.trim(), cargo: _cargoCtrl.text.trim(), area: _areaCtrl.text.trim());
            },
            style: ElevatedButton.styleFrom(backgroundColor: OmniTheme.accentBlue),
            child: const Text('Guardar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}