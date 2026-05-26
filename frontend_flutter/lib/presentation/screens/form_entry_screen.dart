import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../data/db.dart';
import '../../data/repositories/form_repository_impl.dart';
import '../../domain/form_definitions.dart';
import '../../domain/entities/form_entry.dart';
import '../widgets/smart_form_field.dart';
import '../../security/auth_service.dart';
import '../../security/edit_lock_service.dart';
import '../../ai/ai_service.dart';
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
    String? lockHolder;
    try {
      final lockSvc = context.read<EditLockService>();
      lockHolder = lockSvc.getLockHolder(entry.id);
    } catch (_) { lockHolder = null; }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {
          try {
            final lockSvc = context.read<EditLockService>();
            final auth = context.read<AuthService>();
            if (lockSvc.isLocked(entry.id) && !lockSvc.canEdit(entry.id, auth.currentUser?.id ?? '')) {
              final holder = lockSvc.getLockHolder(entry.id);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('Editado por: ${holder ?? "otro usuario"}'),
                backgroundColor: OmniTheme.orange400,
              ));
              return;
            }
          } catch (_) {}
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
                if (lockHolder != null) ...[
                  const SizedBox(width: 4),
                  Icon(Icons.lock_outline, size: 12, color: OmniTheme.orange400),
                ],
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
  String? _lockToken;
  EditLockService? _lockService;
  AiService? _aiService;
  Timer? _autosaveTimer;
  DateTime _lastAutosave = DateTime.now();
  bool _dirty = false;
  List<Map<String, dynamic>> _activities = [];
  List<Map<String, dynamic>> _resources = [];
  List<Map<String, dynamic>> _cajas = [];
  final Map<String, List<String>> _historyCache = {};
  Map<String, List<String>> _customOptions = {};
  final Map<String, List<String>> _equipmentOptionsByCategory = {};
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
    _loadDraft();
    _loadEquipmentOptions();
    _loadCustomOptions();
    try {
      _lockService = context.read<EditLockService>();
      if (widget.existingEntry != null) {
        final auth = context.read<AuthService>();
        _lockService!.acquireLock(widget.existingEntry!.id, auth.currentUser?.id ?? '', auth.currentUser?.nombre ?? '', widget.module).then((token) {
          if (mounted) setState(() => _lockToken = token);
        });
      }
      _aiService = context.read<AiService>();
    } catch (_) {}
    _autosaveTimer = Timer.periodic(const Duration(seconds: 30), (_) => _autosave());
  }

  @override
  void dispose() {
    if (_dirty) _autosave();
    _autosaveTimer?.cancel();
    if (_lockToken != null && widget.existingEntry != null && _lockService != null) {
      _lockService!.releaseLock(widget.existingEntry!.id, _lockToken!);
    }
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
      if (widget.module == 'bitacora' && widget.existingEntry == null) {
        _resources = [
          {'reactivo': 'Medio de Cultivo DMEM', 'lote': '', 'caducidad': '', 'cantidad': '', 'observaciones': ''},
          {'reactivo': 'Suero Fetal Bovino (SFB)', 'lote': '', 'caducidad': '', 'cantidad': '', 'observaciones': ''},
          {'reactivo': 'Tripsina-EDTA', 'lote': '', 'caducidad': '', 'cantidad': '', 'observaciones': ''},
          {'reactivo': 'PBS 1X', 'lote': '', 'caducidad': '', 'cantidad': '', 'observaciones': ''},
          {'reactivo': 'Agua Grado Reactivo', 'lote': '', 'caducidad': '', 'cantidad': '', 'observaciones': ''},
        ];
      } else {
        _resources = [{}];
      }
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

  Future<void> _loadEquipmentOptions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('equipment_list');
      if (raw != null) {
        final list = jsonDecode(raw) as List;
        final byCategory = <String, List<String>>{};
        for (final e in list) {
          final map = Map<String, dynamic>.from(e as Map);
          final cat = map['category'] as String? ?? '';
          final name = map['name'] as String? ?? '';
          if (name.isNotEmpty) {
            byCategory.putIfAbsent(cat, () => []).add(name);
          }
        }
        if (mounted) setState(() => _equipmentOptionsByCategory..addAll(byCategory));
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

      if (_aiService != null) {
        for (final f in _generalFields) {
          final key = f['key'] as String;
          final val = _controllers[key]?.text ?? '';
          if (val.isNotEmpty) {
            if (f['type'] == 'autofill') _saveHistory(key, val);
            _aiService!.recordValue(key, val);
          }
        }
        _aiService!.recordContextualSuggestion(widget.module, widget.section['key'] as String? ?? '', _formData);
      }

      final version = (widget.existingEntry?.version ?? 0) + 1;
      final now = DateTime.now().toUtc().toIso8601String();

      if (widget.existingEntry != null) {
        final existing = widget.existingEntry!;
        final updated = FormEntry(
          id: existing.id,
          module: existing.module,
          subModule: existing.subModule,
          date: existing.date,
          userId: existing.userId,
          deviceId: deviceId,
          version: version,
          data: Map<String, dynamic>.from(_formData),
          status: existing.status,
          createdAt: existing.createdAt,
          updatedAt: now,
        );
        await repo.saveEntry(updated);
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
        try {
          final prefs = await SharedPreferences.getInstance();
          if (prefs.getBool('auto_backup') == true) {
            final backupPath = prefs.getString('backup_path') ?? '';
            if (backupPath.isNotEmpty) {
              final ts = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
              final dir = Directory(backupPath);
              if (!await dir.exists()) await dir.create(recursive: true);
              final file = File('${dir.path}/LABSYNC_AutoBackup_$ts.json');
              final backup = {
                'module': widget.module,
                'section': widget.section['key'],
                'date': _formData['fecha'],
                'data': _formData,
                'saved_at': DateTime.now().toUtc().toIso8601String(),
              };
              await file.writeAsString(const JsonEncoder.withIndent('  ').convert(backup));
            }
          }
        } catch (_) {}
      }

      if (mounted) {
        setState(() => _saveSuccess = true);
        await Future.delayed(const Duration(milliseconds: 600));
        widget.onSave();
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() { _saveError = e.toString(); _isSaving = false; });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error al guardar: $e'),
          backgroundColor: OmniTheme.red400,
          duration: const Duration(seconds: 4),
        ));
      }
    }
  }

  Future<void> _autosave() async {
    if (!_dirty || widget.existingEntry != null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final auth = context.read<AuthService>();
      final data = _collectFormData();
      await prefs.setString('draft_${widget.module}', jsonEncode({
        'module': widget.module,
        'section_key': widget.section['key'] as String? ?? '',
        'date': data['fecha'] ?? DateTime.now().toIso8601String().split('T')[0],
        'data': data,
        'user_id': auth.currentUser?.id ?? 'offline',
        'saved_at': DateTime.now().toUtc().toIso8601String(),
      }));
      _lastAutosave = DateTime.now();
      _dirty = false;
    } catch (_) {}
  }

  Future<void> _loadDraft() async {
    if (widget.existingEntry != null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('draft_${widget.module}');
      if (raw == null) return;
      final draft = jsonDecode(raw) as Map<String, dynamic>;
      final draftDate = draft['date'] as String? ?? '';
      final formDate = _controllers['fecha']?.text ?? '';
      if (draftDate != formDate) return;
      final data = draft['data'] as Map<String, dynamic>? ?? {};
      for (final f in _generalFields) {
        final key = f['key'] as String;
        if (data.containsKey(key) && data[key].toString().isNotEmpty) {
          _formData[key] = data[key];
          _controllers[key]?.text = data[key].toString();
        }
      }
      if (data['_actividades'] is List) {
        _activities = (data['_actividades'] as List).map((a) => Map<String, dynamic>.from(a as Map)).toList();
      }
      if (data['_cajas'] is List) {
        _cajas = (data['_cajas'] as List).map((c) => Map<String, dynamic>.from(c as Map)).toList();
      }
      if (data['_recursos'] is List) {
        _resources = (data['_recursos'] as List).map((r) => Map<String, dynamic>.from(r as Map)).toList();
      }
      if (mounted) setState(() {});
      prefs.remove('draft_${widget.module}');
    } catch (_) {}
  }

  Map<String, dynamic> _collectFormData() {
    for (final f in _generalFields) {
      final key = f['key'] as String;
      final c = _controllers[key];
      if (c != null) _formData[key] = c.text;
    }
    _formData['_actividades'] = _activities.where((a) => a.values.any((v) => v.toString().isNotEmpty)).toList();
    _formData['_cajas'] = _cajas.where((c) => c.values.any((v) => v.toString().isNotEmpty)).toList();
    _formData['_recursos'] = _resources.where((r) => r.values.any((v) => v.toString().isNotEmpty)).toList();
    return Map<String, dynamic>.from(_formData);
  }

  void _markDirty() {
    _dirty = true;
  }

  Future<void> _copyFromPreviousDay() async {
    try {
      final repo = context.read<FormRepositoryImpl>();
      final allEntries = await repo.getEntriesByModule(widget.module);
      if (allEntries.isEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No hay entradas anteriores para copiar'), backgroundColor: OmniTheme.orange400));
        return;
      }
      final lastEntry = allEntries.last;
      final sourceData = lastEntry.data;
      int fechaIdx = -1;
      for (int i = 0; i < _generalFields.length; i++) {
        if (_generalFields[i]['type'] == 'date') { fechaIdx = i; break; }
      }
      final fechaField = fechaIdx >= 0 ? _generalFields[fechaIdx] : null;
      if (fechaField != null) {
        final key = fechaField['key'] as String;
        final today = DateTime.now().toIso8601String().split('T')[0];
        _formData[key] = today;
        _controllers[key]?.text = today;
      }
      for (final f in _generalFields) {
        final key = f['key'] as String;
        final type = f['type'] as String;
        if (type == 'date' || type == 'time') continue;
        if (sourceData.containsKey(key) && sourceData[key].toString().isNotEmpty) {
          _formData[key] = sourceData[key];
          if (_controllers.containsKey(key)) {
            _controllers[key]!.text = sourceData[key].toString();
          }
        }
      }
      if (sourceData['_actividades'] is List) {
        _activities = (sourceData['_actividades'] as List).map((a) => Map<String, dynamic>.from(a as Map)).toList();
      }
      if (sourceData['_cajas'] is List) {
        _cajas = (sourceData['_cajas'] as List).map((c) => Map<String, dynamic>.from(c as Map)).toList();
      }
      if (sourceData['_recursos'] is List) {
        _resources = (sourceData['_recursos'] as List).map((r) => Map<String, dynamic>.from(r as Map)).toList();
      }
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Datos copiados de entrada anterior'), backgroundColor: OmniTheme.green400));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al copiar: $e'), backgroundColor: OmniTheme.red400));
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
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: OmniTheme.accentBlue.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
            child: const Icon(Icons.preview, size: 18, color: OmniTheme.accentBlue),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text('Vista previa - ${widget.moduleLabel}', style: const TextStyle(fontSize: 14, color: OmniTheme.textPrimary, fontWeight: FontWeight.bold))),
        ]),
        content: SizedBox(
          width: 640,
          child: ListView(
            shrinkWrap: true,
            children: [
              _buildPreviewSection('Información General', OmniTheme.accentBlue, () {
                return _generalFields.where((f) {
                  final val = _formData[f['key'] as String]?.toString() ?? '';
                  return val.isNotEmpty;
                }).map((f) {
                  final key = f['key'] as String;
                  final label = f['label'] as String? ?? key;
                  final val = _formData[key]?.toString() ?? '';
                  return Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(width: 150, child: Text('$label:', style: const TextStyle(fontSize: 11, color: OmniTheme.textMuted))),
                      Expanded(child: Text(val, style: const TextStyle(fontSize: 11, color: OmniTheme.textPrimary, fontWeight: FontWeight.w500))),
                    ],
                  ));
                }).toList();
              }),
              if (_activities.any((a) => a.values.any((v) => v.toString().isNotEmpty))) ...[
                const SizedBox(height: 12),
                _buildPreviewSection('${_activitiesTable?['label'] ?? 'Actividades'} (${_activities.length})', OmniTheme.green400, () {
                  return _activities.map((a) {
                    final items = a.entries.where((e) => e.value.toString().isNotEmpty).map((e) => '${e.key}: ${e.value}').join(' | ');
                    if (items.isEmpty) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: OmniTheme.bg800.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(items, style: const TextStyle(fontSize: 10, color: OmniTheme.textSecondary)),
                      ),
                    );
                  }).toList();
                }),
              ],
              if (_cajas.any((c) => c.values.any((v) => v.toString().isNotEmpty))) ...[
                const SizedBox(height: 12),
                _buildPreviewSection('${_cajasTable?['label'] ?? 'Cajas Procesadas'} (${_cajas.length})', OmniTheme.accentBlue, () {
                  return _cajas.map((c) {
                    final items = c.entries.where((e) => e.value.toString().isNotEmpty).map((e) => '${e.key}: ${e.value}').join(' | ');
                    if (items.isEmpty) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: OmniTheme.bg800.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(items, style: const TextStyle(fontSize: 10, color: OmniTheme.textSecondary)),
                      ),
                    );
                  }).toList();
                }),
              ],
              if (_resources.any((r) => r.values.any((v) => v.toString().isNotEmpty))) ...[
                const SizedBox(height: 12),
                _buildPreviewSection('${_resourcesTable?['label'] ?? 'Recursos'} (${_resources.length})', OmniTheme.orange400, () {
                  return _resources.map((r) {
                    final items = r.entries.where((e) => e.value.toString().isNotEmpty).map((e) => '${e.key}: ${e.value}').join(' | ');
                    if (items.isEmpty) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: OmniTheme.bg800.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(items, style: const TextStyle(fontSize: 10, color: OmniTheme.textSecondary)),
                      ),
                    );
                  }).toList();
                }),
              ],
              if (_formData['incidencias']?.toString().isNotEmpty == true) ...[
                const SizedBox(height: 12),
                _buildPreviewSection('Incidencias', OmniTheme.red400, () {
                  return [
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: OmniTheme.red400.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: OmniTheme.red400.withOpacity(0.2)),
                        ),
                        child: Text(_formData['incidencias'].toString(), style: const TextStyle(fontSize: 10, color: OmniTheme.red400)),
                      ),
                    ),
                  ];
                }),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Editar', style: TextStyle(color: OmniTheme.textMuted)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _validateAndSave();
            },
            style: TextButton.styleFrom(foregroundColor: OmniTheme.green400),
            child: const Text('Validar y Guardar'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.save, size: 16),
            onPressed: () { Navigator.pop(ctx); _save(); },
            style: ElevatedButton.styleFrom(backgroundColor: OmniTheme.accentBlue, foregroundColor: Colors.white),
            label: const Text('GUARDAR'),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewSection(String title, Color color, List<Widget> Function() buildContent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Container(width: 3, height: 14, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
        ]),
        const SizedBox(height: 6),
        ...buildContent(),
      ],
    );
  }

  Future<void> _validateAndSave() async {
    final missingFields = <String>[];
    for (final f in _generalFields) {
      if (f['required'] == true) {
        final key = f['key'] as String;
        final val = _controllers[key]?.text ?? '';
        if (val.isEmpty) {
          missingFields.add(f['label'] as String? ?? key);
        }
      }
    }
    if (missingFields.isNotEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Campos requeridos faltantes: ${missingFields.join(", ")}'),
          backgroundColor: OmniTheme.red400,
          duration: const Duration(seconds: 3),
        ));
      }
      return;
    }
    await _save();
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
      _markDirty();
    });
  }

  void _duplicateRow(List<Map<String, dynamic>> list, int index) {
    if (index >= list.length) return;
    setState(() { list.insert(index + 1, Map<String, dynamic>.from(list[index])); _markDirty(); });
  }

  void _removeRow(List<Map<String, dynamic>> list, int index) {
    if (list.length <= 1) return;
    setState(() { list.removeAt(index); _markDirty(); });
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
          if (widget.existingEntry == null) ...[
            IconButton(icon: const Icon(Icons.content_copy, size: 18), tooltip: 'Copiar de entrada anterior', onPressed: _copyFromPreviousDay, color: OmniTheme.textMuted),
          ],
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
                  child: Center(
                    child: LayoutBuilder(
                    builder: (context, constraints) => Container(
                      constraints: BoxConstraints(maxWidth: constraints.maxWidth > 800 ? 800 : constraints.maxWidth),
                      child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_generalFields.isNotEmpty) ...[
                        _buildSectionHeader('Informacion General'),
                        const SizedBox(height: 8),
                        ...List.generate(_generalFields.length, (i) => _buildAutofillField(i)),
                      ],
                      if (_activitiesTable != null && widget.module == 'procesamiento') ...[
                        const SizedBox(height: 12),
                        _buildImportFromBitacoraButton(),
                      ],
                      if (_activitiesTable != null) ...[
                        const SizedBox(height: 20),
                        _buildTableSection(
                          _activitiesTable!['label'] as String? ?? 'Actividades',
                          ((_activitiesTable!['columns'] as List?) ?? []).cast<Map<String, dynamic>>(),
                          _activities,
                          _activitiesScrollH,
                          onPaste: _makePasteCallback(_activities, ((_activitiesTable!['columns'] as List?) ?? []).cast<Map<String, dynamic>>()),
                        ),
                      ],
                      if (_cajasTable != null) ...[
                        const SizedBox(height: 20),
                        _buildTableSection(
                          _cajasTable!['label'] as String? ?? 'Cajas Procesadas',
                          ((_cajasTable!['columns'] as List?) ?? []).cast<Map<String, dynamic>>(),
                          _cajas,
                          _cajasScrollH,
                          onPaste: _makePasteCallback(_cajas, ((_cajasTable!['columns'] as List?) ?? []).cast<Map<String, dynamic>>()),
                        ),
                      ],
                      if (_resourcesTable != null) ...[
                        const SizedBox(height: 20),
                        _buildTableSection(
                          _resourcesTable!['label'] as String? ?? 'Recursos',
                          ((_resourcesTable!['columns'] as List?) ?? []).cast<Map<String, dynamic>>(),
                          _resources,
                          _resourcesScrollH,
                          onPaste: _makePasteCallback(_resources, ((_resourcesTable!['columns'] as List?) ?? []).cast<Map<String, dynamic>>()),
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
                        _markDirty();
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
                            _markDirty();
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
                            onChanged: (v) { controller.text = v ?? ''; _formData[key] = v; _markDirty(); },
                            dropdownColor: OmniTheme.bg800,
                            style: const TextStyle(fontSize: 13, color: OmniTheme.textPrimary),
                            decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                          )
                        : TextFormField(
                            controller: controller,
                            focusNode: _focusNodes[key],
                            style: const TextStyle(fontSize: 13, color: OmniTheme.textPrimary),
                            textInputAction: index < _generalFields.length - 1 ? TextInputAction.next : TextInputAction.newline,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(borderSide: BorderSide(color: OmniTheme.bg700)),
                              enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: OmniTheme.bg700)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              isDense: true,
                            ),
                            onChanged: (v) { _formData[key] = v; _markDirty(); },
                            onFieldSubmitted: index < _generalFields.length - 1
                                ? (_) { FocusScope.of(context).requestFocus(_focusNodes[_generalFields[index + 1]['key'] as String]); }
                                : null,
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableSection(String label, List<Map<String, dynamic>> columns, List<Map<String, dynamic>> rows, ScrollController scrollH, {VoidCallback? onPaste}) {
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
          if (onPaste != null) ...[const SizedBox(width: 4), _tableAction(Icons.content_paste, onPaste)],
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
            final dynamicCat = col['dynamic'] as String?;
            final options = dynamicCat != null && _equipmentOptionsByCategory.containsKey(dynamicCat)
                ? _equipmentOptionsByCategory[dynamicCat]!
                : col['options'] as List?;
            final width = (col['width'] as num?)?.toDouble() ?? 120;
            final cellValue = rows[rowIdx][key]?.toString() ?? '';
            final history = col['history'] == true ? _historyCache[key] : null;

            Widget cell;
            if (type == 'select' && options != null && options.isNotEmpty) {
              cell = _buildEditableDropdown(rows, columns, rowIdx, col, key, options, cellValue);
            } else {
              final isLastCol = columns.indexOf(col) == columns.length - 1;
              cell = TextFormField(
                initialValue: cellValue,
                style: const TextStyle(fontSize: 11, color: OmniTheme.textPrimary),
                textInputAction: isLastCol && rowIdx < rows.length - 1 ? TextInputAction.next : TextInputAction.done,
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
                onChanged: (v) { rows[rowIdx][key] = v; _markDirty(); },
                onFieldSubmitted: isLastCol && rowIdx < rows.length - 1
                    ? (_) {
                        final nextColKey = columns.isNotEmpty ? columns[0]['key'] as String : '';
                        // Focus next row by using a post-frame callback
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          FocusScope.of(context).nextFocus();
                        });
                      }
                    : null,
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

  Future<void> _loadCustomOptions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final allKeys = prefs.getKeys().where((k) => k.startsWith('custom_opts_'));
      final map = <String, List<String>>{};
      for (final k in allKeys) {
        final raw = prefs.getStringList(k);
        if (raw != null) map[k.replaceFirst('custom_opts_', '')] = raw;
      }
      _customOptions = map;
    } catch (_) {}
  }

  Future<void> _saveCustomOption(String key, String value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storageKey = 'custom_opts_$key';
      final existing = prefs.getStringList(storageKey) ?? [];
      if (!existing.contains(value)) {
        existing.add(value);
        await prefs.setStringList(storageKey, existing);
        _customOptions[key] = existing;
      }
    } catch (_) {}
  }

  Widget _buildEditableDropdown(List<Map<String, dynamic>> rows, List<Map<String, dynamic>> columns, int rowIdx, Map<String, dynamic> col, String key, List<dynamic> baseOptions, String cellValue) {
    final allOptions = <String>[
      ...baseOptions.map((o) => o.toString()),
      if (_customOptions.containsKey(key)) ..._customOptions[key]!.where((o) => !baseOptions.any((b) => b.toString() == o)),
    ];
    final effectiveOptions = allOptions.toSet().toList();

    return TextFormField(
      key: ValueKey('${rowIdx}_$key'),
      initialValue: cellValue,
      style: const TextStyle(fontSize: 11, color: OmniTheme.textPrimary),
      decoration: InputDecoration(
        border: InputBorder.none,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
        suffixIcon: effectiveOptions.isNotEmpty
            ? PopupMenuButton<String>(
                icon: const Icon(Icons.arrow_drop_down, size: 16, color: OmniTheme.textMuted),
                color: OmniTheme.bg800,
                onSelected: (v) { setState(() { rows[rowIdx][key] = v; _markDirty(); }); },
                itemBuilder: (_) => effectiveOptions.map((o) => PopupMenuItem(value: o, child: Text(o, style: const TextStyle(fontSize: 10, color: OmniTheme.textPrimary)))).toList(),
              )
            : null,
      ),
      onChanged: (v) {
        rows[rowIdx][key] = v;
        if (v.isNotEmpty && !effectiveOptions.contains(v)) {
          _saveCustomOption(key, v);
        }
        _markDirty();
      },
      onFieldSubmitted: (v) {
        if (v.isNotEmpty && !effectiveOptions.contains(v)) {
          _saveCustomOption(key, v);
        }
      },
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

  VoidCallback _makePasteCallback(List<Map<String, dynamic>> target, List<Map<String, dynamic>> columns) {
    return () async {
      try {
        final data = await Clipboard.getData(Clipboard.kTextPlain);
        if (data?.text == null || data!.text!.trim().isEmpty) return;
        final lines = data.text!.split(RegExp(r'[\r\n]+')).map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
        if (lines.isEmpty) return;

        setState(() {
          for (final line in lines) {
            final values = line.split('\t');
            final row = <String, dynamic>{};
            for (int c = 0; c < columns.length; c++) {
              row[columns[c]['key'] as String] = c < values.length ? values[c].trim() : '';
            }
            target.add(row);
          }
        });
      } catch (_) {}
    };
  }

  Widget _buildImportFromBitacoraButton() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: OutlinedButton.icon(
        icon: const Icon(Icons.import_export, size: 14),
        label: const Text('Importar cajas desde Bitácora (fecha actual)', style: TextStyle(fontSize: 11)),
        style: OutlinedButton.styleFrom(foregroundColor: OmniTheme.accentBlue, side: BorderSide(color: OmniTheme.accentBlue.withOpacity(0.4))),
        onPressed: () async {
          try {
            final fecha = _controllers['fecha']?.text;
            if (fecha == null || fecha.isEmpty) {
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecciona una fecha primero'), backgroundColor: OmniTheme.orange400));
              return;
            }
            final repo = context.read<FormRepositoryImpl>();
            final allEntries = await repo.getEntriesByModule('bitacora');
            final dayEntries = allEntries.where((e) => e.data['fecha']?.toString() == fecha || e.date == fecha).toList();
            if (dayEntries.isEmpty) {
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No hay registros en Bitácora para la fecha $fecha'), backgroundColor: OmniTheme.orange400));
              return;
            }
              int imported = 0;
              setState(() {
                for (final entry in dayEntries) {
                  final cajasList = entry.data['_cajas'] as List? ?? [];
                  for (final c in cajasList) {
                    final cMap = Map<String, dynamic>.from(c as Map);
                    final cajasTexto = cMap['cajas']?.toString() ?? '';
                    final vialesTexto = cMap['viales']?.toString() ?? '';
                    final obsTexto = cMap['observaciones']?.toString() ?? '';
                    final notasBuf = <String>[];
                    if (cajasTexto.isNotEmpty) notasBuf.add('Caja: $cajasTexto');
                    if (vialesTexto.isNotEmpty) notasBuf.add('Viales: $vialesTexto');
                    if (obsTexto.isNotEmpty) notasBuf.add(obsTexto);
                    _activities.add({
                      'presentacion': '',
                      'volumen': '',
                      'uso': '',
                      'tejido': cMap['tipo_tejido']?.toString() ?? '',
                      'paciente': '',
                      'enviado_a': '',
                      'pedido_por': '',
                      'fecha_proceso': fecha,
                      'notas': notasBuf.isNotEmpty ? notasBuf.join(' | ') : 'Importado de Bitácora',
                      'continuacion': '',
                    });
                    imported++;
                  }
                }
                _markDirty();
              });
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$imported caja(s) importada(s) desde Bitácora'), backgroundColor: OmniTheme.green400));
          } catch (e) {
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: OmniTheme.red400));
          }
        },
      ),
    );
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
