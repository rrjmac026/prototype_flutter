import 'package:prototype/models/message.dart';
import 'package:prototype/providers/message_provider.dart';


class SmsService {
  static const String authorizedNumber = '+639318384664';
  final MessageProvider messageProvider;

  SmsService({required this.messageProvider});

  void handleIncomingSms(String sender, String content, DateTime timestamp) {
    // Only process messages from authorized number
    if (sender == authorizedNumber) {
      final message = Message.fromSMS(
        content: content,
        senderNumber: sender,
        timestamp: timestamp,
      );
      messageProvider.addMessage(message);
    }
  }
}
