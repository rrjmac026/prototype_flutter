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
  Future<Schedule?> createSchedule(Schedule schedule) async {
    try {
      final endpoints = ['$baseUrl/schedules', '$backupUrl/schedules'];
      final scheduleData = schedule.toJson();
      debugPrint('Creating schedule with data: $scheduleData');

      for (final endpoint in endpoints) {
        try {
          final response = await http
              .post(
                Uri.parse(endpoint),
                headers: {
                  'Content-Type': 'application/json',
                  'Accept': 'application/json'
                },
                body: json.encode(scheduleData),
              )
              .timeout(const Duration(seconds: 30)); // Increased timeout

          debugPrint('Server response status: ${response.statusCode}');
          debugPrint('Server response body: ${response.body}');

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
          }
        } catch (e) {
          debugPrint('Error with endpoint $endpoint: $e');
          continue;
        }
      }
      throw Exception('Failed to create schedule: Server error');
    } catch (e) {
      debugPrint('Error creating schedule: $e');
      rethrow;
    }
  }

  // Update a schedule
  Future<bool> updateSchedule(
      String scheduleId, Map<String, dynamic> data) async {
    try {
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
}
