class DayClosure {
  final String id;
  final String date;
  final String status;
  final String closedBy;
  final String closedAt;
  final String notes;
  final List<Map<String, dynamic>> reopenLog;

  DayClosure({
    required this.id,
    required this.date,
    required this.status,
    required this.closedBy,
    String? closedAt,
    this.notes = '',
    List<Map<String, dynamic>>? reopenLog,
  })  : closedAt = closedAt ?? DateTime.now().toUtc().toIso8601String(),
        reopenLog = reopenLog ?? [];

  factory DayClosure.fromJson(Map<String, dynamic> json) {
    return DayClosure(
      id: json['id'] ?? '',
      date: json['date'] ?? '',
      status: json['status'] ?? 'ABIERTO',
      closedBy: json['closed_by'] ?? '',
      closedAt: json['closed_at'],
      notes: json['notes'] ?? '',
      reopenLog: (json['reopen_log'] as List?)?.cast<Map<String, dynamic>>(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date,
    'status': status,
    'closed_by': closedBy,
    'closed_at': closedAt,
    'notes': notes,
    'reopen_log': reopenLog,
  };
}
