import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../data/db.dart';
import '../../data/repositories/form_repository_impl.dart';
import '../../domain/form_definitions.dart';
import '../../domain/entities/form_entry.dart';
import '../widgets/smart_form_field.dart';
import '../../security/auth_service.dart';
import '../../services/user_service.dart';
import '../../sync/sync_engine.dart';
import '../../theme/omni_theme.dart';

class FormEntryScreen extends StatefulWidget {
  final String module;
  final String moduleLabel;

  const FormEntryScreen({super.key, required this.module, required this.moduleLabel});

  @override
  State<FormEntryScreen> createState() => _FormEntryScreenState();
}

class _FormEntryScreenState extends State<FormEntryScreen> with SingleTickerProviderStateMixin {
  FormModuleDef? _moduleDef;
  int _activeSectionIndex = 0;
  List<FormEntry> _entries = [];
  bool _loading = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _moduleDef = findModule(widget.module);
    if (_moduleDef != null && (_moduleDef!['sections'] as List).length > 1) {
      _tabController = TabController(length: (_moduleDef!['sections'] as List).length, vsync: this);
    }
    _loadEntries();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _loadEntries() async {
    setState(() => _loading = true);
    try {
      final repo = context.read<FormRepositoryImpl>();
      final entries = await repo.getEntriesByModule(widget.module);
      if (mounted) setState(() { _entries = entries; _loading = false; });
    } catch (e) {
      debugPrint('Load entries error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  FormSectionDef? _getCurrentSection() {
    if (_moduleDef == null) return null;
    final sections = _moduleDef!['sections'] as List;
    if (sections.isEmpty) return null;
    return sections[_activeSectionIndex] as FormSectionDef;
  }

  void _openForm() {
    final section = _getCurrentSection();
    if (section == null) return;
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => _DailyLogForm(
        module: widget.module,
        moduleLabel: widget.moduleLabel,
        section: section,
        onSave: _loadEntries,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final sections = _moduleDef?['sections'] as List? ?? [];
    final hasTabs = sections.length > 1;

    return Scaffold(
      backgroundColor: OmniTheme.bg950,
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back, size: 20), onPressed: () => Navigator.pop(context)),
        title: Row(children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [OmniTheme.accentBlue, OmniTheme.accentIndigo]),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.edit_note, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 10),
          Text(widget.moduleLabel, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ]),
        backgroundColor: OmniTheme.bg900,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.add, size: 20), tooltip: 'Nuevo registro', onPressed: _openForm, color: OmniTheme.accentBlue),
        ],
        bottom: hasTabs
            ? TabBar(
                controller: _tabController,
                onTap: (i) => setState(() => _activeSectionIndex = i),
                tabs: sections.map<Widget>((s) => Tab(text: (s['label'] as String).toUpperCase())).toList(),
              )
            : null,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _entries.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inbox_outlined, size: 48, color: OmniTheme.bg700),
                      const SizedBox(height: 12),
                      const Text('Sin registros', style: TextStyle(color: OmniTheme.textMuted, fontSize: 12)),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Nuevo registro'),
                        onPressed: _openForm,
                        style: ElevatedButton.styleFrom(backgroundColor: OmniTheme.accentBlue, foregroundColor: Colors.white),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _entries.length,
                  itemBuilder: (ctx, i) => _buildEntryCard(_entries[i]),
                ),
    );
  }

  Widget _buildEntryCard(FormEntry entry) {
    final data = entry.data;
    final fecha = data['fecha'] as String? ?? entry.date;
    final responsable = data['responsable'] as String? ?? data['usuario'] as String? ?? '-';
    final horaInicio = data['hora_inicio'] as String? ?? '';
    final horaFin = data['hora_fin'] as String? ?? '';
    final actividades = data['_actividades'] as List? ?? [];
    final recursos = data['_recursos'] as List? ?? [];
    final incidencias = data['incidencias'] as String? ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => _DailyLogForm(
              module: widget.module,
              moduleLabel: widget.moduleLabel,
              section: _getCurrentSection()!,
              existingEntry: entry,
              onSave: _loadEntries,
            ),
          ));
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 4, height: 20,
                  decoration: BoxDecoration(
                    color: entry.status == 'synced' ? OmniTheme.green400 : OmniTheme.orange400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(fecha, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: OmniTheme.textPrimary))),
                if (horaInicio.isNotEmpty)
                  Text('$horaInicio${horaFin.isNotEmpty ? ' - $horaFin' : ''}', style: const TextStyle(fontSize: 10, color: OmniTheme.textMuted)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: entry.status == 'synced' ? OmniTheme.green400.withOpacity(0.15) : OmniTheme.orange400.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(entry.status.toUpperCase(), style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: entry.status == 'synced' ? OmniTheme.green400 : OmniTheme.orange400)),
                ),
              ]),
              const SizedBox(height: 8),
              Text(responsable, style: const TextStyle(fontSize: 11, color: OmniTheme.textSecondary)),
              if (actividades.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text('${actividades.length} actividades', style: const TextStyle(fontSize: 10, color: OmniTheme.accentBlue)),
              ],
              if (incidencias.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.warning_amber, size: 12, color: OmniTheme.orange400),
                  const SizedBox(width: 4),
                  Expanded(child: Text(incidencias, style: const TextStyle(fontSize: 10, color: OmniTheme.orange400), maxLines: 1, overflow: TextOverflow.ellipsis)),
                ]),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DailyLogForm extends StatefulWidget {
  final String module;
  final String moduleLabel;
  final FormSectionDef section;
  final FormEntry? existingEntry;
  final VoidCallback onSave;

  const _DailyLogForm({
    required this.module,
    required this.moduleLabel,
    required this.section,
    this.existingEntry,
    required this.onSave,
  });

  @override
  State<_DailyLogForm> createState() => _DailyLogFormState();
}

class _DailyLogFormState extends State<_DailyLogForm> {
  final Map<String, dynamic> _formData = {};
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, FocusNode> _focusNodes = {};
  bool _isSaving = false;
  bool _saveSuccess = false;
  String? _saveError;
  List<Map<String, dynamic>> _activities = [];
  List<Map<String, dynamic>> _resources = [];
  List<Map<String, dynamic>> _cajas = [];
  final Map<String, List<String>> _historyCache = {};
  final ScrollController _fieldsScroll = ScrollController();
  final ScrollController _activitiesScrollH = ScrollController();
  final ScrollController _resourcesScrollH = ScrollController();
  final ScrollController _cajasScrollH = ScrollController();

  List<Map<String, dynamic>> get _generalFields => ((widget.section['general_fields'] as List?) ?? []).cast<Map<String, dynamic>>();
  Map<String, dynamic>? get _activitiesTable => widget.section['activities_table'] as Map<String, dynamic>?;
  Map<String, dynamic>? get _cajasTable => widget.section['cajas_table'] as Map<String, dynamic>?;
  Map<String, dynamic>? get _resourcesTable => widget.section['resources_table'] as Map<String, dynamic>?;
  List<Map<String, dynamic>> get _extraFields => ((widget.section['fields'] as List?) ?? []).cast<Map<String, dynamic>>();

  @override
  void initState() {
    super.initState();
    _initForm();
  }

  @override
  void dispose() {
    _fieldsScroll.dispose();
    _activitiesScrollH.dispose();
    _resourcesScrollH.dispose();
    _cajasScrollH.dispose();
    for (final c in _controllers.values) { c.dispose(); }
    for (final f in _focusNodes.values) { f.dispose(); }
    super.dispose();
  }

  void _initForm() {
    final now = DateTime.now();
    final today = now.toIso8601String().split('T')[0];
    final nowTime = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final autofill = context.read<UserService>().getAutofill();
    final historyKeys = <String>{};

    for (final f in _generalFields) {
      final key = f['key'] as String;
      final type = f['type'] as String;
      final existing = widget.existingEntry?.data[key];
      if (existing != null && existing.toString().isNotEmpty) {
        _formData[key] = existing;
      } else if (type == 'date') {
        _formData[key] = today;
      } else if (type == 'time') {
        _formData[key] = nowTime;
      } else if (type == 'autofill' && autofill.containsKey(key)) {
        _formData[key] = autofill[key] ?? '';
      } else {
        _formData[key] = '';
      }
      _controllers[key] = TextEditingController(text: _formData[key]?.toString() ?? '');
      _focusNodes[key] = FocusNode();
    }

    if (widget.existingEntry != null) {
      final acts = widget.existingEntry!.data['_actividades'] as List? ?? [];
      _activities = acts.map((a) => Map<String, dynamic>.from(a as Map)).toList();
      final res = widget.existingEntry!.data['_recursos'] as List? ?? [];
      _resources = res.map((r) => Map<String, dynamic>.from(r as Map)).toList();
      final cajas = widget.existingEntry!.data['_cajas'] as List? ?? [];
      _cajas = cajas.map((c) => Map<String, dynamic>.from(c as Map)).toList();
    }

    if (_activities.isEmpty && _activitiesTable != null) {
      _activities = [{}];
    }
    if (_cajas.isEmpty && _cajasTable != null) {
      _cajas = [{}];
    }
    if (_resources.isEmpty && _resourcesTable != null) {
      _resources = [{}];
    }

    if (_activitiesTable != null) {
      for (final col in (_activitiesTable!['columns'] as List?) ?? []) {
        if (col['history'] == true) historyKeys.add(col['key'] as String);
      }
    }
    if (_cajasTable != null) {
      for (final col in (_cajasTable!['columns'] as List?) ?? []) {
        if (col['history'] == true) historyKeys.add(col['key'] as String);
      }
    }
    if (_resourcesTable != null) {
      for (final col in (_resourcesTable!['columns'] as List?) ?? []) {
        if (col['history'] == true) historyKeys.add(col['key'] as String);
      }
    }
    for (final key in historyKeys) {
      _loadHistory(key);
    }
  }

  Future<void> _loadHistory(String fieldKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('field_history_$fieldKey');
      if (raw != null) {
        final list = (jsonDecode(raw) as List).cast<String>();
        if (mounted) setState(() => _historyCache[fieldKey] = list);
      }
    } catch (_) {}
  }

  Future<void> _saveHistory(String fieldKey, String value) async {
    if (value.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('field_history_$fieldKey');
      final list = raw != null ? (jsonDecode(raw) as List).cast<String>() : <String>[];
      list.remove(value);
      list.insert(0, value);
      if (list.length > 20) list.removeLast();
      await prefs.setString('field_history_$fieldKey', jsonEncode(list));
    } catch (_) {}
  }

  Future<void> _save() async {
    if (_isSaving) return;
    setState(() { _isSaving = true; _saveError = null; _saveSuccess = false; });

    try {
      final auth = context.read<AuthService>();
      final prefs = await SharedPreferences.getInstance();
      final deviceId = prefs.getString('device_id') ?? '';
      final repo = context.read<FormRepositoryImpl>();

      for (final f in _generalFields) {
        final key = f['key'] as String;
        final c = _controllers[key];
        if (c != null) _formData[key] = c.text;
      }
      _formData['_actividades'] = _activities.where((a) => a.values.any((v) => v.toString().isNotEmpty)).toList();
      _formData['_cajas'] = _cajas.where((c) => c.values.any((v) => v.toString().isNotEmpty)).toList();
      _formData['_recursos'] = _resources.where((r) => r.values.any((v) => v.toString().isNotEmpty)).toList();

      for (final f in _generalFields) {
        final key = f['key'] as String;
        final val = _controllers[key]?.text ?? '';
        if (val.isNotEmpty && f['type'] == 'autofill') _saveHistory(key, val);
      }

      final version = (widget.existingEntry?.version ?? 0) + 1;
      final now = DateTime.now().toUtc().toIso8601String();

      if (widget.existingEntry != null) {
        final db = await LocalDatabase.instance.database;
        final existing = widget.existingEntry!;
        final oldData = existing.data;
        await db.update(
          'form_entries',
          {
            'data_json': jsonEncode(_formData),
            'version': version,
            'updated_at': now,
          },
          where: 'id = ?',
          whereArgs: [existing.id],
        );
        await db.insert('audit_log', {
          'id': const Uuid().v4(),
          'action': 'UPDATE',
          'user_id': auth.currentUser?.id ?? 'offline',
          'device_id': deviceId,
          'timestamp': now,
          'details_json': jsonEncode({'entry_id': existing.id, 'old_data': oldData}),
        });
      } else {
        await repo.createEntry(
          module: widget.module,
          subModule: widget.section['key'] as String?,
          date: _formData['fecha']?.toString() ?? DateTime.now().toIso8601String().split('T')[0],
          userId: auth.currentUser?.id ?? 'offline',
          deviceId: deviceId,
          data: _formData,
        );
      }

      if (mounted) {
        setState(() => _saveSuccess = true);
        await Future.delayed(const Duration(milliseconds: 600));
        widget.onSave();
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) setState(() { _saveError = e.toString(); _isSaving = false; });
    }
  }

  void _showPreview() {
    for (final f in _generalFields) {
      final key = f['key'] as String;
      final c = _controllers[key];
      if (c != null) _formData[key] = c.text;
    }
    _formData['_actividades'] = _activities.where((a) => a.values.any((v) => v.toString().isNotEmpty)).toList();
    _formData['_cajas'] = _cajas.where((c) => c.values.any((v) => v.toString().isNotEmpty)).toList();
    _formData['_recursos'] = _resources.where((r) => r.values.any((v) => v.toString().isNotEmpty)).toList();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: OmniTheme.bg900,
        title: Row(children: [
          const Icon(Icons.preview, size: 20, color: OmniTheme.accentBlue),
          const SizedBox(width: 8),
          Expanded(child: Text('Vista previa - ${widget.moduleLabel}', style: const TextStyle(fontSize: 14, color: OmniTheme.textPrimary))),
        ]),
        content: SizedBox(
          width: 600,
          child: ListView(
            shrinkWrap: true,
            children: [
              ..._generalFields.map((f) {
                final key = f['key'] as String;
                final label = f['label'] as String? ?? key;
                final val = _formData[key]?.toString() ?? '';
                if (val.isEmpty) return const SizedBox.shrink();
                return Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 130, child: Text('$label:', style: const TextStyle(fontSize: 11, color: OmniTheme.textMuted))),
                    Expanded(child: Text(val, style: const TextStyle(fontSize: 11, color: OmniTheme.textPrimary))),
                  ],
                ));
              }),
              if (_activities.isNotEmpty && _activities[0].isNotEmpty) ...[
                const Divider(color: OmniTheme.bg800),
                Text('${_activitiesTable?['label'] ?? 'Actividades'}: ${_activities.length}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: OmniTheme.accentBlue)),
                ..._activities.map((a) => Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(a.entries.map((e) => '${e.key}: ${e.value}').join(' | '), style: const TextStyle(fontSize: 10, color: OmniTheme.textSecondary)),
                )),
              ],
              if (_cajas.isNotEmpty && _cajas[0].isNotEmpty) ...[
                const Divider(color: OmniTheme.bg800),
                Text('${_cajasTable?['label'] ?? 'Cajas Procesadas'}: ${_cajas.length}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: OmniTheme.accentBlue)),
                ..._cajas.map((c) => Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(c.entries.map((e) => '${e.key}: ${e.value}').join(' | '), style: const TextStyle(fontSize: 10, color: OmniTheme.textSecondary)),
                )),
              ],
              if (_resources.isNotEmpty && _resources[0].isNotEmpty) ...[
                const Divider(color: OmniTheme.bg800),
                Text('${_resourcesTable?['label'] ?? 'Recursos'}: ${_resources.length}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: OmniTheme.green400)),
                ..._resources.map((r) => Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(r.entries.map((e) => '${e.key}: ${e.value}').join(' | '), style: const TextStyle(fontSize: 10, color: OmniTheme.textSecondary)),
                )),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Editar', style: TextStyle(color: OmniTheme.textMuted))),
          ElevatedButton(onPressed: () { Navigator.pop(ctx); _save(); }, style: ElevatedButton.styleFrom(backgroundColor: OmniTheme.green400, foregroundColor: Colors.white), child: const Text('GUARDAR')),
        ],
      ),
    );
  }

  void _addRow(List<Map<String, dynamic>> list, List<Map<String, dynamic>>? columns) {
    setState(() {
      final row = <String, dynamic>{};
      if (columns != null) {
        for (final col in columns) {
          final key = col['key'] as String;
          final initial = col['initial'] as String? ?? '';
          row[key] = initial;
        }
      }
      list.add(row);
    });
  }

  void _duplicateRow(List<Map<String, dynamic>> list, int index) {
    if (index >= list.length) return;
    setState(() => list.insert(index + 1, Map<String, dynamic>.from(list[index])));
  }

  void _removeRow(List<Map<String, dynamic>> list, int index) {
    if (list.length <= 1) return;
    setState(() => list.removeAt(index));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OmniTheme.bg950,
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back, size: 20), onPressed: () => Navigator.pop(context)),
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.moduleLabel, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          Text(widget.section['label'] as String? ?? '', style: const TextStyle(fontSize: 10, color: OmniTheme.textMuted)),
        ]),
        backgroundColor: OmniTheme.bg900,
        elevation: 0,
        actions: [
          if (_saveSuccess)
            const Icon(Icons.check_circle, color: OmniTheme.green400, size: 20)
          else
            IconButton(icon: const Icon(Icons.visibility, size: 20), tooltip: 'Vista previa', onPressed: _showPreview, color: OmniTheme.textMuted),
          if (_saveSuccess)
            const Padding(padding: EdgeInsets.only(right: 16), child: Text('Guardado', style: TextStyle(fontSize: 11, color: OmniTheme.green400))),
        ],
      ),
      body: CallbackShortcuts(
        bindings: {
          SingleActivator(LogicalKeyboardKey.keyS, control: true): _showPreview,
        },
        child: Focus(
          autofocus: true,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  controller: _fieldsScroll,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_generalFields.isNotEmpty) ...[
                        _buildSectionHeader('Informacion General'),
                        const SizedBox(height: 8),
                        ...List.generate(_generalFields.length, (i) => _buildAutofillField(i)),
                      ],
                      if (_activitiesTable != null) ...[
                        const SizedBox(height: 20),
                        _buildTableSection(
                          _activitiesTable!['label'] as String? ?? 'Actividades',
                          ((_activitiesTable!['columns'] as List?) ?? []).cast<Map<String, dynamic>>(),
                          _activities,
                          _activitiesScrollH,
                        ),
                      ],
                      if (_cajasTable != null) ...[
                        const SizedBox(height: 20),
                        _buildTableSection(
                          _cajasTable!['label'] as String? ?? 'Cajas Procesadas',
                          ((_cajasTable!['columns'] as List?) ?? []).cast<Map<String, dynamic>>(),
                          _cajas,
                          _cajasScrollH,
                        ),
                      ],
                      if (_resourcesTable != null) ...[
                        const SizedBox(height: 20),
                        _buildTableSection(
                          _resourcesTable!['label'] as String? ?? 'Recursos',
                          ((_resourcesTable!['columns'] as List?) ?? []).cast<Map<String, dynamic>>(),
                          _resources,
                          _resourcesScrollH,
                        ),
                      ],
                      if (_extraFields.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        _buildSectionHeader('Observaciones e Incidencias'),
                        const SizedBox(height: 8),
                        ...List.generate(_extraFields.length, (i) => _buildExtraField(i)),
                      ],
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(children: [
      Container(width: 3, height: 16, decoration: BoxDecoration(color: OmniTheme.accentBlue, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 8),
      Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: OmniTheme.textPrimary, letterSpacing: 1)),
    ]);
  }

  Widget _buildAutofillField(int index) {
    final f = _generalFields[index];
    final key = f['key'] as String;
    final label = f['label'] as String? ?? key;
    final type = f['type'] as String;
    final required = f['required'] as bool? ?? false;
    final controller = _controllers[key]!;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 140, child: Text('$label${required ? ' *' : ''}', style: const TextStyle(fontSize: 11, color: OmniTheme.textMuted))),
          const SizedBox(width: 8),
          Expanded(
            child: type == 'date'
                ? InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                        builder: (ctx, child) => Theme(data: Theme.of(context).copyWith(
                          colorScheme: const ColorScheme.dark(primary: OmniTheme.accentBlue, onPrimary: Colors.white, surface: OmniTheme.bg900, onSurface: OmniTheme.textPrimary),
                        ), child: child!),
                      );
                      if (picked != null) {
                        controller.text = picked.toIso8601String().split('T')[0];
                        _formData[key] = controller.text;
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(border: Border.all(color: OmniTheme.bg700), borderRadius: BorderRadius.circular(6)),
                      child: Row(children: [
                        Expanded(child: Text(controller.text.isNotEmpty ? controller.text : 'Seleccionar', style: TextStyle(fontSize: 13, color: controller.text.isNotEmpty ? OmniTheme.textPrimary : OmniTheme.textMuted))),
                        const Icon(Icons.calendar_today, size: 14, color: OmniTheme.textMuted),
                      ]),
                    ),
                  )
                : type == 'time'
                    ? InkWell(
                        onTap: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.now(),
                            builder: (ctx, child) => Theme(data: Theme.of(context).copyWith(
                              colorScheme: const ColorScheme.dark(primary: OmniTheme.accentBlue, onPrimary: Colors.white, surface: OmniTheme.bg900, onSurface: OmniTheme.textPrimary),
                            ), child: child!),
                          );
                          if (picked != null) {
                            controller.text = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                            _formData[key] = controller.text;
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(border: Border.all(color: OmniTheme.bg700), borderRadius: BorderRadius.circular(6)),
                          child: Row(children: [
                            Expanded(child: Text(controller.text.isNotEmpty ? controller.text : 'Seleccionar', style: TextStyle(fontSize: 13, color: controller.text.isNotEmpty ? OmniTheme.textPrimary : OmniTheme.textMuted))),
                            const Icon(Icons.access_time, size: 14, color: OmniTheme.textMuted),
                          ]),
                        ),
                      )
                    : type == 'select'
                        ? DropdownButtonFormField<String>(
                            value: controller.text.isEmpty ? null : controller.text,
                            items: (f['options'] as List?)?.map((o) => DropdownMenuItem(value: o.toString(), child: Text(o.toString(), style: const TextStyle(fontSize: 13, color: OmniTheme.textPrimary)))).toList(),
                            onChanged: (v) { controller.text = v ?? ''; _formData[key] = v; },
                            dropdownColor: OmniTheme.bg800,
                            style: const TextStyle(fontSize: 13, color: OmniTheme.textPrimary),
                            decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                          )
                        : TextFormField(
                            controller: controller,
                            focusNode: _focusNodes[key],
                            style: const TextStyle(fontSize: 13, color: OmniTheme.textPrimary),
                            decoration: InputDecoration(
                              border: OutlineInputBorder(borderSide: BorderSide(color: OmniTheme.bg700)),
                              enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: OmniTheme.bg700)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              isDense: true,
                            ),
                            onChanged: (v) { _formData[key] = v; },
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableSection(String label, List<Map<String, dynamic>> columns, List<Map<String, dynamic>> rows, ScrollController scrollH) {
    if (columns.isEmpty) return const SizedBox.shrink();

    double totalWidth = 70;
    for (final col in columns) { totalWidth += (col['width'] as num?)?.toDouble() ?? 120; }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          _buildSectionHeader(label),
          const Spacer(),
          Text('${rows.length}', style: const TextStyle(fontSize: 10, color: OmniTheme.accentBlue, fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          _tableAction(Icons.add, () => _addRow(rows, columns)),
          const SizedBox(width: 4),
          _tableAction(Icons.content_paste, _pasteFromClipboard),
        ]),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(border: Border.all(color: OmniTheme.bg800), borderRadius: BorderRadius.circular(8)),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              controller: scrollH,
              child: SizedBox(
                width: totalWidth,
                child: Column(
                  children: [
                    _buildTableHeader(columns),
                    ...List.generate(rows.length, (i) => _buildTableRow(rows, columns, i)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _tableAction(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(border: Border.all(color: OmniTheme.bg700), borderRadius: BorderRadius.circular(4)),
        child: Icon(icon, size: 14, color: OmniTheme.accentBlue),
      ),
    );
  }

  Widget _buildTableHeader(List<Map<String, dynamic>> columns) {
    return Container(
      height: 32,
      color: OmniTheme.bg800,
      child: Row(
        children: [
          ...columns.map((col) => SizedBox(
            width: (col['width'] as num?)?.toDouble() ?? 120,
            child: Center(child: Text((col['label'] as String? ?? '').toUpperCase(), style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: OmniTheme.textMuted))),
          )),
          const SizedBox(width: 60, child: Center(child: Text('ACCIÓN', style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: OmniTheme.textMuted)))),
        ],
      ),
    );
  }

  Widget _buildTableRow(List<Map<String, dynamic>> rows, List<Map<String, dynamic>> columns, int rowIdx) {
    return Container(
      height: 36,
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: OmniTheme.bg800, width: 0.5))),
      child: Row(
        children: [
          ...columns.map((col) {
            final key = col['key'] as String;
            final type = col['type'] as String? ?? 'text';
            final options = col['options'] as List?;
            final width = (col['width'] as num?)?.toDouble() ?? 120;
            final cellValue = rows[rowIdx][key]?.toString() ?? '';
            final history = col['history'] == true ? _historyCache[key] : null;

            Widget cell;
            if (type == 'select' && options != null) {
              cell = DropdownButtonFormField<String>(
                value: options.contains(cellValue) ? cellValue : null,
                items: options.map((o) => DropdownMenuItem(value: o.toString(), child: Text(o.toString(), style: const TextStyle(fontSize: 11, color: Colors.white)))).toList(),
                onChanged: (v) { setState(() { rows[rowIdx][key] = v ?? ''; }); },
                dropdownColor: OmniTheme.bg800,
                style: const TextStyle(fontSize: 11, color: Colors.white),
                decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 4)),
              );
            } else {
              cell = TextFormField(
                initialValue: cellValue,
                style: const TextStyle(fontSize: 11, color: OmniTheme.textPrimary),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  suffixIcon: history != null && history.isNotEmpty
                      ? PopupMenuButton<String>(
                          icon: const Icon(Icons.history, size: 12, color: OmniTheme.textMuted),
                          color: OmniTheme.bg800,
                          onSelected: (v) { setState(() { rows[rowIdx][key] = v; }); },
                          itemBuilder: (_) => history.take(10).map((h) => PopupMenuItem(value: h, child: Text(h, style: const TextStyle(fontSize: 10, color: OmniTheme.textPrimary)))).toList(),
                        )
                      : null,
                ),
                onChanged: (v) { rows[rowIdx][key] = v; },
              );
            }
            return SizedBox(width: width, child: cell);
          }),
          SizedBox(
            width: 60,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              InkWell(onTap: () => _duplicateRow(rows, rowIdx), child: const Padding(padding: EdgeInsets.all(4), child: Icon(Icons.copy, size: 12, color: OmniTheme.accentBlue))),
              InkWell(onTap: () => _removeRow(rows, rowIdx), child: const Padding(padding: EdgeInsets.all(4), child: Icon(Icons.close, size: 12, color: OmniTheme.red400))),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildExtraField(int index) {
    final f = _extraFields[index];
    final key = f['key'] as String;
    final label = f['label'] as String? ?? key;
    final multiline = f['multiline'] as bool? ?? false;
    final controller = _controllers[key] ?? TextEditingController(text: _formData[key]?.toString() ?? '');
    if (!_controllers.containsKey(key)) _controllers[key] = controller;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: OmniTheme.textMuted)),
          const SizedBox(height: 4),
          TextFormField(
            controller: controller,
            maxLines: multiline ? 3 : 1,
            style: const TextStyle(fontSize: 13, color: OmniTheme.textPrimary),
            decoration: InputDecoration(
              border: OutlineInputBorder(borderSide: BorderSide(color: OmniTheme.bg700)),
              enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: OmniTheme.bg700)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              isDense: true,
            ),
            onChanged: (v) { _formData[key] = v; },
          ),
        ],
      ),
    );
  }

  Future<void> _pasteFromClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (data?.text == null || data!.text!.trim().isEmpty) return;
      final lines = data.text!.split(RegExp(r'[\r\n]+')).map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
      if (lines.isEmpty) return;

      final columns = (_activitiesTable?['columns'] as List?) ?? [];
      setState(() {
        for (final line in lines) {
          final values = line.split('\t');
          final row = <String, dynamic>{};
          for (int c = 0; c < columns.length; c++) {
            row[columns[c]['key'] as String] = c < values.length ? values[c].trim() : '';
          }
          _activities.add(row);
        }
      });
    } catch (_) {}
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: OmniTheme.bg800))),
      child: Row(children: [
        Expanded(child: _saveError != null
            ? Text('$_saveError', style: const TextStyle(fontSize: 11, color: OmniTheme.red400))
            : _saveSuccess
                ? const Text('Guardado correctamente', style: TextStyle(fontSize: 11, color: OmniTheme.green400))
                : const SizedBox.shrink()),
        TextButton(onPressed: _isSaving ? null : () => Navigator.pop(context), child: const Text('Cancelar', style: TextStyle(color: OmniTheme.textMuted))),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: _isSaving || _saveSuccess ? null : _showPreview,
          icon: _isSaving
              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.save, size: 16),
          label: Text(widget.existingEntry != null ? 'ACTUALIZAR' : 'GUARDAR'),
          style: ElevatedButton.styleFrom(backgroundColor: OmniTheme.accentBlue, foregroundColor: Colors.white),
        ),
      ]),
    );
  }
}
