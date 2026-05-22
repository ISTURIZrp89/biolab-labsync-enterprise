class FormEntry {
  final String id;
  final String module;
  final String? subModule;
  final String date;
  final String userId;
  final String deviceId;
  final int version;
  final Map<String, dynamic> data;
  final String status;
  final String createdAt;
  final String updatedAt;

  static const String statusBorrador = 'borrador';
  static const String statusPendiente = 'pendiente';
  static const String statusCompletado = 'completado';
  static const String statusRevisado = 'revisado';
  static const String statusCorregido = 'corregido';
  static const String statusCerrado = 'cerrado';
  static const String statusReabierto = 'reabierto';
  static const String statusJustificado = 'justificado';
  static const String statusCancelado = 'cancelado';

  static const List<String> allStatuses = [
    statusBorrador,
    statusPendiente,
    statusCompletado,
    statusRevisado,
    statusCorregido,
    statusCerrado,
    statusReabierto,
    statusJustificado,
    statusCancelado,
  ];

  static const Map<String, int> statusWeight = {
    statusBorrador: 0,
    statusPendiente: 1,
    statusCompletado: 2,
    statusRevisado: 3,
    statusCorregido: 4,
    statusCerrado: 5,
    statusReabierto: 6,
    statusJustificado: 7,
    statusCancelado: 8,
  };

  static String statusLabel(String s) {
    switch (s) {
      case statusBorrador: return 'Borrador';
      case statusPendiente: return 'Pendiente';
      case statusCompletado: return 'Completado';
      case statusRevisado: return 'Revisado';
      case statusCorregido: return 'Corregido';
      case statusCerrado: return 'Cerrado';
      case statusReabierto: return 'Reabierto';
      case statusJustificado: return 'Justificado';
      case statusCancelado: return 'Cancelado';
      default: return s;
    }
  }

  static String nextStatus(String current) {
    final weight = statusWeight[current] ?? 0;
    for (final entry in statusWeight.entries) {
      if (entry.value == weight + 1) return entry.key;
    }
    return current;
  }

  FormEntry({
    required this.id,
    required this.module,
    this.subModule,
    required this.date,
    required this.userId,
    required this.deviceId,
    this.version = 1,
    required this.data,
    this.status = statusCompletado,
    String? createdAt,
    String? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now().toUtc().toIso8601String(),
        updatedAt = updatedAt ?? DateTime.now().toUtc().toIso8601String();

  factory FormEntry.fromJson(Map<String, dynamic> json) {
    return FormEntry(
      id: json['id'] ?? '',
      module: json['module'] ?? '',
      subModule: json['sub_module'],
      date: json['date'] ?? '',
      userId: json['user_id'] ?? '',
      deviceId: json['device_id'] ?? '',
      version: json['version'] ?? 1,
      data: json['data'] is Map ? json['data'] : {},
      status: json['status'] ?? statusCompletado,
      createdAt: json['created_at'],
      updatedAt: json['updated_at'],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'module': module,
    'sub_module': subModule,
    'date': date,
    'user_id': userId,
    'device_id': deviceId,
    'version': version,
    'data': data,
    'status': status,
    'created_at': createdAt,
    'updated_at': updatedAt,
  };
}
