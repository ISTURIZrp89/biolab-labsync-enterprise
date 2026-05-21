import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/repositories/form_repository_impl.dart';
import '../../domain/entities/form_entry.dart';
import '../../domain/form_definitions.dart';
import '../../security/auth_service.dart';
import '../../sync/sync_engine.dart';
import '../widgets/smart_form_field.dart';

class FormEntryScreen extends StatefulWidget {
  final String module;
  final String moduleLabel;

  const FormEntryScreen({
    super.key,
    required this.module,
    required this.moduleLabel,
  });

  @override
  State<FormEntryScreen> createState() => _FormEntryScreenState();
}

class _FormEntryScreenState extends State<FormEntryScreen> with SingleTickerProviderStateMixin {
  final FormRepositoryImpl _formRepo = FormRepositoryImpl();
  TabController? _tabController;
  String? _selectedSection;
  List<FormEntry> _entries = [];
  bool _loading = true;
  FormModuleDef _moduleDef = <String, dynamic>{};

  @override
  void initState() {
    super.initState();
    _moduleDef = findModule(widget.module);
    final sections = _moduleDef['sections'] as List? ?? [];
    if (sections.isNotEmpty) {
      _selectedSection = sections.first['key'] as String;
      _tabController = TabController(length: sections.length, vsync: this);
      _tabController!.addListener(() {
        if (!_tabController!.indexIsChanging) {
          final section = sections[_tabController!.index];
          setState(() => _selectedSection = section['key'] as String);
          _loadEntries();
        }
      });
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
      List<FormEntry> entries;
      if (_selectedSection != null) {
        entries = await _formRepo.getEntriesByModuleAndSubModule(widget.module, _selectedSection!);
      } else {
        entries = await _formRepo.getEntriesByModule(widget.module);
      }
      if (mounted) {
        setState(() => _entries = entries);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _entries = []);
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _openForm({FormEntry? existing, Map<String, dynamic>? prefilledValues, bool quickEntry = false}) async {
    final section = findSection(widget.module, _selectedSection ?? '');
    if (section == null && (_moduleDef['sections'] as List?)?.isEmpty == true) {
      return;
    }

    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => _FormBuilderScreen(
          module: widget.module,
          moduleLabel: widget.moduleLabel,
          sectionKey: _selectedSection,
          section: section,
          existingEntry: existing,
          prefilledValues: prefilledValues,
          quickEntry: quickEntry,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );

    if (result != null) {
      _loadEntries();
      if (result['quickEntry'] == true) {
        _openForm(
          prefilledValues: result['formData'] as Map<String, dynamic>?,
          quickEntry: true,
        );
      }
    }
  }

  Future<void> _syncNow() async {
    if (!mounted) return;
    final syncEngine = context.read<SyncEngine>();
    final success = await syncEngine.synchronize();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(success ? Icons.check_circle : Icons.warning_amber, color: success ? const Color(0xFF22C55E) : const Color(0xFFF59E0B)),
              const SizedBox(width: 12),
              Text(success ? 'Sincronizacion completada' : 'Error al sincronizar'),
            ],
          ),
          backgroundColor: const Color(0xFF1E293B),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      if (success) _loadEntries();
    }
  }

  void _showEntryDetails(FormEntry entry) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(_getModuleIcon(), color: _getModuleColor(), size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _getSectionLabel(entry.subModule),
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _detailRow('Fecha', _formatDate(entry.date)),
                _detailRow('Usuario', entry.data['usuario'] ?? entry.data['nombre'] ?? entry.data['responsable'] ?? '-'),
                const Divider(color: Colors.white10),
                ...entry.data.entries.map((e) => _detailRow(_formatKey(e.key), _formatValue(e.value))),
                const Divider(color: Colors.white10),
                _detailRow('Estado', entry.status.toUpperCase()),
                _detailRow('Creado', _formatDateTime(entry.createdAt)),
                _detailRow('Actualizado', _formatDateTime(entry.updatedAt)),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _openForm(existing: entry);
            },
            style: ElevatedButton.styleFrom(backgroundColor: _getModuleColor()),
            child: const Text('Editar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  String _formatKey(String key) {
    return key.replaceAll('_', ' ').split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1);
    }).join(' ');
  }

  String _formatValue(dynamic value) {
    if (value == null) return '-';
    return value.toString();
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd/MM/yyyy').format(date);
    } catch (_) {
      return dateStr;
    }
  }

  String _formatDateTime(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd/MM/yyyy HH:mm').format(date.toLocal());
    } catch (_) {
      return dateStr;
    }
  }

  String _getSectionLabel(String? sectionKey) {
    if (sectionKey == null) return widget.moduleLabel;
    final section = findSection(widget.module, sectionKey);
    return section?['label'] as String? ?? sectionKey;
  }

  String _getEntrySummary(FormEntry entry) {
    final data = entry.data;
    final priorityKeys = ['equipo', 'modelo', 'nombre', 'paciente', 'contenido', 'producto', 'responsable', 'actividad', 'tipo_actividad'];
    for (var key in priorityKeys) {
      if (data.containsKey(key) && data[key].toString().isNotEmpty) {
        return data[key].toString();
      }
    }
    if (data.isNotEmpty) {
      return data.values.firstWhere(
        (v) => v.toString().isNotEmpty,
        orElse: () => 'Sin datos',
      ).toString();
    }
    return 'Sin datos';
  }

  IconData _getModuleIcon() {
    final iconStr = _moduleDef['icon'] as String?;
    switch (iconStr) {
      case 'thermostat': return Icons.thermostat;
      case 'local_fire_department': return Icons.local_fire_department;
      case 'ac_unit': return Icons.ac_unit;
      case 'precision_manufacturing': return Icons.precision_manufacturing;
      case 'biotech': return Icons.biotech;
      case 'book': return Icons.book;
      default: return Icons.folder;
    }
  }

  Color _getModuleColor() {
    final colorStr = _moduleDef['color'] as String?;
    if (colorStr != null) {
      try {
        return Color(int.parse(colorStr));
      } catch (_) {}
    }
    return const Color(0xFF3B82F6);
  }

  @override
  Widget build(BuildContext context) {
    final sections = _moduleDef['sections'] as List? ?? [];

    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      appBar: AppBar(
        title: Row(
          children: [
            Icon(_getModuleIcon(), color: _getModuleColor(), size: 22),
            const SizedBox(width: 10),
            Text(widget.moduleLabel),
          ],
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: sections.length > 1
            ? TabBar(
                controller: _tabController,
                isScrollable: true,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white54,
                indicatorColor: _getModuleColor(),
                indicatorSize: TabBarIndicatorSize.tab,
                tabs: sections.map((s) => Tab(text: s['label'] as String)).toList(),
              )
            : null,
        actions: [
          Consumer<SyncEngine>(
            builder: (context, sync, _) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Container(
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
            ),
          ),
          IconButton(
            icon: const Icon(Icons.sync, size: 20),
            onPressed: _syncNow,
            tooltip: 'Sincronizar ahora',
          ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: _loadEntries,
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
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _openForm(),
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('Nuevo Registro'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _getModuleColor(),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF3B82F6)))
                  : _entries.isEmpty
                      ? _buildEmptyState()
                      : _buildEntriesList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _getModuleIcon(),
            size: 80,
            color: Colors.white.withOpacity(0.1),
          ),
          const SizedBox(height: 16),
          Text(
            'Sin registros en ${_getSectionLabel(_selectedSection)}',
            style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'Presiona "Nuevo Registro" para comenzar',
            style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildEntriesList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      itemCount: _entries.length,
      itemBuilder: (context, index) {
        final entry = _entries[index];
        final summary = _getEntrySummary(entry);
        final dateStr = _formatDate(entry.date);

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _showEntryDetails(entry),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: _getModuleColor().withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(_getModuleIcon(), color: _getModuleColor(), size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            summary,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 14),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            dateStr,
                            style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12),
                          ),
                          if (entry.subModule != null)
                            Text(
                              _getSectionLabel(entry.subModule),
                              style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 11),
                            ),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getStatusBgColor(entry.status),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            entry.status.toUpperCase(),
                            style: TextStyle(
                              color: _getStatusColor(entry.status),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.visibility_outlined, color: Colors.white54, size: 18),
                          onPressed: () => _showEntryDetails(entry),
                          tooltip: 'Ver detalles',
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.all(8),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, color: Colors.white54, size: 18),
                          onPressed: () => _openForm(existing: entry),
                          tooltip: 'Editar',
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.all(8),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'saved': return const Color(0xFF22C55E);
      case 'synced': return const Color(0xFF3B82F6);
      case 'pending': return const Color(0xFFF59E0B);
      default: return Colors.white54;
    }
  }

  Color _getStatusBgColor(String status) {
    switch (status.toLowerCase()) {
      case 'saved': return const Color(0xFF22C55E).withOpacity(0.15);
      case 'synced': return const Color(0xFF3B82F6).withOpacity(0.15);
      case 'pending': return const Color(0xFFF59E0B).withOpacity(0.15);
      default: return Colors.white.withOpacity(0.1);
    }
  }
}

class _FormBuilderScreen extends StatefulWidget {
  final String module;
  final String moduleLabel;
  final String? sectionKey;
  final FormSectionDef? section;
  final FormEntry? existingEntry;
  final Map<String, dynamic>? prefilledValues;
  final bool quickEntry;

  const _FormBuilderScreen({
    required this.module,
    required this.moduleLabel,
    this.sectionKey,
    this.section,
    this.existingEntry,
    this.prefilledValues,
    this.quickEntry = false,
  });

  @override
  State<_FormBuilderScreen> createState() => _FormBuilderScreenState();
}

class _FormBuilderScreenState extends State<_FormBuilderScreen> {
  final FormRepositoryImpl _formRepo = FormRepositoryImpl();
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, dynamic> _fieldValues = {};
  final Map<String, FocusNode> _focusNodes = {};
  bool _saving = false;
  bool _quickEntryMode = false;

  @override
  void initState() {
    super.initState();
    _quickEntryMode = widget.quickEntry;
    _initFields();
  }

  void _initFields() {
    final fields = widget.section?['fields'] as List? ?? [];
    final existingData = widget.existingEntry?.data ?? {};
    final prefilled = widget.prefilledValues ?? {};

    final smartDefaults = _getSmartDefaults();

    for (var field in fields) {
      final key = field['key'] as String;
      final type = field['type'] as String;
      var initial = existingData[key] ?? prefilled[key];

      if (initial == null || initial.toString().isEmpty) {
        initial = smartDefaults[key];
      }
      if (initial == null || initial.toString().isEmpty) {
        initial = field['initial'];
      }

      _focusNodes[key] = FocusNode();

      if (type == 'select') {
        _fieldValues[key] = initial?.toString() ?? '';
      } else if (type == 'date' || type == 'time' || type == 'datetime') {
        _fieldValues[key] = initial?.toString() ?? '';
        _controllers[key] = TextEditingController(text: _formatInitialValue(type, initial));
      } else {
        _fieldValues[key] = initial?.toString() ?? '';
        _controllers[key] = TextEditingController(text: _fieldValues[key].toString());
      }
    }
  }

  Map<String, dynamic> _getSmartDefaults() {
    final now = DateTime.now();
    return {
      'fecha': DateFormat('yyyy-MM-dd').format(now),
      'hora': '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
      'hora_inicio': '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
      'estado': 'ACTIVO',
    };
  }

  String _formatInitialValue(String type, dynamic value) {
    if (value == null || value.toString().isEmpty) return '';
    final str = value.toString();
    if (type == 'date') {
      try {
        final date = DateTime.parse(str);
        return DateFormat('dd/MM/yyyy').format(date);
      } catch (_) {
        return str;
      }
    } else if (type == 'time') {
      try {
        final parts = str.split(':');
        return '${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}';
      } catch (_) {
        return str;
      }
    } else if (type == 'datetime') {
      try {
        final date = DateTime.parse(str);
        return DateFormat('dd/MM/yyyy HH:mm').format(date.toLocal());
      } catch (_) {
        return str;
      }
    }
    return str;
  }

  @override
  void dispose() {
    for (var c in _controllers.values) {
      c.dispose();
    }
    for (var n in _focusNodes.values) {
      n.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate(String key) async {
    final initialDate = _controllers[key]?.text.isNotEmpty == true
        ? _tryParseDate(_controllers[key]!.text)
        : DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF3B82F6),
              onPrimary: Colors.white,
              surface: Color(0xFF1E293B),
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: const Color(0xFF0F172A),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _fieldValues[key] = DateFormat('yyyy-MM-dd').format(picked);
        _controllers[key]?.text = DateFormat('dd/MM/yyyy').format(picked);
      });
    }
  }

  Future<void> _pickTime(String key) async {
    final initialTime = _controllers[key]?.text.isNotEmpty == true
        ? _tryParseTime(_controllers[key]!.text)
        : TimeOfDay.now();

    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF3B82F6),
              onPrimary: Colors.white,
              surface: Color(0xFF1E293B),
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: const Color(0xFF0F172A),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final timeStr = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      setState(() {
        _fieldValues[key] = timeStr;
        _controllers[key]?.text = timeStr;
      });
    }
  }

  Future<void> _pickDateTime(String key) async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF3B82F6),
              surface: Color(0xFF1E293B),
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: const Color(0xFF0F172A),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null) {
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(now),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.dark(
                primary: Color(0xFF3B82F6),
                surface: Color(0xFF1E293B),
                onSurface: Colors.white,
              ),
              dialogBackgroundColor: const Color(0xFF0F172A),
            ),
            child: child!,
          );
        },
      );

      if (pickedTime != null) {
        final dateTime = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );
        setState(() {
          _fieldValues[key] = dateTime.toIso8601String();
          _controllers[key]?.text = DateFormat('dd/MM/yyyy HH:mm').format(dateTime);
        });
      }
    }
  }

  DateTime _tryParseDate(String text) {
    try {
      return DateFormat('dd/MM/yyyy').parse(text);
    } catch (_) {
      try {
        return DateTime.parse(text);
      } catch (_) {
        return DateTime.now();
      }
    }
  }

  TimeOfDay _tryParseTime(String text) {
    try {
      final parts = text.split(':');
      return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    } catch (_) {
      return TimeOfDay.now();
    }
  }

  Future<void> _save({bool andContinue = false}) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final deviceId = prefs.getString('device_id') ?? 'unknown';
      final auth = context.read<AuthService>();
      final userId = auth.currentUser?.id ?? 'usr-admin';

      final fields = widget.section?['fields'] as List? ?? [];
      final formData = <String, dynamic>{};

      for (var field in fields) {
        final key = field['key'] as String;
        final type = field['type'] as String;
        var value = _fieldValues[key];

        if (type == 'number' && value != null && value.toString().isNotEmpty) {
          value = double.tryParse(value.toString()) ?? value;
        }

        if (value != null && value.toString().isNotEmpty) {
          formData[key] = value;
        }

        if (type == 'text' && value != null && value.toString().isNotEmpty) {
          await SmartFormFieldHistory.saveValue(key, value.toString());
        }
      }

      final dateField = _findDateField(fields);
      final entryDate = formData[dateField]?.toString() ?? DateTime.now().toIso8601String().split('T')[0];

      if (widget.existingEntry != null) {
        final updated = FormEntry(
          id: widget.existingEntry!.id,
          module: widget.module,
          subModule: widget.sectionKey,
          date: entryDate,
          userId: userId,
          deviceId: deviceId,
          version: widget.existingEntry!.version + 1,
          data: formData,
          status: 'saved',
          createdAt: widget.existingEntry!.createdAt,
          updatedAt: DateTime.now().toUtc().toIso8601String(),
        );
        await _formRepo.saveEntry(updated);
      } else {
        await _formRepo.createEntry(
          module: widget.module,
          subModule: widget.sectionKey,
          date: entryDate,
          userId: userId,
          deviceId: deviceId,
          data: formData,
        );
      }

      if (mounted) {
        if (andContinue) {
          Navigator.pop(context, {'quickEntry': true, 'formData': formData});
        } else {
          Navigator.pop(context, {'quickEntry': false, 'formData': formData});
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Color(0xFF22C55E)),
                const SizedBox(width: 12),
                Text(andContinue ? 'Registro guardado. Continuando...' : 'Registro guardado exitosamente'),
              ],
            ),
            backgroundColor: const Color(0xFF1E293B),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: const Color(0xFF1E293B),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  String _findDateField(List fields) {
    final dateKeys = ['fecha', 'fecha_hora', 'fecha_prueba', 'fecha_servicio'];
    for (var key in dateKeys) {
      if (fields.any((f) => f['key'] == key)) return key;
    }
    return 'fecha';
  }

  List<Widget> _groupFields(List<Map<String, dynamic>> fields) {
    final groups = <String, List<Map<String, dynamic>>>{};
    final order = ['Informacion General', 'Lectura', 'Observaciones'];

    for (var field in fields) {
      final key = field['key'] as String;
      final multiline = field['multiline'] as bool? ?? false;

      String group;
      if (['fecha', 'hora', 'hora_inicio', 'hora_fin', 'usuario', 'operador', 'responsable', 'nombre', 'paciente'].contains(key)) {
        group = 'Informacion General';
      } else if (['temperatura', 'co2', 'presion', 'humedad', 'ph_obtenido', 'temp_inicial', 'temp_final', 'volumen', 'volumen_ml', 'pedido', 'ciclo_no'].contains(key)) {
        group = 'Lectura';
      } else if (multiline || ['observaciones', 'notas', 'actividad', 'equipos_usados', 'firma_responsable'].contains(key)) {
        group = 'Observaciones';
      } else {
        group = 'Informacion General';
      }

      groups.putIfAbsent(group, () => []);
      groups[group]!.add(field);
    }

    final widgets = <Widget>[];
    for (var groupName in order) {
      if (groups.containsKey(groupName) && groups[groupName]!.isNotEmpty) {
        IconData? icon;
        switch (groupName) {
          case 'Informacion General':
            icon = Icons.info_outline;
            break;
          case 'Lectura':
            icon = Icons.speed;
            break;
          case 'Observaciones':
            icon = Icons.note_alt_outlined;
            break;
          default:
            icon = Icons.folder;
        }

        widgets.add(
          SmartFormFieldGroup(
            title: groupName,
            icon: icon,
            accentColor: _getModuleColor(),
            children: groups[groupName]!.map((f) => _buildField(f)).toList(),
          ),
        );
      }
    }

    return widgets;
  }

  Widget _buildField(Map<String, dynamic> field) {
    final key = field['key'] as String;
    final label = field['label'] as String;
    final required = field['required'] as bool? ?? false;
    final type = field['type'] as String? ?? 'text';
    final unit = field['unit'] as String?;
    final multiline = field['multiline'] as bool? ?? false;
    final options = field['options'] as List?;

    switch (type) {
      case 'number':
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: SmartNumberField(
            fieldKey: key,
            label: label,
            required: required,
            unit: unit,
            controller: _controllers[key],
            focusNode: _focusNodes[key],
            onChanged: (v) => _fieldValues[key] = v,
          ),
        );
      case 'select':
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: SmartSelectField(
            fieldKey: key,
            label: label,
            options: options?.cast<String>() ?? [],
            required: required,
            initialValue: _fieldValues[key]?.toString(),
            onChanged: (v) => setState(() => _fieldValues[key] = v ?? ''),
          ),
        );
      case 'date':
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: SmartDateField(
            fieldKey: key,
            label: label,
            required: required,
            onChanged: (v) => setState(() => _fieldValues[key] = v),
          ),
        );
      case 'time':
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: SmartTimeField(
            fieldKey: key,
            label: label,
            required: required,
            onChanged: (v) => setState(() => _fieldValues[key] = v),
          ),
        );
      case 'datetime':
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () => _pickDateTime(key),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white.withOpacity(0.1)),
                borderRadius: BorderRadius.circular(12),
                color: const Color(0xFF0F172A),
              ),
              child: Row(
                children: [
                  const Icon(Icons.event_note, color: Colors.white54, size: 18),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _controllers[key]?.text.isEmpty == true ? label : _controllers[key]!.text,
                      style: TextStyle(
                        color: _controllers[key]?.text.isEmpty == true ? Colors.white54 : Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      default:
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: SmartTextField(
            fieldKey: key,
            label: label,
            required: required,
            multiline: multiline,
            controller: _controllers[key],
            focusNode: _focusNodes[key],
            onChanged: (v) => _fieldValues[key] = v,
          ),
        );
    }
  }

  IconData _getModuleIcon() {
    final mod = findModule(widget.module);
    final iconStr = mod['icon'] as String?;
    switch (iconStr) {
      case 'thermostat': return Icons.thermostat;
      case 'local_fire_department': return Icons.local_fire_department;
      case 'ac_unit': return Icons.ac_unit;
      case 'precision_manufacturing': return Icons.precision_manufacturing;
      case 'biotech': return Icons.biotech;
      case 'book': return Icons.book;
      default: return Icons.folder;
    }
  }

  Color _getModuleColor() {
    final mod = findModule(widget.module);
    final colorStr = mod['color'] as String?;
    if (colorStr != null) {
      try {
        return Color(int.parse(colorStr));
      } catch (_) {}
    }
    return const Color(0xFF3B82F6);
  }

  @override
  Widget build(BuildContext context) {
    final fields = widget.section?['fields'] as List? ?? [];
    final sectionLabel = widget.section?['label'] as String? ?? widget.moduleLabel;
    final moduleColor = _getModuleColor();

    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_getModuleIcon(), color: moduleColor, size: 20),
                const SizedBox(width: 8),
                Text(widget.moduleLabel),
              ],
            ),
            Text(
              sectionLabel,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal, color: Colors.white.withOpacity(0.5)),
            ),
          ],
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (widget.existingEntry == null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton.icon(
                onPressed: () {
                  setState(() => _quickEntryMode = !_quickEntryMode);
                },
                icon: Icon(
                  _quickEntryMode ? Icons.toggle_on : Icons.toggle_off,
                  color: _quickEntryMode ? const Color(0xFF22C55E) : Colors.white38,
                ),
                label: Text(
                  'Entrada rapida',
                  style: TextStyle(
                    color: _quickEntryMode ? const Color(0xFF22C55E) : Colors.white54,
                    fontSize: 12,
                  ),
                ),
              ),
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
        child: _saving
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF3B82F6)))
            : Form(
                key: _formKey,
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_quickEntryMode)
                              Container(
                                width: double.infinity,
                                margin: const EdgeInsets.only(bottom: 16),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF22C55E).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFF22C55E).withOpacity(0.3)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.fast_forward, color: Color(0xFF22C55E), size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Modo entrada rapida: despues de guardar, el formulario se mantendra abierto con los campos prellenados',
                                        style: const TextStyle(color: Color(0xFF22C55E), fontSize: 12),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ..._groupFields(fields.map((f) => f as Map<String, dynamic>).toList()),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.06))),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(48),
                                side: BorderSide(color: Colors.white.withOpacity(0.15)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('Cancelar', style: TextStyle(color: Colors.white70)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              onPressed: () => _save(andContinue: _quickEntryMode),
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size.fromHeight(48),
                                backgroundColor: moduleColor,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.save, color: Colors.white, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    widget.existingEntry != null ? 'Actualizar' : (_quickEntryMode ? 'Guardar y Continuar' : 'Guardar Registro'),
                                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
