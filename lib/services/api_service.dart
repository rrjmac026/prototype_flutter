import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

class ApiService {
  static const String baseUrl = 'http://192.168.1.8:3000/api/sensor-data';
  static const String defaultPlantId =
      'C8dA5OfZEC1EGAhkdAB4'; // Match ESP32's FIXED_PLANT_ID
  static const String defaultPlantName = 'Default Plant';

  // Get latest sensor data
  Future<Map<String, dynamic>> getLatestSensorData(String plantId) async {
    try {
      debugPrint('Fetching sensor data for plant: $plantId');
      // Updated endpoint to match server.js implementation
      final response = await http.get(
        Uri.parse('$baseUrl/plants/$plantId/latest-sensor-data'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      );

      debugPrint('Response status: ${response.statusCode}');
      debugPrint('Raw response: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('Parsed data: $data');

        // Handle the response format from server.js
        return {
          'moisture': data['moisture'] ?? 0,
          'temperature': data['temperature'] ?? 0,
          'humidity': data['humidity'] ?? 0,
          'moistureStatus': data['moistureStatus'] ?? 'NO_DATA',
          'timestamp': data['timestamp'] != null
              ? data['timestamp'].toString()
              : DateTime.now().toIso8601String(),
        };
      } else {
        debugPrint('Error response: ${response.body}');
        return _getDefaultData();
      }
    } catch (e) {
      debugPrint('Error fetching sensor data: $e');
      return _getDefaultData();
    }
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
  Future<List<int>> generateReport(
      String plantId, DateTime start, DateTime end) async {
    try {
      final response = await http.get(
        Uri.parse(
          '$baseUrl/reports/$plantId?start=${start.toIso8601String()}&end=${end.toIso8601String()}',
        ),
        headers: {'Accept': 'application/pdf'},
      );

      if (response.statusCode == 200) {
        return response.bodyBytes;
      } else {
        throw Exception('Failed to generate report');
      }
    } catch (e) {
      debugPrint('Error generating report: $e');
      rethrow;
    }
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
