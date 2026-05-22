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
import '../widgets/operational_table.dart';
import '../../security/auth_service.dart';
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
  List<Map<String, dynamic>> _entries = [];
  bool _loading = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _moduleDef = findModule(widget.module);
    if (_moduleDef != null && (_moduleDef!['sections'] as List).length > 1) {
      _tabController = TabController(
        length: (_moduleDef!['sections'] as List).length,
        vsync: this,
      );
    }
    _loadEntries();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadEntries() async {
    setState(() => _loading = true);
    try {
      final repo = context.read<FormRepositoryImpl>();
      final section = _getCurrentSection();
      final sectionKey = section?['key'] as String?;
      final entries = sectionKey != null
          ? await repo.getEntriesByModuleAndSubModule(widget.module, sectionKey)
          : await repo.getEntriesByModule(widget.module);
      if (mounted) {
        setState(() {
          _entries = entries.map((e) => e.toJson()).toList();
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Load entries error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _copyYesterdayEntries() async {
    try {
      final repo = context.read<FormRepositoryImpl>();
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final yStr = yesterday.toIso8601String().split('T')[0];
      final entries = await repo.getEntriesByModule(widget.module);
      final yesterdayEntries = entries.where((e) => e.date.startsWith(yStr)).toList();
      if (yesterdayEntries.isEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No hay registros de ayer')));
        return;
      }
      final db = await LocalDatabase.instance.database;
      final now = DateTime.now().toUtc().toIso8601String();
      final todayStr = DateTime.now().toIso8601String().split('T')[0];
      int copied = 0;
      for (final e in yesterdayEntries) {
        final data = e.data;
        data['fecha'] = todayStr;
        await db.insert('form_entries', {
          'id': 'cpy-${DateTime.now().microsecondsSinceEpoch}-$copied',
          'module': widget.module,
          'sub_module': e.subModule,
          'date': todayStr,
          'user_id': e.userId,
          'device_id': e.deviceId,
          'version': 1,
          'data_json': jsonEncode(data),
          'status': 'saved',
          'created_at': now,
          'updated_at': now,
        });
        copied++;
      }
      _loadEntries();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$copied registros copiados de ayer')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: OmniTheme.red400));
    }
  }

  Widget _buildQuickAction(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(border: Border.all(color: OmniTheme.bg700), borderRadius: BorderRadius.circular(6)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: OmniTheme.textMuted),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 11, color: OmniTheme.textMuted)),
        ]),
      ),
    );
  }

  Widget _buildChip(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: OmniTheme.bg800, borderRadius: BorderRadius.circular(4)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 12, color: OmniTheme.accentBlue),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 10, color: OmniTheme.accentBlue)),
        ]),
      ),
    );
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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: OmniTheme.bg900,
      builder: (_) => _SmartFillModal(
        module: widget.module,
        moduleLabel: widget.moduleLabel,
        section: section,
        onSave: () {
          _loadEntries();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sections = _moduleDef?['sections'] as List? ?? [];
    final hasTabs = sections.length > 1;

    return Scaffold(
      backgroundColor: OmniTheme.bg950,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [OmniTheme.accentBlue, OmniTheme.accentIndigo]),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(_getModuleIcon(), color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            Text(widget.moduleLabel),
          ],
        ),
        bottom: hasTabs
            ? TabBar(
                controller: _tabController,
                onTap: (i) => setState(() => _activeSectionIndex = i),
                tabs: sections.map<Tab>((s) {
                  final sec = s as FormSectionDef;
                  return Tab(text: (sec['label'] as String).toUpperCase());
                }).toList(),
              )
            : null,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: OmniTheme.bg800)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Text(
                      '${_entries.length} registros',
                      style: const TextStyle(fontSize: 12, color: OmniTheme.textMuted),
                    ),
                    const Spacer(),
                    _buildQuickAction(Icons.content_copy, 'Copiar ayer', _copyYesterdayEntries),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _openForm,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('NUEVO'),
                      style: ElevatedButton.styleFrom(backgroundColor: OmniTheme.accentBlue, foregroundColor: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildChip(Icons.flash_on, 'Registro rapido', _openForm),
                    const SizedBox(width: 8),
                    _buildChip(Icons.content_paste, 'Pegar de ayer', _copyYesterdayEntries),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _entries.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inbox_outlined, size: 48, color: OmniTheme.bg700),
                            const SizedBox(height: 12),
                            const Text(
                              'Sin registros para esta seccion.',
                              style: TextStyle(color: OmniTheme.textMuted, fontSize: 12),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _entries.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final entry = _entries[index];
                          return _EntryCard(entry: entry, onDelete: _loadEntries);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  IconData _getModuleIcon() {
    switch (widget.module) {
      case 'incubadoras': return Icons.thermostat_outlined;
      case 'autoclaves': return Icons.local_fire_department_outlined;
      case 'ultracongeladores': return Icons.ac_unit_outlined;
      case 'equipos': return Icons.precision_manufacturing_outlined;
      case 'procesamiento': return Icons.biotech_outlined;
      case 'bitacora': return Icons.book_outlined;
      default: return Icons.folder_outlined;
    }
  }
}

class _EntryCard extends StatelessWidget {
  final Map<String, dynamic> entry;
  final VoidCallback onDelete;

  const _EntryCard({required this.entry, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    Map<String, dynamic> data = {};
    try {
      data = jsonDecode(entry['data_json'] as String);
    } catch (_) {}

    final date = entry['date']?.toString() ?? '';
    final status = entry['status']?.toString() ?? 'pending';

    return Card(
      child: InkWell(
        onTap: () => _showDetail(context, data, date, status),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 40,
                decoration: BoxDecoration(
                  color: status == 'synced' ? OmniTheme.green400 : OmniTheme.orange400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      date.length >= 10 ? date.substring(0, 10) : date,
                      style: const TextStyle(
                        fontFamily: 'Outfit',
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: OmniTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getSummary(data),
                      style: const TextStyle(fontSize: 12, color: OmniTheme.textMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: status == 'synced'
                      ? OmniTheme.green400.withOpacity(0.1)
                      : OmniTheme.orange400.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  status == 'synced' ? 'SYNCED' : 'PENDING',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: status == 'synced' ? OmniTheme.green400 : OmniTheme.orange400,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getSummary(Map<String, dynamic> data) {
    final keys = ['usuario', 'operador', 'responsable', 'nombre', 'paciente', 'equipo', 'modelo'];
    for (final k in keys) {
      if (data[k] != null && data[k].toString().isNotEmpty) {
        return data[k].toString();
      }
    }
    return data.entries.take(2).map((e) => '${e.value}').join(' / ');
  }

  void _showDetail(BuildContext context, Map<String, dynamic> data, String date, String status) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: OmniTheme.bg900,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
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
                    const Text(
                      'Detalle del Registro',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: OmniTheme.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  children: [
                    Text(
                      date.length >= 10 ? date.substring(0, 10) : date,
                      style: const TextStyle(
                        fontFamily: 'Outfit',
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: OmniTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...data.entries.map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (e.key as String).toUpperCase(),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: OmniTheme.textMuted,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            e.value?.toString() ?? '-',
                            style: const TextStyle(fontSize: 14, color: OmniTheme.textPrimary),
                          ),
                        ],
                      ),
                    )),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SmartFillModal extends StatefulWidget {
  final String module;
  final String moduleLabel;
  final FormSectionDef section;
  final VoidCallback onSave;

  const _SmartFillModal({
    required this.module,
    required this.moduleLabel,
    required this.section,
    required this.onSave,
  });

  @override
  State<_SmartFillModal> createState() => _SmartFillModalState();
}

class _SmartFillModalState extends State<_SmartFillModal> {
  final Map<String, dynamic> _formData = {};
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, GlobalKey<FormState>> _formKeys = {};
  final Map<String, FocusNode> _focusNodes = {};
  bool _isSaving = false;
  bool _saveSuccess = false;
  String? _saveError;
  bool _quickEntryMode = false;
  Timer? _autoSaveTimer;
  int _completedFields = 0;
  int _totalRequired = 0;
  List<Map<String, dynamic>> _tableRows = [];
  bool _isTableMode = false;

  @override
  void initState() {
    super.initState();
    _isTableMode = widget.section['mode'] == 'table';
    _initForm();
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    for (final c in _controllers.values) {
      c.dispose();
    }
    for (final f in _focusNodes.values) {
      f.dispose();
    }
    super.dispose();
  }

  void _initForm() {
    final fields = widget.section['fields'] as List;
    final now = DateTime.now();
    final today = now.toIso8601String().split('T')[0];
    final nowTime = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    _totalRequired = fields.where((f) => f['required'] == true).length;
    final userName = context.read<AuthService>().currentUser?.nombre ?? '';

    if (_isTableMode) {
      for (final f in fields) {
        final key = f['key'] as String;
        final type = f['type'] as String;
        if (type == 'date') _formData[key] = today;
        else if (type == 'time') _formData[key] = nowTime;
        else if (key == 'responsable' || key == 'usuario' || key == 'nombre' || key == 'operador' || key == 'firma_responsable') {
          _formData[key] = userName;
        } else _formData[key] = '';
        _controllers[key] = TextEditingController(text: _formData[key]?.toString() ?? '');
      }
      _tableRows = [{}];
    } else {
      for (int i = 0; i < fields.length; i++) {
        final f = fields[i];
        final key = f['key'] as String;
        final type = f['type'] as String;
        _formKeys[key] = GlobalKey<FormState>();
        _focusNodes[key] = FocusNode();

        if (type == 'date') _formData[key] = today;
        else if (type == 'time') _formData[key] = nowTime;
        else if (key == 'responsable' || key == 'usuario' || key == 'nombre' || key == 'operador' || key == 'firma_responsable') {
          _formData[key] = userName;
        } else _formData[key] = '';
        _controllers[key] = TextEditingController(text: _formData[key]?.toString() ?? '');
      }
    }
  }

  void _onFieldChanged(String key) {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(seconds: 3), () => _save(auto: true));

    final fields = widget.section['fields'] as List;
    int completed = 0;
    for (final f in fields) {
      final k = f['key'] as String;
      final c = _controllers[k];
      final isRequired = f['required'] == true;
      if (c != null && c.text.isNotEmpty) {
        if (isRequired || !isRequired) completed++;
      }
    }
    setState(() => _completedFields = completed);
  }

  Future<void> _copyLastEntry() async {
    try {
      final repo = context.read<FormRepositoryImpl>();
      final entries = await repo.getEntriesByModule(widget.module);
      if (entries.isEmpty) return;
      final lastEntry = entries.first;
      final lastData = lastEntry.data;

      if (_isTableMode) {
        final tableData = lastData['_table_rows'] as List? ?? [];
        if (tableData.isNotEmpty) {
          final lastRows = tableData.map((r) => Map<String, dynamic>.from(r as Map)).toList();
          setState(() => _tableRows = lastRows);
        }
        for (final entry in lastData.entries) {
          final key = entry.key;
          if (key == '_table_rows' || key == 'fecha') continue;
          if (_controllers.containsKey(key)) {
            final val = entry.value?.toString() ?? '';
            _controllers[key]?.text = val;
            _formData[key] = val;
          }
        }
      } else {
        final fields = widget.section['fields'] as List;
        for (final f in fields) {
          final key = f['key'] as String;
          final type = f['type'] as String;
          if (type == 'date') continue;
          if (type == 'time') continue;
          if (lastData.containsKey(key)) {
            final val = lastData[key]?.toString() ?? '';
            _formData[key] = val;
            _controllers[key]?.text = val;
          }
        }
      }
      setState(() {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Datos copiados del ultimo registro')),
        );
      }
    } catch (_) {}
  }

  Future<void> _copyYesterday() async {
    try {
      final repo = context.read<FormRepositoryImpl>();
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final yStr = yesterday.toIso8601String().split('T')[0];
      final entries = await repo.getEntriesByModule(widget.module);
      final yesterdayEntries = entries.where((e) => e.date.startsWith(yStr)).toList();

      if (_isTableMode) {
        final rows = <Map<String, dynamic>>[];
        for (final e in yesterdayEntries) {
          final data = e.data;
          final tableData = data['_table_rows'] as List?;
          if (tableData != null) {
            rows.addAll(tableData.map((r) => Map<String, dynamic>.from(r as Map)));
          } else {
            final row = <String, dynamic>{};
            for (final col in (widget.section['table_columns'] as List?) ?? []) {
              final k = col['key'] as String;
              if (data.containsKey(k)) row[k] = data[k];
            }
            if (row.isNotEmpty) rows.add(row);
          }
        }
        if (rows.isNotEmpty) setState(() => _tableRows = rows);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Copiados ${yesterdayEntries.length} registros de ayer')),
        );
      }
    } catch (_) {}
  }

  Future<void> _save({bool auto = false}) async {
    if (_isSaving) return;
    setState(() {
      _isSaving = true;
      _saveError = null;
      _saveSuccess = false;
    });

    try {
      final auth = context.read<AuthService>();
      final prefs = await SharedPreferences.getInstance();
      final deviceId = prefs.getString('device_id') ?? '';
      final repo = context.read<FormRepositoryImpl>();
      final sync = context.read<SyncEngine>();

      if (_isTableMode) {
        final fields = widget.section['fields'] as List;
        for (final f in fields) {
          final key = f['key'] as String;
          final controller = _controllers[key];
          if (controller != null) _formData[key] = controller.text;
        }
        for (final row in _tableRows) {
          final data = Map<String, dynamic>.from(_formData);
          data.addAll(row);
          await repo.createEntry(
            module: widget.module,
            subModule: widget.section['key'] as String?,
            date: _formData['fecha']?.toString() ?? DateTime.now().toIso8601String().split('T')[0],
            userId: auth.currentUser?.id ?? 'offline',
            deviceId: deviceId,
            data: data,
          );
        }
      } else {
        final fields = widget.section['fields'] as List;
        for (final f in fields) {
          final key = f['key'] as String;
          final controller = _controllers[key];
          if (controller != null) _formData[key] = controller.text;
        }

        await repo.createEntry(
          module: widget.module,
          subModule: widget.section['key'] as String?,
          date: _formData['fecha']?.toString() ?? DateTime.now().toIso8601String().split('T')[0],
          userId: auth.currentUser?.id ?? 'offline',
          deviceId: deviceId,
          data: _formData,
        );
      }

      if (!auto) await sync.synchronize();

      if (mounted) {
        setState(() => _saveSuccess = true);

        if (auto) {
          await Future.delayed(const Duration(milliseconds: 1500));
          if (mounted) setState(() => _saveSuccess = false);
          _isSaving = false;
          if (mounted) setState(() {});
          return;
        }

        await Future.delayed(const Duration(milliseconds: 800));

        if (_quickEntryMode && !_isTableMode) {
          final fields = widget.section['fields'] as List;
          final skipKeys = {'usuario', 'operador', 'responsable', 'nombre', 'equipo', 'modelo'};
          for (final f in fields) {
            final key = f['key'] as String;
            final type = f['type'] as String;
            if (skipKeys.contains(key)) continue;
            if (type == 'date') {
              _formData[key] = DateTime.now().toIso8601String().split('T')[0];
            } else if (type == 'time') {
              final now = DateTime.now();
              _formData[key] = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
            } else {
              _formData[key] = '';
            }
            _controllers[key]?.text = _formData[key]?.toString() ?? '';
          }
          setState(() {
            _saveSuccess = false;
            _completedFields = 0;
          });
        } else {
          widget.onSave();
          Navigator.pop(context);
        }
      }
    } catch (e) {
      debugPrint('Save error: $e');
      if (mounted) {
        setState(() => _saveError = e.toString());
      }
    } finally {
      if (mounted && !auto) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fields = widget.section['fields'] as List;

    return CallbackShortcuts(
      bindings: {
        SingleActivator(LogicalKeyboardKey.keyS, control: true): () => _save(),
        SingleActivator(LogicalKeyboardKey.keyD, control: true): () => _isTableMode ? null : _copyLastEntry(),
        SingleActivator(LogicalKeyboardKey.enter, control: true): () => _save(),
      },
      child: Focus(
        autofocus: true,
        child: DraggableScrollableSheet(
          initialChildSize: _isTableMode ? 0.95 : 0.9,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          expand: false,
          builder: (_, scrollController) {
            return Column(
              children: [
                _buildHeader(),
                if (!_isTableMode && _totalRequired > 0) _buildProgressBar(),
                const Divider(height: 1),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(20),
                    children: [
                      if (_isTableMode) ...[
                        _buildTableHeaderFields(fields),
                        const SizedBox(height: 16),
                        _buildTableWidget(),
                      ] else
                        _buildFieldGrid(fields),
                    ],
                  ),
                ),
                _buildFooter(),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    final pct = _totalRequired > 0 ? (_completedFields / _totalRequired) : 0.0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct.clamp(0.0, 1.0),
                backgroundColor: OmniTheme.bg800,
                valueColor: AlwaysStoppedAnimation<Color>(
                  pct >= 1.0 ? OmniTheme.green400 : OmniTheme.accentBlue,
                ),
                minHeight: 4,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '$_completedFields/$_totalRequired',
            style: const TextStyle(fontSize: 11, color: OmniTheme.textMuted, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.section['label'] as String? ?? 'Registro',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: OmniTheme.textPrimary),
                ),
                Text(
                  '${widget.moduleLabel}'.toUpperCase(),
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: OmniTheme.textMuted, letterSpacing: 1.5),
                ),
              ],
            ),
          ),
          _buildQuickActions(),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: () => Navigator.pop(context),
            color: OmniTheme.textMuted,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildActionBtn(Icons.content_copy, 'Copiar ultimo', _copyLastEntry),
        const SizedBox(width: 4),
        _buildActionBtn(Icons.calendar_view_day, 'Copiar ayer', _copyYesterday),
        if (!_isTableMode) ...[
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () => setState(() => _quickEntryMode = !_quickEntryMode),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _quickEntryMode ? OmniTheme.accentBlue.withOpacity(0.2) : OmniTheme.bg800,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _quickEntryMode ? OmniTheme.accentBlue.withOpacity(0.3) : OmniTheme.bg700),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_quickEntryMode ? Icons.flash_on : Icons.flash_off, size: 14, color: _quickEntryMode ? OmniTheme.accentBlue : OmniTheme.textMuted),
                  const SizedBox(width: 4),
                  Text(_quickEntryMode ? 'Rapido' : 'Simple', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _quickEntryMode ? OmniTheme.accentBlue : OmniTheme.textMuted)),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildActionBtn(IconData icon, String tooltip, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border.all(color: OmniTheme.bg700),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 16, color: OmniTheme.textMuted),
        ),
      ),
    );
  }

  Widget _buildTableHeaderFields(List fields) {
    final dateField = fields.firstWhere(
      (f) => (f as Map)['type'] == 'date',
      orElse: () => <String, dynamic>{'key': 'fecha', 'label': 'Fecha'},
    ) as Map<String, dynamic>;
    final dateKey = dateField['key'] as String? ?? 'fecha';
    final dateLabel = dateField['label'] as String? ?? 'Fecha';

    return Row(
      children: [
        SizedBox(
          width: 160,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(dateLabel.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: OmniTheme.textMuted, letterSpacing: 1.5)),
              const SizedBox(height: 4),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                    builder: (context, child) => Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: const ColorScheme.dark(primary: OmniTheme.accentBlue, onPrimary: Colors.white, surface: OmniTheme.bg900, onSurface: OmniTheme.textPrimary),
                      ),
                      child: child!,
                    ),
                  );
                  if (picked != null) {
                    final val = picked.toIso8601String().split('T')[0];
                    _controllers[dateKey]?.text = val;
                    _formData[dateKey] = val;
                    setState(() {});
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(border: Border.all(color: OmniTheme.bg700), borderRadius: BorderRadius.circular(4)),
                  child: Row(
                    children: [
                      Expanded(child: Text(_controllers[dateKey]?.text.isNotEmpty == true ? _controllers[dateKey]!.text : 'Seleccionar', style: const TextStyle(fontSize: 13, color: OmniTheme.textPrimary))),
                      const Icon(Icons.calendar_today, size: 14, color: OmniTheme.textMuted),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('REGISTROS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: OmniTheme.textMuted, letterSpacing: 1.5)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: OmniTheme.accentBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
              child: Text('${_tableRows.length} filas', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: OmniTheme.accentBlue)),
            ),
          ],
        ),
        const Spacer(),
        _buildActionBtn(Icons.auto_fix_high, 'Atajos: Ctrl+S Guardar, Ctrl+D Copiar', () => _showShortcutsInfo()),
      ],
    );
  }

  void _showShortcutsInfo() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: OmniTheme.bg900,
        title: const Text('Atajos de Teclado', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _shortcutRow('Ctrl + S', 'Guardar'),
            _shortcutRow('Ctrl + Enter', 'Guardar'),
            _shortcutRow('Ctrl + D', 'Copiar ultimo registro'),
            _shortcutRow('Tab', 'Siguiente campo'),
            _shortcutRow('Enter', 'Siguiente campo'),
            const SizedBox(height: 12),
            const Text('En tablas operativas:', style: TextStyle(color: OmniTheme.textMuted, fontSize: 11)),
            _shortcutRow('Click +', 'Agregar fila'),
            _shortcutRow('Icono copia', 'Duplicar fila'),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar', style: TextStyle(color: Colors.white54)))],
      ),
    );
  }

  Widget _shortcutRow(String key, String desc) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: OmniTheme.bg800, borderRadius: BorderRadius.circular(4)),
            child: Text(key, style: const TextStyle(fontSize: 11, color: OmniTheme.accentBlue, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          Text(desc, style: const TextStyle(fontSize: 13, color: OmniTheme.textPrimary)),
        ],
      ),
    );
  }

  Widget _buildTableWidget() {
    final columns = (widget.section['table_columns'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    return OperationalTable(
      label: '${widget.section['label'] ?? 'Registros'}',
      columns: columns,
      rows: _tableRows,
      onChanged: (rows) => _tableRows = rows,
    );
  }

  Widget _buildFieldGrid(List fields) {
    final List<Widget> rows = [];

    for (int i = 0; i < fields.length; i += 2) {
      final f1 = fields[i];
      final f2 = (i + 1 < fields.length) ? fields[i + 1] : null;

      rows.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildField(f1, i, fields.length)),
            if (f2 != null) ...[
              const SizedBox(width: 12),
              Expanded(child: _buildField(f2, i + 1, fields.length)),
            ] else
              const SizedBox(width: 12),
          ],
        ),
      );

      if (i + 2 < fields.length) {
        rows.add(const SizedBox(height: 12));
      }
    }

    return Column(children: rows);
  }

  Widget _buildField(dynamic f, int index, int totalFields) {
    final key = f['key'] as String;
    final label = f['label'] as String;
    final type = f['type'] as String;
    final required = f['required'] as bool? ?? false;
    final options = f['options'] as List?;
    final unit = f['unit'] as String?;
    final multiline = f['multiline'] as bool? ?? false;
    final controller = _controllers[key]!;
    final isLast = index == totalFields - 1;

    void _nextField() {
      final nextIndex = index + 1;
      if (nextIndex < totalFields) {
        final nextFields = widget.section['fields'] as List;
        final nextKey = nextFields[nextIndex]['key'] as String;
        _focusNodes[nextKey]?.requestFocus();
      }
    }

    return Form(
      key: _formKeys[key],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label.toUpperCase(),
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: OmniTheme.textMuted,
                  letterSpacing: 1.5,
                ),
              ),
              if (required)
                const Text(
                  ' *',
                  style: TextStyle(color: OmniTheme.red400, fontSize: 10),
                ),
            ],
          ),
          const SizedBox(height: 4),
          if (type == 'select' && options != null)
            DropdownButtonFormField<String>(
              value: controller.text.isEmpty ? null : controller.text,
              focusNode: _focusNodes[key],
              items: options.map<DropdownMenuItem<String>>((opt) {
                return DropdownMenuItem<String>(
                  value: opt.toString(),
                  child: Text(opt.toString(), style: const TextStyle(fontSize: 14, color: OmniTheme.textPrimary)),
                );
              }).toList(),
              onChanged: (v) {
                controller.text = v ?? '';
                _formData[key] = v;
                _onFieldChanged(key);
                if (!isLast) _nextField();
              },
              decoration: const InputDecoration(
                hintText: 'Seleccionar',
              ),
            )
          else if (type == 'date')
            InkWell(
              focusNode: _focusNodes[key],
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                  builder: (context, child) {
                    return Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: const ColorScheme.dark(
                          primary: OmniTheme.accentBlue,
                          onPrimary: Colors.white,
                          surface: OmniTheme.bg900,
                          onSurface: OmniTheme.textPrimary,
                        ),
                      ),
                      child: child!,
                    );
                  },
                );
                if (picked != null) {
                  controller.text = picked.toIso8601String().split('T')[0];
                  _formData[key] = controller.text;
                  _onFieldChanged(key);
                  if (!isLast) _nextField();
                }
              },
              child: InputDecorator(
                decoration: const InputDecoration(),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        controller.text.isNotEmpty ? controller.text : 'Seleccionar fecha',
                        style: TextStyle(
                          fontSize: 14,
                          color: controller.text.isNotEmpty ? OmniTheme.textPrimary : OmniTheme.bg700,
                        ),
                      ),
                    ),
                    const Icon(Icons.calendar_today, size: 16, color: OmniTheme.textMuted),
                  ],
                ),
              ),
            )
          else if (type == 'time')
            InkWell(
              focusNode: _focusNodes[key],
              onTap: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.now(),
                  builder: (context, child) {
                    return Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: const ColorScheme.dark(
                          primary: OmniTheme.accentBlue,
                          onPrimary: Colors.white,
                          surface: OmniTheme.bg900,
                          onSurface: OmniTheme.textPrimary,
                        ),
                      ),
                      child: child!,
                    );
                  },
                );
                if (picked != null) {
                  controller.text = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                  _formData[key] = controller.text;
                  _onFieldChanged(key);
                  if (!isLast) _nextField();
                }
              },
              child: InputDecorator(
                decoration: const InputDecoration(),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        controller.text.isNotEmpty ? controller.text : 'Seleccionar hora',
                        style: TextStyle(
                          fontSize: 14,
                          color: controller.text.isNotEmpty ? OmniTheme.textPrimary : OmniTheme.bg700,
                        ),
                      ),
                    ),
                    const Icon(Icons.access_time, size: 16, color: OmniTheme.textMuted),
                  ],
                ),
              ),
            )
          else
            TextFormField(
              controller: controller,
              focusNode: _focusNodes[key],
              maxLines: multiline ? 3 : 1,
              keyboardType: type == 'number' ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
              textInputAction: isLast ? TextInputAction.done : TextInputAction.next,
              style: const TextStyle(fontSize: 14, color: OmniTheme.textPrimary),
              decoration: InputDecoration(
                suffixText: unit,
                suffixStyle: const TextStyle(color: OmniTheme.textMuted, fontSize: 12),
              ),
              onChanged: (v) {
                _formData[key] = v;
                _onFieldChanged(key);
              },
              onFieldSubmitted: (_) {
                SmartFormFieldHistory.saveValue(key, controller.text);
                if (!isLast) _nextField();
              },
            ),
        ],
      ),
    );
  }

  void _showPreview() {
    final fields = widget.section['fields'] as List;
    for (final f in fields) {
      final key = f['key'] as String;
      final controller = _controllers[key];
      if (controller != null) _formData[key] = controller.text;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: OmniTheme.bg900,
        title: Row(
          children: [
            const Icon(Icons.preview, size: 20, color: OmniTheme.accentBlue),
            const SizedBox(width: 8),
            Text('Vista previa - ${widget.moduleLabel}', style: const TextStyle(fontSize: 14, color: OmniTheme.textPrimary)),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: ListView(
            shrinkWrap: true,
            children: [
              ...fields.map((f) {
                final key = f['key'] as String;
                final label = f['label'] as String? ?? key;
                final val = _formData[key]?.toString() ?? '';
                if (val.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(width: 130, child: Text('$label:', style: const TextStyle(fontSize: 11, color: OmniTheme.textMuted))),
                      Expanded(child: Text(val, style: const TextStyle(fontSize: 11, color: OmniTheme.textPrimary))),
                    ],
                  ),
                );
              }),
              if (_isTableMode && _tableRows.isNotEmpty) ...[
                const Divider(color: OmniTheme.bg800),
                Text('${_tableRows.length} filas en tabla', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: OmniTheme.accentBlue)),
                ..._tableRows.map((row) => Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(row.entries.map((e) => '${e.key}: ${e.value}').join(' | '), style: const TextStyle(fontSize: 10, color: OmniTheme.textSecondary)),
                )),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Editar', style: TextStyle(color: OmniTheme.textMuted))),
          ElevatedButton(
            onPressed: () { Navigator.pop(ctx); _save(); },
            style: ElevatedButton.styleFrom(backgroundColor: OmniTheme.green400, foregroundColor: Colors.white),
            child: const Text('GUARDAR'),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    final rowCount = _isTableMode ? _tableRows.length : 1;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: OmniTheme.bg800)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _saveError != null
                ? Text('$_saveError', style: const TextStyle(fontSize: 12, color: OmniTheme.red400))
                : _saveSuccess
                    ? Text('Guardado correctamente', style: const TextStyle(fontSize: 12, color: OmniTheme.green400))
                    : _isTableMode
                        ? Text('$rowCount registros por importar', style: const TextStyle(fontSize: 12, color: OmniTheme.textMuted))
                        : const SizedBox.shrink(),
          ),
          const SizedBox(width: 12),
          TextButton(
            onPressed: _isSaving ? null : () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: _isSaving || _saveSuccess ? null : _showPreview,
            style: ElevatedButton.styleFrom(backgroundColor: OmniTheme.accentBlue, foregroundColor: Colors.white),
            child: _isSaving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(_isTableMode ? 'IMPORTAR $rowCount REGISTROS' : 'CONFIRMAR'),
          ),
        ],
      ),
    );
  }
}
