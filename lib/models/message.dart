enum MessageType {
  warning, // General system warnings
  critical, // Critical alerts
  info // Information messages
}

enum MessagePriority { normal, warning, critical }

class Message {
  final String id;
  final String title;
  final String content;
  final DateTime timestamp;
  final MessageType type;
  final MessagePriority priority;

  Message({
    required this.id,
    required this.title,
    required this.content,
    required this.timestamp,
    required this.type,
    this.priority = MessagePriority.normal,
  });
}
