enum MessageType { watering, moisture, conservation, system }

class Message {
  final String id;
  final String title;
  final String content;
  final DateTime timestamp;
  final MessageType type;
  final bool isRead;

  Message({
    required this.id,
    required this.title,
    required this.content,
    required this.timestamp,
    required this.type,
    this.isRead = false,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'],
      title: json['title'],
      content: json['content'],
      timestamp: DateTime.parse(json['timestamp']),
      type: MessageType.values.firstWhere(
        (e) => e.toString() == 'MessageType.${json['type']}',
      ),
      isRead: json['isRead'] ?? false,
    );
  }
}
