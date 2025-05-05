import 'package:flutter/services.dart';

class SmsPermissionService {
  static const platform = MethodChannel('sms_channel');

  Future<bool> requestSmsPermissions() async {
    try {
      // Request permissions through platform channel
      await platform.invokeMethod('requestSmsPermissions');

      // Wait for permission result
      final bool granted =
          await platform.invokeMethod('onSmsPermissionsResult');
      return granted;
    } on PlatformException catch (e) {
      print('Failed to get SMS permissions: ${e.message}');
      return false;
    }
  }
}
