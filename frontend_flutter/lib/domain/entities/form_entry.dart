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

  FormEntry({
    required this.id,
    required this.module,
    this.subModule,
    required this.date,
    required this.userId,
    required this.deviceId,
    this.version = 1,
    required this.data,
    this.status = 'saved',
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
      status: json['status'] ?? 'saved',
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
