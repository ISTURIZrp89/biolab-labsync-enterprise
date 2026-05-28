class User {
  final String id;
  final String nombre;
  final String email;
  final String rol;
  final String? cargo;
  final String? cargoOperativo;
  final String? area;
  final String? supervisor;
  final String? firma;
  final bool activo;

  const User({
    required this.id,
    required this.nombre,
    this.email = '',
    required this.rol,
    this.cargo,
    this.cargoOperativo,
    this.area,
    this.supervisor,
    this.firma,
    this.activo = true,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      nombre: json['nombre'] as String,
      email: json['email'] as String? ?? '',
      rol: json['rol'] as String,
      cargo: json['cargo'] as String?,
      cargoOperativo: json['cargo_operativo'] as String?,
      area: json['area'] as String?,
      supervisor: json['supervisor'] as String?,
      firma: json['firma'] as String?,
      activo: json['activo'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre': nombre,
        'email': email,
        'rol': rol,
        'cargo': cargo,
        'cargo_operativo': cargoOperativo,
        'area': area,
        'supervisor': supervisor,
        'firma': firma,
        'activo': activo,
      };
}
