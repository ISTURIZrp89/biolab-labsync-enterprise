class User {
  final String id;
  final String nombre;
  final String cargo;
  final String cargoOperativo;
  final String rol;
  final String area;
  final String supervisor;
  final String firma;
  final bool activo;

  User({
    required this.id,
    required this.nombre,
    this.cargo = '',
    this.cargoOperativo = '',
    required this.rol,
    this.area = '',
    this.supervisor = '',
    this.firma = '',
    this.activo = true,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? '',
      nombre: json['nombre'] ?? '',
      cargo: json['cargo'] ?? '',
      cargoOperativo: json['cargo_operativo'] ?? json['cargoOperativo'] ?? '',
      rol: json['rol'] ?? '',
      area: json['area'] ?? '',
      supervisor: json['supervisor'] ?? '',
      firma: json['firma'] ?? '',
      activo: json['activo'] ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'nombre': nombre,
    'cargo': cargo,
    'cargo_operativo': cargoOperativo,
    'rol': rol,
    'area': area,
    'supervisor': supervisor,
    'firma': firma,
    'activo': activo,
  };
}
