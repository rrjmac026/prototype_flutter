import '../services/audit_service.dart';

class AuditLogger {
  static final AuditService _auditService = AuditService();

  // App navigation and views
  static Future<void> logScreenView(String screenName) async {
    await _auditService.createLog(
      type: 'navigation',
      action: 'view_screen',
      details: 'Accessed $screenName screen',
    );
  }

  // Plant management
  static Future<void> logPlantAction(String action, String details) async {
    await _auditService.createLog(
      type: 'plant',
      action: action,
      details: details,
    );
  }

  // User actions
  static Future<void> logUserAction(String action, String details) async {
    await _auditService.createLog(
      type: 'user',
      action: action,
      details: details,
    );
  }

  // Schedule management
  static Future<void> logScheduleAction(String action, String details) async {
    await _auditService.createLog(
      type: 'schedule',
      action: action,
      details: details,
    );
  }

  // System events
  static Future<void> logSystemEvent(String action, String details) async {
    await _auditService.createLog(
      type: 'system',
      action: action,
      details: details,
    );
  }
}
