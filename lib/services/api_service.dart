import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data';
import 'dart:async';
import 'dart:math'; // Add this import for pow function
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

class ApiService {
  static const String baseUrl = 'https://server-5527.onrender.com/api';
  static const String defaultPlantId =
      'C8dA5OfZEC1EGAhkdAB4'; // Match ESP32's FIXED_PLANT_ID
  static const String defaultPlantName = 'Default Plant';

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
      final endpoint = '$baseUrl/plants/$plantId/latest-sensor-data';

      debugPrint('Trying endpoint: $endpoint');
      final response = await http.get(
        Uri.parse(endpoint),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      debugPrint('Response status: ${response.statusCode}');
      debugPrint('Raw response: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data != null) {
          final moisture = _parseDoubleValue(data['moisture']);
          return {
            'moisture': moisture,
            'temperature': _parseDoubleValue(data['temperature']),
            'humidity': _parseDoubleValue(data['humidity']),
            'moistureStatus':
                data['moistureStatus'] ?? _getMoistureStatus(moisture),
            'timestamp': data['timestamp'] ?? DateTime.now().toIso8601String(),
          };
        }
      }
      return _getDefaultData();
    } catch (e) {
      debugPrint('Error fetching sensor data: $e');
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
}
