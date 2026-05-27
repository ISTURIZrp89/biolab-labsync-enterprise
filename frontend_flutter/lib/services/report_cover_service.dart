import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../data/db.dart';
import '../domain/entities/user.dart';

class ReportPersonnel {
  final String id;
  final int year;
  final int month;
  final String userId;
  String nombre;
  String cargo;
  String area;
  bool activo;
  final String createdAt;

  ReportPersonnel({
    required this.id,
    required this.year,
    required this.month,
    required this.userId,
    required this.nombre,
    this.cargo = '',
    this.area = '',
    this.activo = true,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id, 'year': year, 'month': month, 'user_id': userId,
    'nombre': nombre, 'cargo': cargo, 'area': area,
    'activo': activo ? 1 : 0, 'created_at': createdAt,
  };

  static ReportPersonnel fromMap(Map<String, dynamic> m) => ReportPersonnel(
    id: m['id'] as String, year: m['year'] as int, month: m['month'] as int,
    userId: m['user_id'] as String, nombre: m['nombre'] as String,
    cargo: m['cargo'] as String? ?? '', area: m['area'] as String? ?? '',
    activo: (m['activo'] as int? ?? 1) == 1,
    createdAt: m['created_at'] as String,
  );
}

class ReportCoverData {
  final int year;
  final int month;
  String title;
  String subtitle;
  String notes;

  ReportCoverData({
    required this.year, required this.month,
    this.title = '', this.subtitle = '', this.notes = '',
  });
}

class ReportCoverService extends ChangeNotifier {
  List<ReportPersonnel> _personnel = [];
  ReportCoverData? _coverData;
  bool _loading = false;
  String? _error;

  List<ReportPersonnel> get personnel => _personnel.where((p) => p.activo).toList();
  List<ReportPersonnel> get allPersonnel => _personnel;
  ReportCoverData? get coverData => _coverData;
  bool get loading => _loading;
  String? get error => _error;

  static List<Map<String, dynamic>> _getRegisteredUsers() {
    try {
      final prefs = SharedPreferences.getInstance() as Future<SharedPreferences>?;
      return []; // Will be loaded async
    } catch (_) {
      return [];
    }
  }

  Future<void> loadForMonth(int year, int month) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final db = await LocalDatabase.instance.database;

      final rows = await db.query('report_personnel',
        where: 'year = ? AND month = ?', whereArgs: [year, month]);
      _personnel = rows.map(ReportPersonnel.fromMap).toList();

      final coverRows = await db.query('report_covers',
        where: 'year = ? AND month = ?', whereArgs: [year, month]);
      if (coverRows.isNotEmpty) {
        _coverData = ReportCoverData(
          year: year, month: month,
          title: coverRows.first['title'] as String? ?? '',
          subtitle: coverRows.first['subtitle'] as String? ?? '',
          notes: coverRows.first['notes'] as String? ?? '',
        );
      } else {
        _coverData = ReportCoverData(year: year, month: month);
      }

      if (_personnel.isEmpty) {
        await _autoPopulateFromUsers(year, month);
      }
    } catch (e) {
      _error = 'Error al cargar personal: $e';
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> _autoPopulateFromUsers(int year, int month) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList('users_list') ?? [];
      final db = await LocalDatabase.instance.database;
      final now = DateTime.now().toIso8601String();
      final uuid = const Uuid();

      for (final json in raw) {
        try {
          final u = jsonDecode(json) as Map<String, dynamic>;
          final userId = u['id']?.toString() ?? uuid.v4();
          final nombre = u['nombre']?.toString() ?? '';
          if (nombre.isEmpty) continue;
          final cargoOperativo = u['cargo_operativo']?.toString() ?? u['cargo']?.toString() ?? '';
          final area = u['area']?.toString() ?? '';

          final rp = ReportPersonnel(
            id: uuid.v4(), year: year, month: month,
            userId: userId, nombre: nombre,
            cargo: cargoOperativo, area: area,
            createdAt: now,
          );
          await db.insert('report_personnel', rp.toMap());
          _personnel.add(rp);
        } catch (_) {}
      }
    } catch (_) {}
  }

  Future<void> addPersonnel(String nombre, String cargo, String area) async {
    if (_coverData == null || nombre.isEmpty) return;
    final now = DateTime.now().toIso8601String();
    final rp = ReportPersonnel(
      id: const Uuid().v4(), year: _coverData!.year, month: _coverData!.month,
      userId: const Uuid().v4(), nombre: nombre, cargo: cargo, area: area,
      createdAt: now,
    );
    try {
      final db = await LocalDatabase.instance.database;
      await db.insert('report_personnel', rp.toMap());
      _personnel.add(rp);
      notifyListeners();
    } catch (e) {
      _error = 'Error al agregar: $e';
      notifyListeners();
    }
  }

  Future<void> updatePersonnel(String id, {String? nombre, String? cargo, String? area, bool? activo}) async {
    try {
      final db = await LocalDatabase.instance.database;
      final updates = <String, dynamic>{};
      if (nombre != null) updates['nombre'] = nombre;
      if (cargo != null) updates['cargo'] = cargo;
      if (area != null) updates['area'] = area;
      if (activo != null) updates['activo'] = activo ? 1 : 0;
      if (updates.isNotEmpty) {
        await db.update('report_personnel', updates,
          where: 'id = ?', whereArgs: [id]);
        final idx = _personnel.indexWhere((p) => p.id == id);
        if (idx >= 0) {
          if (nombre != null) _personnel[idx].nombre = nombre;
          if (cargo != null) _personnel[idx].cargo = cargo;
          if (area != null) _personnel[idx].area = area;
          if (activo != null) _personnel[idx].activo = activo;
        }
        notifyListeners();
      }
    } catch (e) {
      _error = 'Error al actualizar: $e';
      notifyListeners();
    }
  }

  Future<void> removePersonnel(String id) async {
    try {
      final db = await LocalDatabase.instance.database;
      await db.delete('report_personnel', where: 'id = ?', whereArgs: [id]);
      _personnel.removeWhere((p) => p.id == id);
      notifyListeners();
    } catch (e) {
      _error = 'Error al eliminar: $e';
      notifyListeners();
    }
  }

  Future<void> saveCoverData(String title, String subtitle, String notes) async {
    if (_coverData == null) return;
    _coverData!.title = title;
    _coverData!.subtitle = subtitle;
    _coverData!.notes = notes;
    final now = DateTime.now().toIso8601String();
    try {
      final db = await LocalDatabase.instance.database;
      final existing = await db.query('report_covers',
        where: 'year = ? AND month = ?',
        whereArgs: [_coverData!.year, _coverData!.month]);
      if (existing.isNotEmpty) {
        await db.update('report_covers',
          {'title': title, 'subtitle': subtitle, 'notes': notes, 'updated_at': now},
          where: 'year = ? AND month = ?',
          whereArgs: [_coverData!.year, _coverData!.month]);
      } else {
        await db.insert('report_covers', {
          'id': const Uuid().v4(),
          'year': _coverData!.year, 'month': _coverData!.month,
          'title': title, 'subtitle': subtitle, 'notes': notes,
          'created_at': now, 'updated_at': now,
        });
      }
      notifyListeners();
    } catch (e) {
      _error = 'Error al guardar portada: $e';
      notifyListeners();
    }
  }

  String generateCoverPreview() {
    if (_coverData == null) return '';
    final monthNames = ['', 'ENERO', 'FEBRERO', 'MARZO', 'ABRIL', 'MAYO', 'JUNIO',
      'JULIO', 'AGOSTO', 'SEPTIEMBRE', 'OCTUBRE', 'NOVIEMBRE', 'DICIEMBRE'];
    final active = _personnel.where((p) => p.activo).toList();
    final buf = StringBuffer();
    buf.writeln('═══════════════════════════════════════════');
    buf.writeln('  ${_coverData!.title.isNotEmpty ? _coverData!.title : 'BIOLAB LABSYNC'}');
    buf.writeln('  ${_coverData!.subtitle.isNotEmpty ? _coverData!.subtitle : monthNames[_coverData!.month]} ${_coverData!.year}');
    buf.writeln('═══════════════════════════════════════════');
    buf.writeln('');
    buf.writeln('  PERIODO: ${monthNames[_coverData!.month]} ${_coverData!.year}');
    buf.writeln('  PERSONAL RESPONSABLE:');
    for (final p in active) {
      buf.writeln('    - ${p.nombre}${p.cargo.isNotEmpty ? ' (${p.cargo})' : ''}');
    }
    if (_coverData!.notes.isNotEmpty) {
      buf.writeln('');
      buf.writeln('  NOTAS: ${_coverData!.notes}');
    }
    buf.writeln('');
    buf.writeln('═══════════════════════════════════════════');
    return buf.toString();
  }
}