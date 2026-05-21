class SyncQueueItem {
  final String id;
  final String action;
  final String entity;
  final String entityId;
  final Map<String, dynamic> data;
  final String timestamp;

  SyncQueueItem({
    required this.id,
    required this.action,
    required this.entity,
    required this.entityId,
    required this.data,
    String? timestamp,
  }) : timestamp = timestamp ?? DateTime.now().toUtc().toIso8601String();

  factory SyncQueueItem.fromMap(Map<String, dynamic> map) {
    return SyncQueueItem(
      id: map['id'] ?? '',
      action: map['action'] ?? '',
      entity: map['entity'] ?? '',
      entityId: map['entity_id'] ?? '',
      data: map['data'] is Map ? map['data'] as Map<String, dynamic> : {},
      timestamp: map['timestamp'],
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'action': action,
    'entity': entity,
    'entity_id': entityId,
    'data_json': data.toString(),
    'timestamp': timestamp,
  };
}
