import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:permission_handler/permission_handler.dart';

class SmsService {
  static const String GSM_NUMBER = '+639940090476';
  final SmsQuery _query = SmsQuery();

  Future<bool> requestPermission() async {
    final status = await Permission.sms.request();
    return status.isGranted;
  }

  Future<List<SmsMessage>> getMessages() async {
    if (!await requestPermission()) {
      throw Exception('SMS permission denied');
    }

    try {
      return await _query.querySms(
        address: GSM_NUMBER,
        kinds: [SmsQueryKind.inbox],
        count: 50,
      );
    } catch (e) {
      throw Exception('Failed to load messages: $e');
    }
  }

  String getMessageType(String body) {
    final lowerBody = body.toLowerCase();
    if (lowerBody.contains('water pump')) return 'water';
    if (lowerBody.contains('fertilizer')) return 'fertilizer';
    if (lowerBody.contains('system')) return 'system';
    if (lowerBody.contains('warning') || lowerBody.contains('error')) {
      return 'warning';
    }
    return 'info';
  }
}
