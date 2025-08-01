import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/audit_log.dart';
import '../services/api_service.dart';

class AuditService {
  static const String baseUrl = 'https://server-ydsa.onrender.com/api';
  static const String backupUrl = 'http://192.168.1.8:3000/api';

  // Standardized log types
  static const Map<String, String> logTypes = {
    'sensor': 'Sensor Activity',
    'water': 'Water System',
    'fertilizer': 'Fertilizer System',
    'schedule': 'Schedule Management',
    'report': 'Report Generation',
    'system': 'System Events',
    'user': 'User Activity',
    'maintenance': 'Maintenance',
    'notification': 'Notifications',
    'auth': 'Authentication',
  };

  Future<List<AuditLog>> getAuditLogs({
    String? plantId,
    String? type,
    String? action,
    String? status,
    DateTime? startDate,
    DateTime? endDate,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final queryParams = {
        if (plantId != null) 'plantId': plantId,
        if (type != null) 'type': type,
        if (action != null) 'action': action,
        if (status != null) 'status': status,
        if (startDate != null) 'start': startDate.toUtc().toIso8601String(),
        if (endDate != null) 'end': endDate.toUtc().toIso8601String(),
        'page': page.toString(),
        'limit': limit.toString(),
      };

      debugPrint('Fetching audit logs with params: $queryParams');

      final endpoints = [
        Uri.parse('$baseUrl/audit-logs').replace(queryParameters: queryParams),
        Uri.parse('$backupUrl/audit-logs')
            .replace(queryParameters: queryParams),
      ];

      for (final endpoint in endpoints) {
        try {
          debugPrint('Trying endpoint: $endpoint');
          final response = await http.get(endpoint).timeout(
                const Duration(seconds: 10),
              );

          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            if (data != null && data['logs'] != null) {
              final logs = (data['logs'] as List)
                  .map((log) {
                    try {
                      // Handle MongoDB date format
                      dynamic timestamp = log['timestamp'];
                      if (timestamp is Map && timestamp['\$date'] != null) {
                        // Handle MongoDB extended JSON format
                        log['timestamp'] = timestamp['\$date'];
                      } else if (timestamp is String) {
                        // Keep string format as is
                        log['timestamp'] = timestamp;
                      } else {
                        // Fallback to current time
                        log['timestamp'] = DateTime.now().toIso8601String();
                      }

                      return AuditLog.fromJson(log);
                    } catch (e) {
                      debugPrint('Error parsing log: $e');
                      debugPrint('Problematic log data: ${json.encode(log)}');
                      return null;
                    }
                  })
                  .where((log) => log != null)
                  .cast<AuditLog>()
                  .toList();

              debugPrint('Successfully parsed ${logs.length} logs');
              return logs;
            }
          }
        } catch (e, stackTrace) {
          debugPrint('Error with endpoint $endpoint: $e');
          debugPrint('Stack trace: $stackTrace');
          continue;
        }
      }

      return [];
    } catch (e, stackTrace) {
      debugPrint('Error fetching audit logs: $e');
      debugPrint('Stack trace: $stackTrace');
      return [];
    }
  }

  Future<List<String>> getLogTypes() async {
    try {
      final endpoints = [
        Uri.parse('$baseUrl/audit-logs/types'),
        Uri.parse('$backupUrl/audit-logs/types'),
      ];

      for (final endpoint in endpoints) {
        try {
          final response = await http.get(endpoint).timeout(
                const Duration(seconds: 5),
              );

          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            if (data['success'] == true && data['types'] != null) {
              return List<String>.from(data['types']);
            }
          }
        } catch (e) {
          continue;
        }
      }

      return [];
    } catch (e) {
      return [];
    }
  }

  Future<List<String>> getLogActions() async {
    try {
      final endpoints = [
        Uri.parse('$baseUrl/audit-logs/actions'),
        Uri.parse('$backupUrl/audit-logs/actions'),
      ];

      for (final endpoint in endpoints) {
        try {
          final response = await http.get(endpoint).timeout(
                const Duration(seconds: 5),
              );

          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            if (data['success'] == true && data['actions'] != null) {
              return List<String>.from(data['actions']);
            }
          }
        } catch (e) {
          continue;
        }
      }

      return [];
    } catch (e) {
      return [];
    }
  }

  // Enhanced createLog method
  Future<bool> createLog({
    required String type,
    required String action,
    String? details,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      if (!logTypes.containsKey(type)) {
        debugPrint('Warning: Unknown log type: $type');
      }

      final Map<String, dynamic> logData = {
        'plantId': ApiService.defaultPlantId,
        'type': type,
        'action': action,
        'status': 'success',
        'timestamp': DateTime.now().toUtc().toIso8601String(),
        if (details != null) 'details': details,
        if (additionalData != null) 'sensorData': additionalData,
      };

      final endpoints = [
        Uri.parse('$baseUrl/audit-logs'),
        Uri.parse('$backupUrl/audit-logs'),
      ];

      for (final endpoint in endpoints) {
        try {
          final response = await http.post(
            endpoint,
            body: json.encode(logData),
            headers: {'Content-Type': 'application/json'},
          ).timeout(const Duration(seconds: 5));

          if (response.statusCode == 201) {
            return true;
          }
        } catch (e) {
          continue;
        }
      }
      return false;
    } catch (e) {
      debugPrint('Error creating audit log: $e');
      return false;
    }
  }

  // Utility method to log any activity
  Future<bool> logActivity({
    required String type,
    required String action,
    String? details,
    Map<String, dynamic>? data,
  }) async {
    return createLog(
      type: type,
      action: action,
      details: details,
      additionalData: data,
    );
  }

  // Helper methods for specific activities
  Future<bool> logSensorActivity(
      String action, Map<String, dynamic> sensorData) {
    // Ensure waterState and fertilizerState are included in the log
    final enhancedSensorData = {
      ...sensorData,
      'waterState': sensorData['waterState'] ?? false,
      'fertilizerState': sensorData['fertilizerState'] ?? false,
    };

    return logActivity(
      type: 'sensor',
      action: action,
      details: 'Sensor reading recorded',
      data: enhancedSensorData,
    );
  }

  Future<bool> logScheduleActivity(
      String action, Map<String, dynamic> scheduleData) {
    return logActivity(
      type: 'schedule',
      action: action,
      details: 'Schedule ${scheduleData['type']} ${action}',
      data: scheduleData,
    );
  }

  Future<bool> logReportActivity(
      String action, Map<String, dynamic> reportData) {
    return logActivity(
      type: 'report',
      action: action,
      details: 'Report ${action}',
      data: reportData,
    );
  }

  Future<bool> logUserActivity(String action, String details) {
    return logActivity(
      type: 'user',
      action: action,
      details: details,
    );
  }

  // Track user authentication events
  Future<void> logAuthEvent(String action, {String? details}) async {
    await createLog(
      type: 'auth',
      action: action,
      details: details,
    );
  }

  // Track sensor data events
  Future<void> logSensorEvent(
      String action, Map<String, dynamic> sensorData) async {
    await createLog(
      type: 'sensor',
      action: action,
      details: 'Sensor readings recorded',
      additionalData: sensorData,
    );
  }

  // Track schedule management
  Future<void> logScheduleEvent(String action, {String? details}) async {
    await createLog(
      type: 'schedule',
      action: action,
      details: details,
    );
  }

  // Track report generation
  Future<void> logReportEvent(String action, {String? details}) async {
    await createLog(
      type: 'report',
      action: action,
      details: details,
    );
  }

  // Track system events
  Future<void> logSystemEvent(String action, {String? details}) async {
    await createLog(
      type: 'system',
      action: action,
      details: details,
    );
  }

  // Track maintenance events
  Future<void> logMaintenanceEvent(String action, {String? details}) async {
    await createLog(
      type: 'maintenance',
      action: action,
      details: details,
    );
  }

  // Track notifications
  Future<void> logNotificationEvent(String action, {String? details}) async {
    await createLog(
      type: 'notification',
      action: action,
      details: details,
    );
  }

  Stream<List<AuditLog>> getAuditLogsStream({
    String? plantId,
    String? type,
    String? action,
    String? status,
    DateTime? startDate,
    DateTime? endDate,
    Duration refreshInterval = const Duration(seconds: 5),
  }) {
    return Stream.periodic(refreshInterval).asyncMap((_) => getAuditLogs(
          plantId: plantId,
          type: type,
          action: action,
          status: status,
          startDate: startDate,
          endDate: endDate,
        ));
  }
}
