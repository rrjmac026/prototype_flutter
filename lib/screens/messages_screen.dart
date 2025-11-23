import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:prototype/models/message.dart';
import 'package:prototype/providers/message_provider.dart';
import 'package:prototype/services/sms_permission_service.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Initialize messages if needed
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<MessageProvider>(context, listen: false).initializeMessages();
    });
  }

  @override
  Widget build(BuildContext context) {
    final messageProvider = Provider.of<MessageProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Warnings'),
        elevation: 0,
      ),
      body: messageProvider.messages.isEmpty
          ? const Center(
              child: Text('No warnings at this time'),
            )
          : ListView.builder(
              itemCount: messageProvider.messages.length,
              padding: const EdgeInsets.all(16),
              itemBuilder: (context, index) {
                final message = messageProvider.messages[index];
                return _buildWarningCard(message);
              },
            ),
    );
  }

  Widget _buildWarningCard(Message message) {
    final color = _getWarningColor(message.type);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: message.type == MessageType.critical ? 8 : 2,
      child: Container(
        decoration: BoxDecoration(
          border: message.type == MessageType.critical
              ? Border.all(color: Colors.red, width: 2)
              : null,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(_getWarningIcon(message.type), color: color, size: 24),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      message.title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: color,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                message.content,
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 8),
              Text(
                DateFormat('MMM d, y • h:mm a').format(message.timestamp),
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getWarningColor(MessageType type) {
    switch (type) {
      case MessageType.critical:
        return Colors.red;
      case MessageType.warning:
        return Colors.orange;
      case MessageType.info:
        return Colors.green;
    }
  }

  IconData _getWarningIcon(MessageType type) {
    switch (type) {
      case MessageType.critical:
        return Icons.error_outline;
      case MessageType.warning:
        return Icons.warning_amber;
      case MessageType.info:
        return Icons.check_circle_outline;
    }
  }
}
