class User {
  final String id;
  final String email;
  final String nombre;
  final String role;
  final bool activo;

  const User({
    required this.id,
    required this.email,
    required this.nombre,
    required this.role,
    this.activo = true,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      email: json['email'] as String,
      nombre: json['nombre'] as String,
      role: json['role'] as String,
      activo: json['activo'] as bool? ?? true,
    );
  }
}
