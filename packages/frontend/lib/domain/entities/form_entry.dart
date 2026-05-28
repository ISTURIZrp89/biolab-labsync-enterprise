class FormEntry {
  final String id;
  final String module;
  final String date;
  final String userId;
  final String deviceId;
  final int version;
  final Map<String, dynamic> data;
  final String status;

  const FormEntry({
    required this.id,
    required this.module,
    required this.date,
    this.userId = '',
    this.deviceId = '',
    this.version = 1,
    this.data = const {},
    this.status = 'saved',
  });

  factory FormEntry.fromJson(Map<String, dynamic> json) {
    return FormEntry(
      id: json['id'] as String,
      module: json['module'] as String,
      date: json['date'] as String,
      userId: json['user_id'] as String? ?? '',
      deviceId: json['device_id'] as String? ?? '',
      version: json['version'] as int? ?? 1,
      data: json['data'] as Map<String, dynamic>? ?? {},
      status: json['status'] as String? ?? 'saved',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'module': module,
        'date': date,
        'user_id': userId,
        'device_id': deviceId,
        'version': version,
        'data': data,
        'status': status,
      };
}
