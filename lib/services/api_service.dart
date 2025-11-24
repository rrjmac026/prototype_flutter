import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data';
import 'dart:async';
import 'dart:math'; // Add this import for pow function
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:prototype/utils/report_config.dart';
import '../services/audit_service.dart';
import '../services/auth_service.dart';

class ApiService {
  static const String baseUrl = 'https://server-ydsa.onrender.com/api';
  static const String backupUrl = 'http://192.168.1.8:3000/api';
  static const String defaultPlantId =
      'C8dA5OfZEC1EGAhkdAB4'; // Match ESP32's FIXED_PLANT_ID
  static const String defaultPlantName = 'Default Plant';

  final AuditService _auditService = AuditService();

  String _getMoistureStatus(double value) {
    if (value == 1023) return 'NO DATA';
    if (value >= 1000) return 'SENSOR ERROR';
    if (value > 600 && value < 1000) return 'DRY';
    if (value > 370 && value <= 600) return 'HUMID';
    if (value <= 370) return 'WET';
    return 'NO DATA';
  }

  // Get latest sensor data
  Future<Map<String, dynamic>> getLatestSensorData(String plantId) async {
    try {
      debugPrint('Fetching sensor data for plant: $plantId');
      final endpoints = [
        '$baseUrl/plants/$plantId/latest-sensor-data',
        '$backupUrl/sensor-data' // Backup endpoint has different path
      ];

      for (int retry = 0; retry < 2; retry++) {
        for (final endpoint in endpoints) {
          try {
            debugPrint('Trying endpoint: $endpoint');
            final response = await http.get(
              Uri.parse(endpoint),
              headers: {'Accept': 'application/json'},
            ).timeout(const Duration(seconds: 10));

            if (response.statusCode == 200) {
              final data = json.decode(response.body);
              if (data != null) {
                final moisture = _parseDoubleValue(data['moisture']);
                final temperature = _parseDoubleValue(data['temperature']);
                final humidity = _parseDoubleValue(data['humidity']);
                final bool waterState = data['waterState'] ?? false;
                final bool fertilizerState = data['fertilizerState'] ?? false;

                // Update connection status check
                final bool isConnected =
                    temperature > 0 || humidity > 0 || moisture > 0;
                final bool explicitStatus =
                    data['isConnected'] ?? data['isOnline'] ?? isConnected;

                // Log the sensor reading with system states
                await _auditService.logSensorActivity(
                  'read',
                  {
                    'moisture': moisture,
                    'temperature': temperature,
                    'humidity': humidity,
                    'moistureStatus':
                        data['moistureStatus'] ?? _getMoistureStatus(moisture),
                    'isConnected': isConnected,
                    'waterState': waterState,
                    'fertilizerState': fertilizerState,
                  },
                );

                return {
                  'moisture': moisture,
                  'temperature': temperature,
                  'humidity': humidity,
                  'moistureStatus':
                      data['moistureStatus'] ?? _getMoistureStatus(moisture),
                  'timestamp':
                      data['timestamp'] ?? DateTime.now().toIso8601String(),
                  'isConnected': explicitStatus,
                  'isOnline': explicitStatus,
                  'waterState': waterState,
                  'fertilizerState': fertilizerState,
                };
              }
            }
          } catch (e) {
            debugPrint('Error with endpoint $endpoint: $e');
            continue;
          }
        }
        await Future.delayed(Duration(seconds: retry + 1));
      }
      return _getDefaultData();
    } catch (e) {
      debugPrint('Error fetching sensor data: $e');
      // Log sensor reading failure
      await _auditService.logSensorActivity(
        'error',
        {'error': e.toString()},
      );
      return _getDefaultData();
    }
  }

  double _parseDoubleValue(dynamic value) {
    if (value == null) return 0.0;
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  Map<String, dynamic> _getDefaultData() {
    return {
      'moisture': 0,
      'temperature': 0,
      'humidity': 0,
      'moistureStatus': 'NO_DATA',
      'timestamp': DateTime.now().toIso8601String(),
      'isConnected': false, // Add flag to indicate sensors are not connected
    };
  }

  // Ensure plant exists
  Future<void> ensurePlantExists() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/plants/$defaultPlantId'),
      );

      if (response.statusCode == 404) {
        // Plant doesn't exist, create it
        await http.post(
          Uri.parse('$baseUrl/plants'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'id': defaultPlantId,
            'name': defaultPlantName,
            'type': 'Indoor Plant',
            'description': 'Default monitoring plant'
          }),
        );
      }
    } catch (e) {
      print('Error ensuring plant exists: $e');
    }
  }

  // Generate report
  Future<Map<String, dynamic>> generateReport(
    String plantId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      debugPrint('Generating report...');
      // Use sensor-data endpoint instead of report since that's what exists
      final endpoint = '$baseUrl/plants/$plantId/sensor-data';

      final response = await http.get(
        Uri.parse(endpoint).replace(queryParameters: {
          'startDate': startDate.toIso8601String(),
          'endDate': endDate.toIso8601String(),
        }),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 30));

      debugPrint('Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final List<dynamic> readings = json.decode(response.body);
        if (readings.isEmpty) {
          throw Exception('No data available for selected date range');
        }

        // Calculate averages from the readings
        double totalMoisture = 0;
        double totalTemp = 0;
        double totalHumidity = 0;
        int count = readings.length;

        for (var reading in readings) {
          totalMoisture += _parseDoubleValue(reading['moisture']);
          totalTemp += _parseDoubleValue(reading['temperature']);
          totalHumidity += _parseDoubleValue(reading['humidity']);
        }

        return {
          'summary': {
            'averageMoisture': totalMoisture / count,
            'averageTemperature': totalTemp / count,
            'averageHumidity': totalHumidity / count,
          },
          'readings': readings,
          'alerts': _generateAlerts(readings),
          'timestamp': DateTime.now().toIso8601String(),
        };
      } else {
        throw Exception('Failed to fetch sensor data: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error generating report: $e');
      throw Exception('Unable to generate report: ${e.toString()}');
    }
  }

  Uri generateReportUrl(
    String plantId,
    DateTime startDate,
    DateTime endDate,
    BuildContext context,
  ) {
    return Uri.parse('$baseUrl/reports').replace(queryParameters: {
      'plantId': plantId,
      'start': startDate.toIso8601String(),
      'end': endDate.toIso8601String(),
      'format': 'pdf',
      'style': json.encode(ReportConfig.getStyle(context)),
      'username': defaultPlantName,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  List<Map<String, dynamic>> _generateAlerts(List<dynamic> readings) {
    final alerts = <Map<String, dynamic>>[];
    for (var reading in readings) {
      final moisture = _parseDoubleValue(reading['moisture']);
      if (moisture >= 1000) {
        alerts.add({
          'type': 'error',
          'message': 'Sensor disconnected',
          'timestamp': reading['timestamp'],
        });
      } else if (moisture > 600) {
        alerts.add({
          'type': 'warning',
          'message': 'Low moisture detected',
          'timestamp': reading['timestamp'],
        });
      }
    }
    return alerts;
  }

  // Get all plants
  Future<List<Map<String, dynamic>>> getPlants() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/plants'));

      if (response.statusCode == 200) {
        List<dynamic> plants = json.decode(response.body);
        return plants.cast<Map<String, dynamic>>();
      } else {
        throw Exception('Failed to load plants');
      }
    } catch (e) {
      debugPrint('Error fetching plants: $e');
      rethrow;
    }
  }

  // Update plant
  Future<void> updatePlant(String plantId, Map<String, dynamic> data) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/plants/$plantId'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(data),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to update plant');
      }
    } catch (e) {
      debugPrint('Error updating plant: $e');
      rethrow;
    }
  }

  static Future<Map<String, String>> _getHeaders() async {
    final token = await AuthService().getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Future<http.Response> get(String endpoint) async {
    final headers = await _getHeaders();
    return http.get(
      Uri.parse('$baseUrl$endpoint'),
      headers: headers,
    ).timeout(const Duration(seconds: 30));
  }

  static Future<http.Response> post(String endpoint, dynamic body) async {
    final headers = await _getHeaders();
    return http.post(
      Uri.parse('$baseUrl$endpoint'),
      headers: headers,
      body: body,
    ).timeout(const Duration(seconds: 30));
  }

  static Future<http.Response> patch(String endpoint, dynamic body) async {
    final headers = await _getHeaders();
    return http.patch(
      Uri.parse('$baseUrl$endpoint'),
      headers: headers,
      body: body,
    ).timeout(const Duration(seconds: 30));
  }

  static Future<http.Response> delete(String endpoint) async {
    final headers = await _getHeaders();
    return http.delete(
      Uri.parse('$baseUrl$endpoint'),
      headers: headers,
    ).timeout(const Duration(seconds: 30));
  }
}
