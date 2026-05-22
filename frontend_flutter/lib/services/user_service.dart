import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../security/auth_service.dart';

class UserSession {
  final String nombre;
  final String cargo;
  final String cargoOperativo;
  final String area;
  final String supervisor;
  final String firma;
  final String rol;

  UserSession({
    required this.nombre,
    this.cargo = '',
    this.cargoOperativo = '',
    this.area = '',
    this.supervisor = '',
    this.firma = '',
    this.rol = '',
  });

  Map<String, String> toAutofill() => {
    'responsable': nombre,
    'usuario': nombre,
    'nombre': nombre,
    'operador': nombre,
    'elaborado_por': nombre,
    'cargo': cargoOperativo.isNotEmpty ? cargoOperativo : cargo,
    'cargo_operativo': cargoOperativo,
    'area': area,
    'supervisor': supervisor,
    'firma_responsable': firma.isNotEmpty ? firma : nombre,
    'firma': firma.isNotEmpty ? firma : nombre,
    'turno': _detectTurno(),
    'rol': rol,
  };

  String _detectTurno() {
    final h = DateTime.now().hour;
    if (h < 14) return 'MATUTINO';
    if (h < 22) return 'VESPERTINO';
    return 'NOCTURNO';
  }
}

class UserService extends ChangeNotifier {
  UserSession? _session;

  UserSession? get session => _session;

  void loadFromAuth(AuthService auth) {
    final user = auth.currentUser;
    if (user == null) {
      _session = null;
      notifyListeners();
      return;
    }
    _loadFromPrefs(user.nombre, user.cargo, user.cargoOperativo, user.rol);
  }

  Future<void> _loadFromPrefs(String nombre, String cargo, String cargoOperativo, String rol) async {
    final prefs = await SharedPreferences.getInstance();
    final area = prefs.getString('user_area') ?? 'Cultivo Celular';
    final supervisor = prefs.getString('user_supervisor') ?? '';
    final firma = prefs.getString('user_firma') ?? nombre;
    _session = UserSession(
      nombre: nombre,
      cargo: cargo,
      cargoOperativo: cargoOperativo,
      area: area,
      supervisor: supervisor,
      firma: firma,
      rol: rol,
    );
    notifyListeners();
  }

  Future<void> updateArea(String area) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_area', area);
    if (_session != null) {
      _session = UserSession(
        nombre: _session!.nombre,
        cargo: _session!.cargo,
        cargoOperativo: _session!.cargoOperativo,
        area: area,
        supervisor: _session!.supervisor,
        firma: _session!.firma,
        rol: _session!.rol,
      );
      notifyListeners();
    }
  }

  Future<void> updateSupervisor(String supervisor) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_supervisor', supervisor);
    if (_session != null) {
      _session = UserSession(
        nombre: _session!.nombre,
        cargo: _session!.cargo,
        cargoOperativo: _session!.cargoOperativo,
        area: _session!.area,
        supervisor: supervisor,
        firma: _session!.firma,
        rol: _session!.rol,
      );
      notifyListeners();
    }
  }

  Future<void> updateFirma(String firma) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_firma', firma);
    if (_session != null) {
      _session = UserSession(
        nombre: _session!.nombre,
        cargo: _session!.cargo,
        cargoOperativo: _session!.cargoOperativo,
        area: _session!.area,
        supervisor: _session!.supervisor,
        firma: firma,
        rol: _session!.rol,
      );
      notifyListeners();
    }
  }

  Map<String, String> getAutofill() => _session?.toAutofill() ?? {};
}
