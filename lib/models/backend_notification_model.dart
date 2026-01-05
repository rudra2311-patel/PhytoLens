class BackendNotification {
  final String id;
  final String type;
  final String severity;
  final String message;
  final DateTime createdAt;
  final bool isRead;
  final bool sent;

  BackendNotification({
    required this.id,
    required this.type,
    required this.severity,
    required this.message,
    required this.createdAt,
    required this.isRead,
    required this.sent,
  });

  factory BackendNotification.fromJson(Map<String, dynamic> json) {
    return BackendNotification(
      id: json['id'],
      type: json['type'],
      severity: json['severity'],
      message: json['message'],
      createdAt: DateTime.parse(json['created_at']),
      isRead: json['is_read'],
      sent: json['sent'],
    );
  }

  String get icon {
    switch (severity) {
      case 'critical':
        return '🔴';
      case 'high':
        return '🟠';
      case 'medium':
        return '🟡';
      case 'low':
        return '🟢';
      default:
        return '⚪';
    }
  }

  String get title {
    // Extract first line as title
    final lines = message.split('\n');
    return lines.first;
  }

  String get body {
    // Extract rest as body
    final lines = message.split('\n');
    if (lines.length > 1) {
      return lines.sublist(1).join('\n');
    }
    return '';
  }
}
