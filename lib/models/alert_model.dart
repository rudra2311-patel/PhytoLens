class Alert {
  final int? id;
  final String type; // 'weather', 'disease', 'action'
  final String severity; // 'high', 'medium', 'low'
  final String title;
  final String message;
  final int? farmId;
  final String? farmName;
  final String? userId; // User ID for data isolation
  final DateTime createdAt;
  final bool isRead;
  final Map<String, dynamic>? metadata;

  Alert({
    this.id,
    required this.type,
    required this.severity,
    required this.title,
    required this.message,
    this.farmId,
    this.farmName,
    this.userId,
    required this.createdAt,
    this.isRead = false,
    this.metadata,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'severity': severity,
      'title': title,
      'message': message,
      'farm_id': farmId,
      'farm_name': farmName,
      'user_id': userId,
      'created_at': createdAt.toIso8601String(),
      'is_read': isRead ? 1 : 0,
      'metadata': metadata?.toString(),
    };
  }

  factory Alert.fromMap(Map<String, dynamic> map) {
    return Alert(
      id: map['id'],
      type: map['type'],
      severity: map['severity'],
      title: map['title'],
      message: map['message'],
      farmId: map['farm_id'],
      farmName: map['farm_name'],
      userId: map['user_id'],
      createdAt: DateTime.parse(map['created_at']),
      isRead: map['is_read'] == 1,
      metadata: map['metadata'] != null ? {} : null,
    );
  }

  Alert copyWith({
    int? id,
    String? type,
    String? severity,
    String? title,
    String? message,
    int? farmId,
    String? farmName,
    String? userId,
    DateTime? createdAt,
    bool? isRead,
    Map<String, dynamic>? metadata,
  }) {
    return Alert(
      id: id ?? this.id,
      type: type ?? this.type,
      severity: severity ?? this.severity,
      title: title ?? this.title,
      message: message ?? this.message,
      farmId: farmId ?? this.farmId,
      farmName: farmName ?? this.farmName,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
      metadata: metadata ?? this.metadata,
    );
  }

  String get icon {
    switch (severity) {
      case 'high':
        return '🔴';
      case 'medium':
        return '🟡';
      case 'low':
        return '🟢';
      default:
        return '⚪';
    }
  }
}
