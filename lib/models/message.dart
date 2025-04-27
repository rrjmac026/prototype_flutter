class Message {
  final String content;
  final DateTime timestamp;
  final String type;
  final bool isRead;

  Message({
    required this.content,
    required this.timestamp,
    this.type = 'info',
    this.isRead = false,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      content: json['message'] ?? '',
      timestamp:
          DateTime.parse(json['timestamp'] ?? DateTime.now().toIso8601String()),
      type: json['type'] ?? 'info',
      isRead: json['isRead'] ?? false,
    );
  }
}
