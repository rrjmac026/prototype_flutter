import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:prototype/models/schedule.dart';
import '../services/audit_service.dart';

class ScheduleService {
  static const String baseUrl = 'https://server-ydsa.onrender.com/api';
  static const String backupUrl = 'http://192.168.1.8:3000/api';

  final AuditService _auditService = AuditService();

  // Get all schedules for a plant
  Future<List<Schedule>> getSchedules(String plantId, {bool? enabled}) async {
    try {
      // Build the endpoint with query parameter if enabled is specified
      String buildEndpoint(String base) {
        final uri = Uri.parse('$base/schedules/$plantId');
        if (enabled != null) {
          return uri.replace(
              queryParameters: {'enabled': enabled.toString()}).toString();
        }
        return uri.toString();
      }

      final endpoints = [buildEndpoint(baseUrl), buildEndpoint(backupUrl)];

      for (final endpoint in endpoints) {
        try {
          final response = await http.get(
            Uri.parse(endpoint),
            headers: {'Accept': 'application/json'},
          ).timeout(const Duration(seconds: 10));

          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            final List<dynamic> scheduleList = data['schedules'];
            return scheduleList.map((json) => Schedule.fromJson(json)).toList();
          }
        } catch (e) {
          debugPrint('Error with endpoint $endpoint: $e');
          continue;
        }
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching schedules: $e');
      return [];
    }
  }

  // Create a new schedule
  // Create a new schedule
  Future<Schedule?> createSchedule(Schedule schedule) async {
    try {
      final endpoints = ['$baseUrl/schedules', '$backupUrl/schedules'];
      final scheduleData = schedule.toJson();

      // DEBUG: Print the schedule data being sent
      debugPrint('🔍 Schedule type: ${scheduleData['type']}');
      debugPrint('🔍 Schedule data being sent: ${json.encode(scheduleData)}');

      // Validate schedule data based on type
      if (scheduleData['type'] == 'fertilizing') {
        debugPrint('🔍 Validating fertilizing schedule...');
        debugPrint('🔍 calendarDays: ${scheduleData['calendarDays']}');
        debugPrint('🔍 calendarDays type: ${scheduleData['calendarDays'].runtimeType}');
        
        if (scheduleData['calendarDays'] == null ||
            (scheduleData['calendarDays'] as List).isEmpty) {
          throw Exception('Fertilizing schedule must specify calendar days');
        }
        scheduleData['days'] = []; // Clear days array
        debugPrint('🔍 Cleared days array for fertilizing schedule');
      } else {
        debugPrint('🔍 Validating watering schedule...');
        if (scheduleData['days'] == null ||
            (scheduleData['days'] as List).isEmpty) {
          throw Exception('Watering schedule must specify days');
        }
        scheduleData['calendarDays'] = []; // Clear calendarDays
        debugPrint('🔍 Cleared calendarDays for watering schedule');
      }

      debugPrint('🔍 Final schedule data: ${json.encode(scheduleData)}');

      for (final endpoint in endpoints) {
        try {
          debugPrint('🔍 Trying endpoint: $endpoint');
          
          final response = await http
              .post(
                Uri.parse(endpoint),
                headers: {
                  'Content-Type': 'application/json',
                  'Accept': 'application/json'
                },
                body: json.encode(scheduleData),
              )
              .timeout(const Duration(seconds: 30));

          debugPrint('🔍 Server response status: ${response.statusCode}');
          debugPrint('🔍 Server response body: ${response.body}');

          if (response.statusCode == 201) {
            final data = json.decode(response.body);
            if (data['success'] == true && data['schedule'] != null) {
              final scheduleData = data['schedule'];
              final scheduleId =
                  scheduleData['id'] ?? scheduleData['_id']?.toString();

              await _auditService.logScheduleActivity(
                'created',
                scheduleData,
              );

              return Schedule.fromJson({
                ...scheduleData,
                'id': scheduleId,
              });
            }
          } else {
            debugPrint('❌ Server error: ${response.statusCode} - ${response.body}');
          }
        } catch (e) {
          debugPrint('❌ Error with endpoint $endpoint: $e');
          continue;
        }
      }
      throw Exception('Failed to create schedule: Server error');
    } catch (e) {
      debugPrint('❌ Error creating schedule: $e');
      rethrow;
    }
  }

  // Update a schedule
  Future<bool> updateSchedule(
      String scheduleId, Map<String, dynamic> data) async {
    try {
      // Validate update data based on schedule type
      if (data['type'] == 'fertilizing') {
        if (data['calendarDays'] == null ||
            (data['calendarDays'] as List).isEmpty) {
          throw Exception('Fertilizing schedule must specify calendar days');
        }
        data['days'] = []; // Clear days array
      } else if (data.containsKey('days')) {
        if (data['days'] == null || (data['days'] as List).isEmpty) {
          throw Exception('Watering schedule must specify days');
        }
        data['calendarDays'] = []; // Clear calendarDays
      }

      final endpoints = [
        '$baseUrl/schedules/$scheduleId',
        '$backupUrl/schedules/$scheduleId'
      ];

      for (final endpoint in endpoints) {
        try {
          final response = await http
              .put(
                Uri.parse(endpoint),
                headers: {
                  'Content-Type': 'application/json',
                  'Accept': 'application/json'
                },
                body: json.encode(data),
              )
              .timeout(const Duration(seconds: 10));

          if (response.statusCode == 200) {
            // Log the schedule update
            await _auditService.logScheduleActivity(
              'updated',
              {'id': scheduleId, ...data},
            );

            return true;
          }
        } catch (e) {
          debugPrint('Error with endpoint $endpoint: $e');
          continue;
        }
      }
      return false;
    } catch (e) {
      debugPrint('Error updating schedule: $e');
      return false;
    }
  }

  // Delete a schedule
  Future<bool> deleteSchedule(String scheduleId) async {
    try {
      final endpoints = [
        '$baseUrl/schedules/$scheduleId',
        '$backupUrl/schedules/$scheduleId'
      ];

      for (final endpoint in endpoints) {
        try {
          final response = await http.delete(
            Uri.parse(endpoint),
            headers: {'Accept': 'application/json'},
          ).timeout(const Duration(seconds: 10));

          if (response.statusCode == 200) {
            // Log the schedule deletion
            await _auditService.logScheduleActivity(
              'deleted',
              {'id': scheduleId},
            );

            return true;
          }
        } catch (e) {
          debugPrint('Error with endpoint $endpoint: $e');
          continue;
        }
      }
      return false;
    } catch (e) {
      debugPrint('Error deleting schedule: $e');
      return false;
    }
  }

  // Execute a schedule
  Future<bool> executeSchedule(String scheduleId) async {
    try {
      final endpoints = [
        '$baseUrl/schedules/$scheduleId/execute',
        '$backupUrl/schedules/$scheduleId/execute'
      ];

      for (final endpoint in endpoints) {
        try {
          final response = await http.post(
            Uri.parse(endpoint),
            headers: {'Accept': 'application/json'},
          ).timeout(const Duration(seconds: 30));

          if (response.statusCode == 200) {
            return true;
          }
        } catch (e) {
          debugPrint('Error with endpoint $endpoint: $e');
          continue;
        }
      }
      return false;
    } catch (e) {
      debugPrint('Error executing schedule: $e');
      return false;
    }
  }

  // Get schedule status
  Future<Map<String, dynamic>> getScheduleStatus(String scheduleId) async {
    try {
      final endpoints = [
        '$baseUrl/schedules/$scheduleId/status',
        '$backupUrl/schedules/$scheduleId/status'
      ];

      for (final endpoint in endpoints) {
        try {
          final response = await http.get(
            Uri.parse(endpoint),
            headers: {'Accept': 'application/json'},
          ).timeout(const Duration(seconds: 10));

          if (response.statusCode == 200) {
            return json.decode(response.body);
          }
        } catch (e) {
          debugPrint('Error with endpoint $endpoint: $e');
          continue;
        }
      }
      throw Exception('Failed to get schedule status');
    } catch (e) {
      debugPrint('Error getting schedule status: $e');
      rethrow;
    }
  }
}
