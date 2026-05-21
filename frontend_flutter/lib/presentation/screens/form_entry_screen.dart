import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/repositories/form_repository_impl.dart';
import '../../domain/entities/form_entry.dart';
import '../../domain/form_definitions.dart';
import '../../security/auth_service.dart';
import '../../sync/sync_engine.dart';

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

  Future<void> _openForm({FormEntry? existing}) async {
    final section = findSection(widget.module, _selectedSection ?? '');
    if (section == null && (_moduleDef['sections'] as List?)?.isEmpty == true) {
      return;
    }

    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => _FormBuilderScreen(
          module: widget.module,
          moduleLabel: widget.moduleLabel,
          sectionKey: _selectedSection,
          section: section,
          existingEntry: existing,
        ),
      ),
    );

    if (result != null) {
      _loadEntries();
    }
  }

  Future<void> _syncNow() async {
    if (!mounted) return;
    final syncEngine = context.read<SyncEngine>();
    final success = await syncEngine.synchronize();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success
              ? 'Sincronizacion completada'
              : 'Error al sincronizar. Datos guardados localmente'),
          backgroundColor: success ? Colors.green.shade800 : Colors.orange.shade800,
        ),
      );
      if (success) _loadEntries();
    }
  }

  void _showEntryDetails(FormEntry entry) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF001830),
        title: Text(
          _getSectionLabel(entry.subModule),
          style: const TextStyle(color: Colors.white),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _detailRow('Fecha', _formatDate(entry.date)),
                _detailRow('Usuario', entry.data['usuario'] ?? entry.data['nombre'] ?? '-'),
                const Divider(color: Colors.white24),
                ...entry.data.entries.map((e) => _detailRow(_formatKey(e.key), _formatValue(e.value))),
                const Divider(color: Colors.white24),
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
            child: const Text('Cerrar', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _openForm(existing: entry);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF004A99)),
            child: const Text('Editar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
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
      return DateFormat('dd/MM/yyyy', 'es').format(date);
    } catch (_) {
      return dateStr;
    }
  }

  String _formatDateTime(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd/MM/yyyy HH:mm', 'es').format(date.toLocal());
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
    final priorityKeys = ['equipo', 'modelo', 'nombre', 'paciente', 'contenido', 'producto'];
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
    return const Color(0xFF004A99);
  }

  @override
  Widget build(BuildContext context) {
    final sections = _moduleDef['sections'] as List? ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(_getModuleIcon(), color: _getModuleColor(), size: 24),
            const SizedBox(width: 8),
            Text(widget.moduleLabel),
          ],
        ),
        backgroundColor: const Color(0xFF004A99),
        foregroundColor: Colors.white,
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
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    sync.isOnline ? Icons.wifi : Icons.wifi_off,
                    color: sync.isOnline ? Colors.greenAccent : Colors.redAccent,
                    size: 18,
                  ),
                  if (sync.isSyncing)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: _syncNow,
            tooltip: 'Sincronizar ahora',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadEntries,
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF004A99)))
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
            color: Colors.white.withOpacity(0.15),
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

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          color: const Color(0xFF001830),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _getModuleColor().withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(_getModuleIcon(), color: _getModuleColor(), size: 22),
            ),
            title: Text(
              summary,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 14),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  dateStr,
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                ),
                if (entry.subModule != null)
                  Text(
                    _getSectionLabel(entry.subModule),
                    style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11),
                  ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getStatusBgColor(entry.status),
                    borderRadius: BorderRadius.circular(4),
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
                  icon: const Icon(Icons.visibility_outlined, color: Colors.white54, size: 20),
                  onPressed: () => _showEntryDetails(entry),
                  tooltip: 'Ver detalles',
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, color: Colors.white54, size: 20),
                  onPressed: () => _openForm(existing: entry),
                  tooltip: 'Editar',
                ),
              ],
            ),
            onTap: () => _showEntryDetails(entry),
          ),
        );
      },
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'saved': return Colors.greenAccent;
      case 'synced': return Colors.blueAccent;
      case 'pending': return Colors.orangeAccent;
      default: return Colors.white54;
    }
  }

  Color _getStatusBgColor(String status) {
    switch (status.toLowerCase()) {
      case 'saved': return Colors.green.withOpacity(0.15);
      case 'synced': return Colors.blue.withOpacity(0.15);
      case 'pending': return Colors.orange.withOpacity(0.15);
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

  const _FormBuilderScreen({
    required this.module,
    required this.moduleLabel,
    this.sectionKey,
    this.section,
    this.existingEntry,
  });

  @override
  State<_FormBuilderScreen> createState() => _FormBuilderScreenState();
}

class _FormBuilderScreenState extends State<_FormBuilderScreen> {
  final FormRepositoryImpl _formRepo = FormRepositoryImpl();
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, dynamic> _fieldValues = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _initFields();
  }

  void _initFields() {
    final fields = widget.section?['fields'] as List? ?? [];
    final existingData = widget.existingEntry?.data ?? {};

    for (var field in fields) {
      final key = field['key'] as String;
      final type = field['type'] as String;
      final initial = existingData[key];

      if (type == 'select') {
        _fieldValues[key] = initial?.toString() ?? '';
      } else if (type == 'date' || type == 'time' || type == 'datetime') {
        _fieldValues[key] = initial?.toString() ?? '';
        _controllers[key] = TextEditingController(text: _formatInitialValue(type, initial));
      } else {
        _fieldValues[key] = initial?.toString() ?? (field['initial']?.toString() ?? '');
        _controllers[key] = TextEditingController(text: _fieldValues[key].toString());
      }
    }
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
              primary: Color(0xFF004A99),
              onPrimary: Colors.white,
              surface: Color(0xFF001830),
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: const Color(0xFF001020),
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
              primary: Color(0xFF004A99),
              onPrimary: Colors.white,
              surface: Color(0xFF001830),
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: const Color(0xFF001020),
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
              primary: Color(0xFF004A99),
              surface: Color(0xFF001830),
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: const Color(0xFF001020),
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
                primary: Color(0xFF004A99),
                surface: Color(0xFF001830),
                onSurface: Colors.white,
              ),
              dialogBackgroundColor: const Color(0xFF001020),
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

  Future<void> _save() async {
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
        Navigator.pop(context, formData);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.greenAccent),
                const SizedBox(width: 12),
                const Text('Registro guardado exitosamente'),
              ],
            ),
            backgroundColor: const Color(0xFF001830),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red.shade800,
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

  Widget _buildField(Map<String, dynamic> field) {
    final key = field['key'] as String;
    final label = field['label'] as String;
    final required = field['required'] as bool? ?? false;
    final type = field['type'] as String? ?? 'text';
    final unit = field['unit'] as String?;
    final multiline = field['multiline'] as bool? ?? false;

    switch (type) {
      case 'number':
        return _buildNumberField(key, label, required, unit);
      case 'select':
        return _buildSelectField(key, label, field['options'] as List?, required);
      case 'date':
        return _buildDateField(key, label, required);
      case 'time':
        return _buildTimeField(key, label, required);
      case 'datetime':
        return _buildDateTimeField(key, label, required);
      default:
        return _buildTextField(key, label, required, multiline);
    }
  }

  Widget _buildTextField(String key, String label, bool required, bool multiline) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: _controllers[key],
        maxLines: multiline ? 3 : 1,
        minLines: multiline ? 2 : 1,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white54),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.15)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF004A99), width: 2),
          ),
          filled: true,
          fillColor: const Color(0xFF001830),
        ),
        style: const TextStyle(color: Colors.white),
        validator: required
            ? (v) => (v == null || v.isEmpty) ? '$label es requerido' : null
            : null,
        onChanged: (v) => _fieldValues[key] = v,
      ),
    );
  }

  Widget _buildNumberField(String key, String label, bool required, String? unit) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: _controllers[key],
        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white54),
          suffixText: unit,
          suffixStyle: const TextStyle(color: Colors.white54),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.15)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF004A99), width: 2),
          ),
          filled: true,
          fillColor: const Color(0xFF001830),
        ),
        style: const TextStyle(color: Colors.white),
        validator: required
            ? (v) => (v == null || v.isEmpty) ? '$label es requerido' : null
            : null,
        onChanged: (v) => _fieldValues[key] = v,
      ),
    );
  }

  Widget _buildSelectField(String key, String label, List? options, bool required) {
    final opts = options?.cast<String>() ?? [];
    final currentValue = _fieldValues[key]?.toString() ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        value: currentValue.isNotEmpty ? currentValue : null,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white54),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.15)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF004A99), width: 2),
          ),
          filled: true,
          fillColor: const Color(0xFF001830),
        ),
        dropdownColor: const Color(0xFF001830),
        style: const TextStyle(color: Colors.white),
        items: opts.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
        onChanged: (v) => setState(() => _fieldValues[key] = v ?? ''),
        validator: required
            ? (v) => (v == null || v.isEmpty) ? '$label es requerido' : null
            : null,
      ),
    );
  }

  Widget _buildDateField(String key, String label, bool required) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () => _pickDate(key),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white.withOpacity(0.15)),
            borderRadius: BorderRadius.circular(8),
            color: const Color(0xFF001830),
          ),
          child: Row(
            children: [
              const Icon(Icons.calendar_today, color: Colors.white54, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _controllers[key]?.text.isEmpty == true ? label : _controllers[key]!.text,
                  style: TextStyle(
                    color: _controllers[key]?.text.isEmpty == true ? Colors.white54 : Colors.white,
                    fontSize: 16,
                  ),
                ),
              ),
              if (required)
                const Text('*', style: TextStyle(color: Colors.red, fontSize: 16)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeField(String key, String label, bool required) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () => _pickTime(key),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white.withOpacity(0.15)),
            borderRadius: BorderRadius.circular(8),
            color: const Color(0xFF001830),
          ),
          child: Row(
            children: [
              const Icon(Icons.access_time, color: Colors.white54, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _controllers[key]?.text.isEmpty == true ? label : _controllers[key]!.text,
                  style: TextStyle(
                    color: _controllers[key]?.text.isEmpty == true ? Colors.white54 : Colors.white,
                    fontSize: 16,
                  ),
                ),
              ),
              if (required)
                const Text('*', style: TextStyle(color: Colors.red, fontSize: 16)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateTimeField(String key, String label, bool required) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () => _pickDateTime(key),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white.withOpacity(0.15)),
            borderRadius: BorderRadius.circular(8),
            color: const Color(0xFF001830),
          ),
          child: Row(
            children: [
              const Icon(Icons.event_note, color: Colors.white54, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _controllers[key]?.text.isEmpty == true ? label : _controllers[key]!.text,
                  style: TextStyle(
                    color: _controllers[key]?.text.isEmpty == true ? Colors.white54 : Colors.white,
                    fontSize: 16,
                  ),
                ),
              ),
              if (required)
                const Text('*', style: TextStyle(color: Colors.red, fontSize: 16)),
            ],
          ),
        ),
      ),
    );
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
    return const Color(0xFF004A99);
  }

  @override
  Widget build(BuildContext context) {
    final fields = widget.section?['fields'] as List? ?? [];
    final sectionLabel = widget.section?['label'] as String? ?? widget.moduleLabel;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.moduleLabel),
            Text(
              sectionLabel,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal, color: Colors.white70),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF004A99),
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF001020), Color(0xFF000810)],
          ),
        ),
        child: _saving
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF004A99)))
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
                            Row(
                              children: [
                                Icon(_getModuleIcon(), color: _getModuleColor(), size: 24),
                                const SizedBox(width: 8),
                                Text(
                                  sectionLabel,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Complete los campos requeridos',
                              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
                            ),
                            const SizedBox(height: 24),
                            ...fields.map((f) => _buildField(f as Map<String, dynamic>)),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF001020),
                        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(48),
                                side: BorderSide(color: Colors.white.withOpacity(0.2)),
                              ),
                              child: const Text('Cancelar', style: TextStyle(color: Colors.white70)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              onPressed: _save,
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size.fromHeight(48),
                                backgroundColor: _getModuleColor(),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.save, color: Colors.white, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    widget.existingEntry != null ? 'Actualizar' : 'Guardar Registro',
                                    style: const TextStyle(color: Colors.white, fontSize: 15),
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
