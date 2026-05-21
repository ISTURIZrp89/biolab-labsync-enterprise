class User {
  final String id;
  final String nombre;
  final String cargo;
  final String rol;
  final bool activo;

  User({
    required this.id,
    required this.nombre,
    this.cargo = '',
    required this.rol,
    this.activo = true,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? '',
      nombre: json['nombre'] ?? '',
      cargo: json['cargo'] ?? '',
      rol: json['rol'] ?? '',
      activo: json['activo'] ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'nombre': nombre,
    'cargo': cargo,
    'rol': rol,
    'activo': activo,
  };
}
